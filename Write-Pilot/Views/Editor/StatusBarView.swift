import SwiftUI

struct StatusBarView: View {
    let line: Int
    let column: Int
    let wordCount: Int
    let hasUnsavedChanges: Bool
    let fileName: String

    var body: some View {
        HStack(spacing: 16) {
            Label("行 \(line)，欄 \(column)", systemImage: "text.cursor")
                .font(.system(size: 11))

            Divider().frame(height: 10)

            Label("字數：\(wordCount)", systemImage: "character.cursor.ibeam")
                .font(.system(size: 11))

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: hasUnsavedChanges ? "circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(hasUnsavedChanges ? .orange : .green)
                Text(hasUnsavedChanges ? "未儲存" : "已儲存")
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .overlay(alignment: .top) { Divider() }
    }
}
