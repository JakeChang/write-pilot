import SwiftUI

struct FileTreeRow: View {
    @Environment(FileService.self) private var fileService
    let node: FileNode
    var aiService: AIService?
    @State private var showRenameSheet = false
    @State private var renameText = ""
    @State private var showPlanWizard = false
    @State private var showDeleteConfirm = false
    @State private var hasPlanMetadata = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 14))
                .frame(width: 18)

            Text(node.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)

            if node.isDirectory && hasPlanMetadata {
                Text("計畫")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.tint)
            }

            Spacer()
        }
        .padding(.vertical, 1)
        .contextMenu { contextMenuItems }
        .sheet(isPresented: $showRenameSheet) {
            renameSheet
        }
        .sheet(isPresented: $showPlanWizard) {
            if let ai = aiService {
                PlanWizardView(
                    folderURL: node.url,
                    folderName: node.name,
                    aiService: ai,
                    fileService: fileService,
                    onComplete: { showPlanWizard = false }
                )
            }
        }
        .onAppear { checkPlanMetadata() }
        .onChange(of: showPlanWizard) { _, showing in
            if !showing { checkPlanMetadata() }
        }
        .alert("操作失敗", isPresented: $showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("確定刪除「\(node.name)」？", isPresented: $showDeleteConfirm) {
            Button("刪除", role: .destructive) { deleteNode() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("檔案將移至垃圾桶。")
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("重新命名")
                .font(.headline)

            TextField("名稱", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commitRename() }

            HStack {
                Button("取消") {
                    showRenameSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("確定") {
                    commitRename()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func commitRename() {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != node.name else {
            showRenameSheet = false
            return
        }
        do {
            let newURL = try fileService.rename(url: node.url, to: newName)
            node.name = newName
            node.url = newURL
            fileService.rescan()
        } catch {
            errorMessage = "重新命名失敗：\(error.localizedDescription)"
            showError = true
        }
        showRenameSheet = false
    }

    // MARK: - Icon

    private var icon: String {
        if node.isDirectory {
            return node.isExpanded ? "folder.fill" : "folder"
        }
        if node.isMarkdown { return "doc.text" }
        return "doc"
    }

    private var iconColor: Color {
        node.isDirectory ? .accentColor : .secondary
    }

    private func checkPlanMetadata() {
        hasPlanMetadata = FileManager.default.fileExists(
            atPath: node.url.appendingPathComponent(".writepilot").path
        )
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        if node.isDirectory {
            Button("新增檔案") { createFile() }
            Button("新增資料夾") { createFolder() }

            Divider()

            if aiService != nil {
                Button(hasPlanMetadata ? "✦ 更新寫作計畫…" : "✦ 啟動寫作計畫…") {
                    showPlanWizard = true
                }
            }

            Divider()
        }

        Button("重新命名") {
            renameText = node.name
            showRenameSheet = true
        }

        Button("在 Finder 中顯示") {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }

        Divider()

        Button("刪除", role: .destructive) {
            showDeleteConfirm = true
        }
    }

    // MARK: - Actions

    private func createFile() {
        do {
            _ = try fileService.createFile(in: node.url, name: "未命名.md")
            fileService.rescan()
        } catch {
            errorMessage = "新增檔案失敗：\(error.localizedDescription)"
            showError = true
        }
    }

    private func createFolder() {
        do {
            _ = try fileService.createFolder(in: node.url, name: "新資料夾")
            fileService.rescan()
        } catch {
            errorMessage = "新增資料夾失敗：\(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteNode() {
        do {
            try fileService.delete(url: node.url)
            fileService.rescan()
        } catch {
            errorMessage = "刪除失敗：\(error.localizedDescription)"
            showError = true
        }
    }
}
