import SwiftUI

enum AIPanelMode: String, CaseIterable {
    case assist = "助手"
    case reader = "讀者"
    case source = "來源"

    var icon: String {
        switch self {
        case .assist: "sparkles"
        case .reader: "person.2"
        case .source: "chart.bar"
        }
    }
}

struct AIPanelView: View {
    @Environment(\.openSettings) private var openSettings
    let aiService: AIService
    var selectedText: String
    var sourceTracker: SourceTracker
    var editorState: EditorState
    var onApplyText: ((String) -> Void)?

    @State private var selectedMode: AIPanelMode = .assist
    @State private var isAPIConfigured = false
    @State private var chatState = ChatState()
    @State private var readerState = ReaderState()
    @State private var detectState = SourceDetectState()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            modeTabs
            Divider()

            if isAPIConfigured {
                modeContent
            } else {
                apiKeyMissing
            }
        }
        .background(Color(.windowBackgroundColor).opacity(0.3))
        .task {
            isAPIConfigured = await aiService.isConfigured
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { isAPIConfigured = await aiService.isConfigured }
        }
        .onChange(of: editorState.pendingAIPrompt) { _, prompt in
            if let prompt {
                selectedMode = .assist
                triggerAssistMessage(prompt)
                editorState.pendingAIPrompt = nil
            }
        }
        .onChange(of: editorState.switchToAIMode) { _, mode in
            if let mode {
                switch mode {
                case "reader": selectedMode = .reader
                case "source": selectedMode = .source
                default: selectedMode = .assist
                }
                editorState.switchToAIMode = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(.tint)
                Text("AI 助手")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Text("Gemma 4")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Mode Tabs

    private var modeTabs: some View {
        HStack(spacing: 0) {
            ForEach(AIPanelMode.allCases, id: \.self) { mode in
                let isSelected = selectedMode == mode
                HStack(spacing: 5) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 11))
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                }
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
                .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.accentColor)
                            .frame(height: 2)
                            .padding(.horizontal, 12)
                    }
                }
                .onTapGesture { selectedMode = mode }
            }
        }
    }

    // MARK: - Mode Content

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .assist:
            AssistModeView(
                aiService: aiService,
                selectedText: selectedText,
                chatState: chatState,
                onApply: onApplyText
            )
        case .reader:
            ReaderModeView(
                aiService: aiService,
                selectedText: selectedText,
                readerState: readerState
            )
        case .source:
            SourceModeView(
                aiService: aiService,
                selectedText: selectedText,
                detectState: detectState
            )
        }
    }

    // MARK: - Trigger from Floating Menu

    private func triggerAssistMessage(_ content: String) {
        chatState.streamResponse(content: content, aiService: aiService)
    }

    // MARK: - API Key Missing

    private var apiKeyMissing: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("尚未設定 API Key")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("前往設定輸入 Google AI API Key")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Button("開啟設定") { openSettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
