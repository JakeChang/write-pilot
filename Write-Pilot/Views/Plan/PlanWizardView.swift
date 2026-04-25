import SwiftUI

struct PlanWizardView: View {
    let folderURL: URL
    let folderName: String
    let aiService: AIService
    let fileService: FileService
    var onComplete: () -> Void

    @State private var step: WizardStep = .describe
    @State private var topicInput = ""
    @State private var outlineText = ""
    @State private var isGenerating = false
    @State private var planService = PlanService()
    @State private var errorMessage = ""
    @State private var resultMessage = ""
    @State private var isUpdate = false

    enum WizardStep {
        case describe
        case editOutline
        case generating
        case done
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            switch step {
            case .describe:
                describeStep
            case .editOutline:
                outlineStep
            case .generating:
                generatingStep
            case .done:
                doneStep
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            let outlineURL = folderURL.appendingPathComponent("outline.md")
            if let content = try? String(contentsOf: outlineURL, encoding: .utf8) {
                outlineText = content
                isUpdate = true
                step = .editOutline
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            Text(isUpdate ? "更新寫作計畫" : "寫作計畫精靈")
                .font(.headline)
            Spacer()
            Text(stepLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var stepLabel: String {
        switch step {
        case .describe: "步驟 1/2：描述你的寫作計畫"
        case .editOutline: isUpdate ? "編輯大綱後產生新章節" : "步驟 2/2：編輯大綱"
        case .generating: "產生中…"
        case .done: "完成"
        }
    }

    // MARK: - Step 1: Describe

    private var describeStep: some View {
        VStack(spacing: 16) {
            Text("你想在「\(folderName)」裡寫什麼？")
                .font(.title3)
                .padding(.top, 20)

            Text("簡單描述主題、目標讀者、預計章節數，AI 會幫你產生大綱。")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $topicInput)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: .infinity)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("產生大綱") {
                    generateOutline()
                }
                .buttonStyle(.borderedProminent)
                .disabled(topicInput.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: Edit Outline

    private var outlineStep: some View {
        VStack(spacing: 12) {
            Text(isUpdate ? "編輯大綱" : "確認大綱")
                .font(.title3)
                .padding(.top, 12)

            Text(isUpdate
                 ? "修改大綱後按「產生新章節」，已存在的檔案不會被覆蓋。"
                 : "確認或修改下方大綱，完成後點擊「產生寫作檔案」。")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $outlineText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: .infinity)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if !isUpdate {
                    Button("重新產生") {
                        step = .describe
                    }
                    .buttonStyle(.bordered)
                }

                Button("取消") {
                    onComplete()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(isUpdate ? "✦ 產生新章節" : "✦ 產生寫作檔案") {
                    generateFiles()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Generating

    private var generatingStep: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("正在產生章節檔案…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Step 4: Done

    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("完成")
                .font(.title3.weight(.semibold))

            Text(resultMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("關閉") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - Actions

    private func generateOutline() {
        isGenerating = true
        errorMessage = ""

        Task {
            do {
                let prompt = """
                請根據以下描述，產生一份書籍大綱（Markdown 格式）。
                用 # 標題作為書名，用 ## 標題作為每一章的標題。
                每章下方用 - 列出 2-3 個小節方向。

                描述：
                \(topicInput)
                """

                let response = try await aiService.send(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    system: "你是一位經驗豐富的寫作顧問。請用繁體中文回答。只回傳 Markdown 大綱，不要加其他說明。直接輸出結果，不要輸出思考過程或推理步驟。"
                )

                outlineText = response
                step = .editOutline
            } catch {
                errorMessage = "產生失敗：\(error.localizedDescription)"
            }
            isGenerating = false
        }
    }

    private func generateFiles() {
        step = .generating
        errorMessage = ""

        Task {
            do {
                let (title, chapters) = planService.parseOutline(markdown: outlineText)
                var plan = WritingPlan(
                    title: title.isEmpty ? folderName : title,
                    chapters: chapters
                )
                plan.description = topicInput

                let (created, skipped) = try planService.generateChapterFiles(
                    plan: plan,
                    outlineMarkdown: outlineText,
                    in: folderURL,
                    fileService: fileService
                )

                fileService.rescan()

                // Build result message
                var msg = ""
                if !created.isEmpty {
                    msg += "新建 \(created.count) 個檔案：\n"
                    msg += created.map { "• \($0)" }.joined(separator: "\n")
                }
                if !skipped.isEmpty {
                    if !msg.isEmpty { msg += "\n\n" }
                    msg += "已存在（略過）\(skipped.count) 個檔案"
                }
                if created.isEmpty && skipped.isEmpty {
                    msg = "大綱中沒有偵測到章節。"
                }
                resultMessage = msg
                step = .done
            } catch {
                errorMessage = "產生檔案失敗：\(error.localizedDescription)"
                step = .editOutline
            }
        }
    }
}
