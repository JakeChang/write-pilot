import SwiftUI

struct EditorView: View {
    @Environment(FileService.self) private var fileService
    @Binding var openFiles: [OpenFile]
    @Binding var activeFile: OpenFile?
    var selectedNode: FileNode?
    var editorState: EditorState
    var sourceTracker: SourceTracker
    var dailyWordCount: DailyWordCountService
    @State private var autoSave = AutoSaveService()
    @State private var cursorLine = 1
    @State private var cursorColumn = 1
    @State private var isPreviewMode = false
    @State private var cachedWordCount = 0
    @State private var wordCountTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            if !openFiles.isEmpty {
                TabBarView(
                    openFiles: $openFiles,
                    activeFile: $activeFile,
                    onClose: closeFile
                )
            }

            if let file = activeFile {
                // Toolbar
                editorToolbar

                // Editor area
                ZStack(alignment: .topTrailing) {
                    if isPreviewMode {
                        MarkdownPreviewView(markdownContent: file.content)
                    } else {
                        MarkdownTextView(
                            text: Binding(
                                get: { file.content },
                                set: { newValue in
                                    file.content = newValue
                                    autoSave.scheduleAutoSave(file: file, fileService: fileService, sourceTracker: sourceTracker)
                                }
                            ),
                            workspaceURL: fileService.workspaceURL,
                            sourceTracker: sourceTracker,
                            dailyWordCount: dailyWordCount,
                            onCursorChange: { line, col in
                                cursorLine = line
                                cursorColumn = col
                            },
                            onSelectionChange: { text, range in
                                editorState.selectedText = text
                                editorState.selectedRange = range
                                editorState.showFloatingMenu = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            }
                        )
                    }

                    // Floating menu — positioned at top-right, not overlapping text
                    if editorState.showFloatingMenu && !isPreviewMode {
                        FloatingMenuView(selectedText: editorState.selectedText) { action in
                            editorState.showFloatingMenu = false
                            if action == .readerView {
                                editorState.switchToAIMode = "reader"
                            } else {
                                let prompt = "\(action.systemPrompt)\n\n\(editorState.selectedText)"
                                editorState.pendingAIPrompt = prompt
                            }
                        }
                        .padding(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.2), value: editorState.showFloatingMenu)
                    }
                }

                // Status bar
                StatusBarView(
                    line: cursorLine,
                    column: cursorColumn,
                    wordCount: cachedWordCount,
                    hasUnsavedChanges: file.hasUnsavedChanges,
                    fileName: file.fileName
                )
                .onChange(of: file.content) { _, newContent in
                    wordCountTask?.cancel()
                    wordCountTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        cachedWordCount = newContent.filter { !$0.isWhitespace && !$0.isNewline }.count
                    }
                }
                .onChange(of: activeFile) { _, newFile in
                    cachedWordCount = newFile?.content.filter { !$0.isWhitespace && !$0.isNewline }.count ?? 0
                }
            } else if let folder = selectedNode, folder.isDirectory {
                FolderOverviewView(node: folder)
            } else {
                emptyState
            }
        }
        .onDisappear {
            if let file = activeFile {
                autoSave.saveNow(file: file, fileService: fileService, sourceTracker: sourceTracker)
            }
        }
        .background {
            Button("") {
                if let file = activeFile {
                    autoSave.saveNow(file: file, fileService: fileService, sourceTracker: sourceTracker)
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .hidden()
        }
    }

    private var editorToolbar: some View {
        HStack(spacing: 8) {
            if let file = activeFile, file.fileName == "outline.md" {
                OutlineToolbarView(
                    file: file,
                    autoSave: autoSave,
                    sourceTracker: sourceTracker
                )
            } else {
                Spacer()
            }

            Button {
                isPreviewMode.toggle()
            } label: {
                Label(isPreviewMode ? "編輯" : "預覽",
                      systemImage: isPreviewMode ? "pencil" : "eye")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor).opacity(0.3))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func closeFile(_ file: OpenFile) {
        if file.hasUnsavedChanges {
            autoSave.saveNow(file: file, fileService: fileService, sourceTracker: sourceTracker)
        }
        openFiles.removeAll { $0.id == file.id }
        if activeFile?.id == file.id {
            activeFile = openFiles.last
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text("選擇一個檔案來開始編輯")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("從左側檔案樹選取，或按 ⌘N 新增檔案")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
