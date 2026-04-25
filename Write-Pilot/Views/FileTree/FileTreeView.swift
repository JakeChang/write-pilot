import SwiftUI

struct FileTreeView: View {
    @Environment(FileService.self) private var fileService
    @Binding var selectedNode: FileNode?
    var aiService: AIService?

    @State private var showNewFileSheet = false
    @State private var showNewFolderSheet = false
    @State private var newFileName = ""
    @State private var newFolderName = ""
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 0) {
            if let root = fileService.rootNode, let children = root.sortedChildren {
                List(selection: $selectedNode) {
                    ForEach(children) { node in
                        FileTreeNodeView(node: node, aiService: aiService)
                    }
                }
                .listStyle(.sidebar)
                .contextMenu {
                    Button("新增檔案") { newFileName = "未命名.md"; showNewFileSheet = true }
                    Button("新增資料夾") { newFolderName = "新資料夾"; showNewFolderSheet = true }
                }
            } else {
                emptyState
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { newFileName = "未命名.md"; showNewFileSheet = true }) {
                    Image(systemName: "doc.badge.plus")
                }
                .help("新增檔案")
                .disabled(fileService.workspaceURL == nil)

                Button(action: { newFolderName = "新資料夾"; showNewFolderSheet = true }) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("新增資料夾")
                .disabled(fileService.workspaceURL == nil)

                Button(action: { fileService.openWorkspace() }) {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .help("開啟工作區")
            }
        }
        .sheet(isPresented: $showNewFileSheet) {
            newFileSheet
        }
        .sheet(isPresented: $showNewFolderSheet) {
            newFolderSheet
        }
        .alert("操作失敗", isPresented: $showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - New File Sheet

    private var newFileSheet: some View {
        VStack(spacing: 16) {
            Text("新增檔案")
                .font(.headline)

            TextField("檔案名稱", text: $newFileName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createNewFile() }

            Text("將建立在工作區根目錄，副檔名預設為 .md")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消") {
                    newFileName = ""
                    showNewFileSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("建立") {
                    createNewFile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newFileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func createNewFile() {
        guard let workspace = fileService.workspaceURL else { return }
        var name = newFileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // Auto-add .md if no extension
        if !name.contains(".") {
            name += ".md"
        }

        // Determine target folder: selected folder, or parent of selected file, or workspace root
        let targetDir: URL
        if let selected = selectedNode {
            targetDir = selected.isDirectory ? selected.url : selected.url.deletingLastPathComponent()
        } else {
            targetDir = workspace
        }

        do {
            let url = try fileService.createFile(in: targetDir, name: name)
            fileService.rescan()

            // Find the new node and select it
            if let node = fileService.findNode(for: url) {
                selectedNode = node
            }

            newFileName = ""
            showNewFileSheet = false
        } catch {
            showNewFileSheet = false
            errorMessage = "新增檔案失敗：\(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - New Folder Sheet

    private var newFolderSheet: some View {
        VStack(spacing: 16) {
            Text("新增資料夾")
                .font(.headline)

            TextField("資料夾名稱", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createNewFolder() }

            HStack {
                Button("取消") {
                    newFolderName = ""
                    showNewFolderSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("建立") {
                    createNewFolder()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func createNewFolder() {
        guard let workspace = fileService.workspaceURL else { return }
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let targetDir: URL
        if let selected = selectedNode {
            targetDir = selected.isDirectory ? selected.url : selected.url.deletingLastPathComponent()
        } else {
            targetDir = workspace
        }

        do {
            _ = try fileService.createFolder(in: targetDir, name: name)
            fileService.rescan()
            newFolderName = ""
            showNewFolderSheet = false
        } catch {
            showNewFolderSheet = false
            errorMessage = "新增資料夾失敗：\(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("尚未開啟工作區")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("選擇資料夾") {
                fileService.openWorkspace()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
