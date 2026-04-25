import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var showCopied = false

    var body: some View {
        if message.role == .user {
            userBubble
        } else {
            assistantBubble
        }
    }

    // MARK: - User

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)

            Text(message.content)
                .font(.system(size: 14))
                .lineSpacing(4)
                .padding(12)
                .foregroundStyle(.white)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .textSelection(.enabled)
        }
    }

    // MARK: - Assistant

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 26, height: 26)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.content)
                    .font(.system(size: 14))
                    .lineSpacing(5)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)

                // Action buttons
                HStack(spacing: 14) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        showCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "已複製" : "複製", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(showCopied ? Color.green : Color.secondary)
                }
                .padding(.leading, 8)
            }

            Spacer(minLength: 0)
        }
    }
}
