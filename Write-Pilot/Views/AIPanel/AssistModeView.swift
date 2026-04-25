import SwiftUI

@Observable
class ChatState {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isStreaming = false
    var streamingText = ""

    private static let systemPrompt = "你是 WritePilot 的寫作助手。幫助使用者改善文章品質，但保留他們自己的聲音和風格。回答請用繁體中文。重要：直接回覆最終內容，不要輸出任何思考過程、推理步驟、角色描述或計畫。"
    private static let maxMessages = 100

    func streamResponse(content: String, aiService: AIService) {
        messages.append(ChatMessage(role: .user, content: content))
        trimMessages()
        isStreaming = true
        streamingText = ""

        Task {
            do {
                let msgs = messages.map { $0 }
                var buffer = ""
                var lastFlush = ContinuousClock.now

                for try await event in await aiService.stream(
                    messages: msgs,
                    system: Self.systemPrompt
                ) {
                    switch event {
                    case .text(let text):
                        buffer += text
                        let now = ContinuousClock.now
                        if now - lastFlush >= .milliseconds(50) {
                            let chunk = buffer
                            buffer = ""
                            lastFlush = now
                            await MainActor.run { self.streamingText += chunk }
                        }
                    case .done:
                        let remaining = buffer
                        await MainActor.run {
                            if !remaining.isEmpty { self.streamingText += remaining }
                            self.messages.append(ChatMessage(role: .assistant, content: self.streamingText))
                            self.isStreaming = false
                        }
                    case .error(let msg):
                        await MainActor.run {
                            self.messages.append(ChatMessage(role: .assistant, content: "Error: \(msg)"))
                            self.isStreaming = false
                        }
                    }
                }
                if !buffer.isEmpty {
                    let remaining = buffer
                    await MainActor.run { self.streamingText += remaining }
                }
            } catch {
                await MainActor.run {
                    self.messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)"))
                    self.isStreaming = false
                }
            }
        }
    }

    private func trimMessages() {
        if messages.count > Self.maxMessages {
            messages.removeFirst(messages.count - Self.maxMessages)
        }
    }
}

struct AssistModeView: View {
    let aiService: AIService
    var selectedText: String
    var chatState: ChatState
    var onApply: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if !selectedText.isEmpty {
                selectedTextCard
                Divider()
            }

            // Chat area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if chatState.messages.isEmpty && !chatState.isStreaming {
                            emptyChat
                        }

                        ForEach(chatState.messages) { msg in
                            ChatBubbleView(message: msg)
                                .id(msg.id)
                        }

                        if chatState.isStreaming {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }
                .onChange(of: chatState.streamingText) { _, _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
                .onChange(of: chatState.messages.count) { _, _ in
                    if let lastMsg = chatState.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(50))
                    if chatState.isStreaming {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    } else if let lastMsg = chatState.messages.last {
                        proxy.scrollTo(lastMsg.id, anchor: .bottom)
                    }
                }
            }

            Divider()
            quickActionsBar
            Divider()
            inputArea
        }
    }

    // MARK: - Empty Chat

    private var emptyChat: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text("開始對話")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("選取文字後使用快速動作，\n或直接輸入問題")
                .font(.system(size: 12))
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Streaming Bubble

    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, isActive: chatState.streamingText.isEmpty)
            }

            VStack(alignment: .leading, spacing: 0) {
                if chatState.streamingText.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在思考…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Text(chatState.streamingText)
                        .font(.system(size: 14))
                        .lineSpacing(5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Selected Text Card

    private var selectedTextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("已選取區塊", systemImage: "text.quote")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text(selectedText)
                .font(.system(size: 13))
                .lineLimit(4)
                .lineSpacing(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
        }
        .padding(14)
    }

    // MARK: - Quick Actions

    private static let quickActions: [FloatingMenuView.FloatingAction] = [.polish, .summarize, .expand, .rewrite, .nextHint]

    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Self.quickActions, id: \.self) { action in
                    Button {
                        let text = selectedText.isEmpty ? "(目前文件內容)" : selectedText
                        sendMessage("\(action.systemPrompt)\n\n\(text)")
                    } label: {
                        Label(action.rawValue, systemImage: action.icon)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(chatState.isStreaming)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 10) {
            // Clear chat button
            if !chatState.messages.isEmpty {
                Button {
                    chatState.messages.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除對話")
            }

            TextField("問 AI…", text: Binding(
                get: { chatState.inputText },
                set: { chatState.inputText = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onSubmit { submitInput() }

            Button {
                submitInput()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canSend ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiaryLabelColor)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var canSend: Bool {
        !chatState.inputText.trimmingCharacters(in: .whitespaces).isEmpty && !chatState.isStreaming
    }

    // MARK: - Actions

    private func submitInput() {
        let text = chatState.inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        var message = text
        if !selectedText.isEmpty {
            message = "\(text)\n\n---\n已選取文字：\n\(selectedText)"
        }

        chatState.inputText = ""
        sendMessage(message)
    }

    private func sendMessage(_ content: String) {
        chatState.streamResponse(content: content, aiService: aiService)
    }
}
