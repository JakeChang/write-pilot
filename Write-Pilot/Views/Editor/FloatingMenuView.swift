import SwiftUI

struct FloatingMenuView: View {
    let selectedText: String
    var onAction: (FloatingAction) -> Void

    enum FloatingAction: String, CaseIterable {
        case polish = "潤稿"
        case summarize = "摘要"
        case expand = "擴寫"
        case rewrite = "改寫"
        case nextHint = "下一段提示"
        case readerView = "讀者看"

        var systemPrompt: String {
            switch self {
            case .polish:
                return "請潤稿以下文字，保持原意但讓文句更流暢優雅："
            case .summarize:
                return "請摘要以下文字的重點："
            case .expand:
                return "請擴寫以下文字，加入更多細節和說明："
            case .rewrite:
                return "請用不同的方式改寫以下文字，保持原意："
            case .nextHint:
                return "根據以下已寫的內容，建議下一段可以寫什麼方向："
            case .readerView:
                return ""
            }
        }

        var icon: String {
            switch self {
            case .polish: "sparkles"
            case .summarize: "text.justify.left"
            case .expand: "arrow.up.left.and.arrow.down.right"
            case .rewrite: "arrow.2.squarepath"
            case .nextHint: "arrow.right.circle"
            case .readerView: "person.2"
            }
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
            ForEach(FloatingAction.allCases, id: \.self) { action in
                Button {
                    onAction(action)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: action.icon)
                            .font(.system(size: 9))
                        Text(action.rawValue)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(action == .readerView
                        ? Color.accentColor.opacity(0.15)
                        : Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        }
        .padding(8)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
