import SwiftUI

// MARK: - Menu bar label (shown in the status item itself)

struct MenuBarWordCountLabel: View {
    let service: DailyWordCountService

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pencil.line")
            Text(formatCount(service.todayCount))
                .monospacedDigit()
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1f萬", Double(n) / 10000) }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}

// MARK: - Popover content

struct MenuBarWordCountView: View {
    let service: DailyWordCountService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("今日寫作")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if service.todayCount == 0 {
                VStack(spacing: 6) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("今天尚未開始寫作")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    Text("\(service.todayCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("字")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            // Footer
            Rectangle()
                .fill(.quaternary)
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows
                    .first { $0.canBecomeMain }?
                    .makeKeyAndOrderFront(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 10))
                    Text("開啟 Write Pilot")
                        .font(.system(size: 11))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 220)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "MM/dd（E）"
        return f.string(from: Date())
    }
}
