import SwiftUI

struct ReaderPersona: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let focus: String

    static let allPersonas: [ReaderPersona] = [
        ReaderPersona(name: "懷疑的讀者", icon: "🤔", color: .red, focus: "論點嚴謹性、數據來源"),
        ReaderPersona(name: "目標讀者", icon: "❤️", color: .green, focus: "共鳴感、實用性"),
        ReaderPersona(name: "好奇的新手", icon: "💡", color: .yellow, focus: "看不懂的地方、學到什麼"),
        ReaderPersona(name: "直率的讀者", icon: "💬", color: .orange, focus: "節奏、表達精煉度"),
        ReaderPersona(name: "資深編輯", icon: "📖", color: .blue, focus: "結構、邏輯、改善方向"),
    ]
}

struct ReaderCardView: View {
    let persona: ReaderPersona
    let feedback: String?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Text(persona.icon)
                    .font(.system(size: 16))
                Text(persona.name)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(persona.focus)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Content
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("分析中…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if let feedback {
                Text(feedback)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
            } else {
                Text("選取文字後按「重新請讀者看這段」")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(persona.color.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(persona.color.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
