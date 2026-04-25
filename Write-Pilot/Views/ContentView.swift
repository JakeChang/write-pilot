import SwiftUI

struct ContentView: View {
    @Environment(FileService.self) private var fileService
    let aiService: AIService
    let dailyWordCount: DailyWordCountService

    @State private var selectedNode: FileNode?
    @State private var openFiles: [OpenFile] = []
    @State private var activeFile: OpenFile?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showExternalChangeAlert = false
    @State private var editorState = EditorState()
    @State private var sourceTracker = SourceTracker()
    @State private var fileErrorMessage = ""
    @State private var showFileError = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(selectedNode: $selectedNode, aiService: aiService)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 300)
        } content: {
            EditorView(
                openFiles: $openFiles,
                activeFile: $activeFile,
                selectedNode: selectedNode,
                editorState: editorState,
                sourceTracker: sourceTracker,
                dailyWordCount: dailyWordCount
            )
        } detail: {
            AIPanelView(
                aiService: aiService,
                selectedText: editorState.selectedText,
                sourceTracker: sourceTracker,
                editorState: editorState,
                onApplyText: { text in
                    applyAIText(text)
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 320, max: 600)
        }
        .navigationTitle(windowTitle)
        .onChange(of: selectedNode) { _, newValue in
            openFileFromTree(newValue)
        }
        .onChange(of: fileService.rescanVersion) { _, _ in
            reloadOpenFiles()
        }
        .onChange(of: fileService.externalChangeDetected) { _, detected in
            if detected {
                showExternalChangeAlert = true
                fileService.externalChangeDetected = false
            }
        }
        .alert("檔案已變更", isPresented: $showExternalChangeAlert) {
            Button("重新載入") { reloadActiveFile() }
            Button("忽略", role: .cancel) {}
        } message: {
            Text("工作區的檔案被外部程式修改，是否重新載入目前檔案？")
        }
        .alert("錯誤", isPresented: $showFileError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(fileErrorMessage)
        }
    }

    private var windowTitle: String {
        fileService.rootNode?.name ?? "WritePilot"
    }

    private func openFileFromTree(_ node: FileNode?) {
        // Save source data for previous file
        if let prevFile = activeFile {
            try? sourceTracker.save(for: prevFile.url)
        }

        guard let node else { return }

        if node.isDirectory {
            activeFile = nil
            return
        }

        if let existing = openFiles.first(where: { $0.node.url == node.url }) {
            activeFile = existing
            sourceTracker.load(for: existing.url)
            return
        }

        do {
            let content = try fileService.readFile(url: node.url)
            let file = OpenFile(node: node, content: content)
            openFiles.append(file)
            activeFile = file
            sourceTracker.load(for: file.url)
        } catch {
            fileErrorMessage = "無法開啟檔案：\(error.localizedDescription)"
            showFileError = true
        }
    }

    private func reloadActiveFile() {
        guard let file = activeFile else { return }
        if let content = try? fileService.readFile(url: file.url) {
            file.content = content
            file.hasUnsavedChanges = false
        }
    }

    private func reloadOpenFiles() {
        let fm = FileManager.default
        // Close tabs whose files no longer exist
        let removed = openFiles.filter { !fm.fileExists(atPath: $0.url.path) }
        if !removed.isEmpty {
            openFiles.removeAll { file in removed.contains(where: { $0.id == file.id }) }
            if let active = activeFile, removed.contains(where: { $0.id == active.id }) {
                activeFile = openFiles.last
            }
        }
        // Reload content for remaining files
        for file in openFiles where !file.hasUnsavedChanges {
            if let content = try? fileService.readFile(url: file.url) {
                if content != file.content {
                    file.content = content
                }
            }
        }
    }

    private func applyAIText(_ text: String) {
        guard let file = activeFile else { return }
        if editorState.selectedRange.length > 0 {
            let nsString = file.content as NSString
            let range = editorState.selectedRange
            if range.location + range.length <= nsString.length {
                file.content = nsString.replacingCharacters(in: range, with: text)
            }
        } else {
            file.content += "\n" + text
        }
        // AI applied text counts as "pasted"
        let contentCount = text.filter { !$0.isWhitespace && !$0.isNewline }.count
        sourceTracker.addPasted(count: contentCount)
        dailyWordCount.addChars(count: contentCount)
        file.hasUnsavedChanges = true
    }
}
