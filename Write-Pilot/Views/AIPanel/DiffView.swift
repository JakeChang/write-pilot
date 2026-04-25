import SwiftUI

struct DiffView: View {
    let original: String
    let modified: String
    var onApply: () -> Void
    var onEdit: () -> Void
    var onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("修改建議")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            // Diff display
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                        diffLineView(line)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Actions
            HStack(spacing: 8) {
                Button("✓ 套用") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("自己改寫") { onEdit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button { onRegenerate() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Diff Computation

    private struct DiffLine {
        enum Kind { case unchanged, added, removed }
        let kind: Kind
        let text: String
    }

    private var diffLines: [DiffLine] {
        let oldLines = original.components(separatedBy: "\n")
        let newLines = modified.components(separatedBy: "\n")

        let diff = newLines.difference(from: oldLines)

        var result: [DiffLine] = []
        var oldIndex = 0

        for change in diff.inferringMoves() {
            switch change {
            case .remove(let offset, let element, _):
                // Add unchanged lines before this removal
                while oldIndex < offset {
                    result.append(DiffLine(kind: .unchanged, text: oldLines[oldIndex]))
                    oldIndex += 1
                }
                result.append(DiffLine(kind: .removed, text: element))
                oldIndex = offset + 1
            case .insert(_, let element, _):
                result.append(DiffLine(kind: .added, text: element))
            }
        }

        // Remaining unchanged lines
        while oldIndex < oldLines.count {
            result.append(DiffLine(kind: .unchanged, text: oldLines[oldIndex]))
            oldIndex += 1
        }

        return result
    }

    @ViewBuilder
    private func diffLineView(_ line: DiffLine) -> some View {
        HStack(spacing: 4) {
            Text(prefix(for: line.kind))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(color(for: line.kind))
                .frame(width: 12)

            Text(line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(color(for: line.kind))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(background(for: line.kind))
    }

    private func prefix(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .unchanged: " "
        case .added: "+"
        case .removed: "-"
        }
    }

    private func color(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .unchanged: .primary
        case .added: .green
        case .removed: .red
        }
    }

    private func background(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .unchanged: .clear
        case .added: .green.opacity(0.1)
        case .removed: .red.opacity(0.1)
        }
    }
}
