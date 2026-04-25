import SwiftUI

struct TabBarView: View {
    @Binding var openFiles: [OpenFile]
    @Binding var activeFile: OpenFile?
    var onClose: (OpenFile) -> Void
    @State private var draggedFile: OpenFile?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(openFiles) { file in
                let isActive = activeFile?.id == file.id

                TabItemView(file: file, isActive: isActive, onClose: onClose, onSelect: { activeFile = file })
                    .opacity(draggedFile?.id == file.id ? 0.4 : 1)
                    .draggable(file.id.uuidString) {
                        Text(file.fileName)
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onAppear { draggedFile = file }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let droppedIDString = items.first,
                              let sourceIndex = openFiles.firstIndex(where: { $0.id.uuidString == droppedIDString }),
                              let destIndex = openFiles.firstIndex(where: { $0.id == file.id }),
                              sourceIndex != destIndex else { return false }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            openFiles.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
                        }
                        return true
                    } isTargeted: { _ in }
            }
            Spacer()
        }
        .frame(height: 36)
        .background(Color(.windowBackgroundColor).opacity(0.5))
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct TabItemView: View {
    let file: OpenFile
    let isActive: Bool
    var onClose: (OpenFile) -> Void
    var onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if file.hasUnsavedChanges {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            Text(file.fileName)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .lineLimit(1)

            if isActive || isHovering {
                Button {
                    onClose(file)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle().fill(Color.accentColor).frame(height: 2)
            }
        }
        .overlay(alignment: .trailing) {
            Divider().frame(height: 18).opacity(0.3)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
    }
}
