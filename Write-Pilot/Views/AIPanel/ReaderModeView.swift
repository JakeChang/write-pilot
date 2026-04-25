import SwiftUI

@Observable
class ReaderState {
    var feedbacks: [UUID: String] = [:]
    var isLoading = false
    var lastAnalyzedText = ""
}

struct ReaderModeView: View {
    let aiService: AIService
    var selectedText: String
    var readerState: ReaderState

    private let personas = ReaderPersona.allPersonas

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Label("讀者回饋", systemImage: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))

                if !selectedText.isEmpty {
                    Text("針對選取的 \(selectedText.count) 個字")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("請先選取文字，再按下方按鈕分析")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Reader cards
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(personas) { persona in
                        ReaderCardView(
                            persona: persona,
                            feedback: readerState.feedbacks[persona.id],
                            isLoading: readerState.isLoading
                        )
                    }
                }
                .padding(14)
            }

            Divider()

            // Action button
            Button {
                fetchFeedback()
            } label: {
                Label(
                    readerState.isLoading ? "分析中…" : "重新請讀者看這段",
                    systemImage: readerState.isLoading ? "hourglass" : "arrow.counterclockwise"
                )
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(selectedText.isEmpty || readerState.isLoading)
            .padding(12)
        }
    }

    private func fetchFeedback() {
        guard !selectedText.isEmpty else { return }
        readerState.isLoading = true
        readerState.feedbacks = [:]
        readerState.lastAnalyzedText = selectedText

        Task {
            let prompt = """
            你是五位不同類型的讀者，正在閱讀以下段落。
            請分別以每位讀者的視角，用第一人稱寫出即時反應和具體建議。

            段落：
            \"\"\"
            \(selectedText)
            \"\"\"

            讀者角色：
            1. 懷疑的讀者：關注論點嚴謹性和數據來源，但也肯定有說服力的部分
            2. 目標讀者：關注共鳴感和實用性，分享哪裡打動你、哪裡可以更好
            3. 好奇的新手：指出看不懂的地方，同時說說學到了什麼
            4. 直率的讀者：關注節奏和表達，指出可以更精煉的地方，也肯定流暢之處
            5. 資深編輯：關注結構和邏輯，給出具體的改善方向

            要求：
            - 先說感受（正面或負面皆可），再給具體建議，可以多說一些沒關係
            - 語氣平衡，不要只挑毛病，好的地方也要提到
            - 語氣自然，像真實的人在閱讀，可以展開說明想法
            - 每則回應 4-8 句話，充分表達觀點和建議
            - 用以下格式回傳（每個角色之間空一行）：

            [懷疑的讀者]
            回應內容

            [目標讀者]
            回應內容

            [好奇的新手]
            回應內容

            [直率的讀者]
            回應內容

            [資深編輯]
            回應內容
            """

            do {
                let response = try await aiService.send(
                    messages: [ChatMessage(role: .user, content: prompt)],
                    system: "你是讀者回饋模擬器。用繁體中文回答。嚴格按照指定格式回傳。直接輸出結果，不要輸出思考過程或推理步驟。"
                )

                let parsed = parseReaderFeedback(response)
                await MainActor.run {
                    for (index, persona) in personas.enumerated() {
                        if index < parsed.count {
                            readerState.feedbacks[persona.id] = parsed[index]
                        }
                    }
                    readerState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    for persona in personas {
                        readerState.feedbacks[persona.id] = "無法取得回饋：\(error.localizedDescription)"
                    }
                    readerState.isLoading = false
                }
            }
        }
    }

    private func parseReaderFeedback(_ text: String) -> [String] {
        let markers = ["[懷疑的讀者]", "[目標讀者]", "[好奇的新手]", "[直率的讀者]", "[資深編輯]"]
        var results: [String] = []

        for (i, marker) in markers.enumerated() {
            guard let markerRange = text.range(of: marker) else {
                results.append("")
                continue
            }

            let afterMarker = text[markerRange.upperBound...]
            let nextMarkerStart: String.Index
            if i + 1 < markers.count, let nextRange = text.range(of: markers[i + 1]) {
                nextMarkerStart = nextRange.lowerBound
            } else {
                nextMarkerStart = text.endIndex
            }

            let feedback = String(afterMarker[..<nextMarkerStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(feedback)
        }

        return results
    }
}
