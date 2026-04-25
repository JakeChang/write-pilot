import SwiftUI

@Observable
class SourceDetectState {
    var aiDetectResult: String?
    var aiDetectScore: Int?
    var isDetecting = false
}

struct SourceModeView: View {
    let aiService: AIService
    var selectedText: String
    var detectState: SourceDetectState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("AI 生成偵測", systemImage: "cpu")
                    .font(.system(size: 14, weight: .semibold))

                Text("選取文字後按下方按鈕，AI 會分析該段文字是否可能由 AI 生成。")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                // Result card
                if let score = detectState.aiDetectScore, let result = detectState.aiDetectResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(Color(.separatorColor), lineWidth: 3)
                                    .frame(width: 40, height: 40)
                                Circle()
                                    .trim(from: 0, to: Double(score) / 100)
                                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 40, height: 40)
                                Text("\(score)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(scoreLabel(score))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(scoreColor(score))
                                Text("AI 生成可能性")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(result)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .foregroundStyle(.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(scoreColor(score).opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(scoreColor(score).opacity(0.15), lineWidth: 1)
                    )
                }

                // Detect button
                Button {
                    detectAI()
                } label: {
                    HStack {
                        if detectState.isDetecting {
                            ProgressView().controlSize(.small)
                        }
                        Label(
                            detectState.isDetecting ? "分析中…" : "偵測 AI 生成",
                            systemImage: "wand.and.stars"
                        )
                        .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(selectedText.isEmpty || detectState.isDetecting)
            }
            .padding(16)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score <= 30 { return .green }
        if score <= 60 { return .orange }
        return .red
    }

    private func scoreLabel(_ score: Int) -> String {
        if score <= 20 { return "很可能是人寫的" }
        if score <= 40 { return "大部分像人寫的" }
        if score <= 60 { return "不確定" }
        if score <= 80 { return "可能是 AI 生成" }
        return "很可能是 AI 生成"
    }

    private func detectAI() {
        guard !selectedText.isEmpty else { return }
        detectState.isDetecting = true
        detectState.aiDetectResult = nil
        detectState.aiDetectScore = nil

        Task {
            let prompt = """
            請分析以下文字是否可能由 AI 生成。

            文字：
            \"\"\"
            \(selectedText)
            \"\"\"

            請回傳以下格式（嚴格遵守）：

            分數：[0-100 的整數，0 = 完全像人寫的，100 = 完全像 AI 生成的]
            分析：[用 2-4 句話說明判斷依據，例如用詞模式、句式結構、語氣特徵等]
            """

            do {
                let response = try await aiService.send(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    system: "你是文字分析專家，專門判斷文字是否由 AI 生成。用繁體中文回答。直接輸出結果，不要輸出思考過程。嚴格按照指定格式回傳。"
                )

                await MainActor.run {
                    parseDetectResult(response)
                    detectState.isDetecting = false
                }
            } catch {
                await MainActor.run {
                    detectState.aiDetectResult = "偵測失敗：\(error.localizedDescription)"
                    detectState.aiDetectScore = nil
                    detectState.isDetecting = false
                }
            }
        }
    }

    private func parseDetectResult(_ text: String) {
        if let scoreMatch = text.range(of: "分數：") ?? text.range(of: "分數:") {
            let afterScore = text[scoreMatch.upperBound...]
            let digits = afterScore.prefix(while: { $0.isNumber })
            detectState.aiDetectScore = Int(digits)
        }

        if let analysisMatch = text.range(of: "分析：") ?? text.range(of: "分析:") {
            detectState.aiDetectResult = String(text[analysisMatch.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            detectState.aiDetectResult = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if detectState.aiDetectScore == nil {
            detectState.aiDetectScore = 50
        }
    }
}
