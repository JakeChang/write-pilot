import Foundation
import AppKit

@Observable
class FileService {
    var workspaceURL: URL?
    var rootNode: FileNode?
    var externalChangeDetected = false
    var rescanVersion = 0

    /// When true, file watcher events are suppressed (app-initiated changes)
    private var suppressWatcher = false

    private static let bookmarkKey = "workspaceBookmark"
    private static let collapsedKey = "fileTree.collapsed"
    private var watcherSource: DispatchSourceFileSystemObject?
    private var watcherFD: Int32 = -1
    private let watchQueue = DispatchQueue(label: "me.jk.WritePilot.filewatcher", qos: .utility)

    deinit {
        stopWatching()
    }

    // MARK: - Workspace Management

    func openWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "選擇你的寫作工作區資料夾"
        panel.prompt = "開啟"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        saveBookmark(for: url)
        activateWorkspace(url: url)
    }

    func restoreWorkspace() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            return false
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }

        if isStale {
            // Re-save bookmark if stale
            saveBookmark(for: url)
        }

        guard url.startAccessingSecurityScopedResource() else {
            return false
        }

        activateWorkspace(url: url)
        return true
    }

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
    }

    private func activateWorkspace(url: URL) {
        stopWatching()
        workspaceURL = url
        rescan()
        restoreExpansionState()
        startWatching(url: url)
    }

    // MARK: - Directory Scanning

    func rescan() {
        guard let url = workspaceURL else { return }
        suppressWatcher = true

        if let root = rootNode {
            updateNode(root, from: url)
        } else {
            rootNode = scanDirectory(url: url)
        }
        rescanVersion += 1
    }

    /// Update an existing directory node in-place, preserving identity and expansion state.
    private func updateNode(_ node: FileNode, from url: URL) {
        let fm = FileManager.default
        node.name = url.lastPathComponent

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            node.children = []
            return
        }

        let diskChildren: [(url: URL, isDir: Bool)] = contents.compactMap { childURL in
            let name = childURL.lastPathComponent
            if name.hasSuffix(".source") || name == ".writepilot" {
                return nil
            }
            let resourceValues = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues?.isDirectory ?? false
            return (childURL, isDir)
        }

        let diskPaths = Set(diskChildren.map(\.url.path))
        let existingByPath = Dictionary(
            uniqueKeysWithValues: (node.children ?? []).map { ($0.url.path, $0) }
        )

        // Remove nodes no longer on disk
        node.children?.removeAll { !diskPaths.contains($0.url.path) }

        // Add new nodes and recurse into existing directories
        var updatedChildren = node.children ?? []
        let existingPaths = Set(updatedChildren.map(\.url.path))

        for entry in diskChildren {
            if let existing = existingByPath[entry.url.path] {
                // Update name in case of rename to same path (shouldn't happen, but safe)
                existing.name = entry.url.lastPathComponent
                if entry.isDir {
                    updateNode(existing, from: entry.url)
                }
            } else if !existingPaths.contains(entry.url.path) {
                // New node
                if entry.isDir {
                    let newNode = scanDirectory(url: entry.url)
                    updatedChildren.append(newNode)
                } else {
                    updatedChildren.append(FileNode(
                        name: entry.url.lastPathComponent,
                        url: entry.url,
                        isDirectory: false
                    ))
                }
            }
        }

        node.children = updatedChildren
    }

    func scanDirectory(url: URL) -> FileNode {
        let fm = FileManager.default
        let node = FileNode(
            name: url.lastPathComponent,
            url: url,
            isDirectory: true,
            children: []
        )

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            return node
        }

        node.children = contents.compactMap { childURL in
            let name = childURL.lastPathComponent
            if name.hasSuffix(".source") || name == ".writepilot" {
                return nil
            }

            let resourceValues = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDir = resourceValues?.isDirectory ?? false

            if isDir {
                return scanDirectory(url: childURL)
            } else {
                return FileNode(
                    name: childURL.lastPathComponent,
                    url: childURL,
                    isDirectory: false
                )
            }
        }

        return node
    }

    // MARK: - File CRUD

    func readFile(url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppError.fileNotFound(url)
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw AppError.fileAccessDenied(url)
        }
    }

    func writeFile(url: URL, content: String) throws {
        suppressWatcher = true
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw AppError.fileWriteFailed(url, error)
        }
    }

    func createFile(in directory: URL, name: String) throws -> URL {
        let fileURL = directory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AppError.fileWriteFailed(fileURL, NSError(domain: "WritePilot", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "檔案已存在"
            ]))
        }
        suppressWatcher = true
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func createFolder(in directory: URL, name: String) throws -> URL {
        let folderURL = directory.appendingPathComponent(name)
        suppressWatcher = true
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }

    func rename(url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        suppressWatcher = true
        try FileManager.default.moveItem(at: url, to: newURL)
        return newURL
    }

    func delete(url: URL) throws {
        suppressWatcher = true
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)

        // Also delete the .source sidecar if it exists
        let sourceURL = url.appendingPathExtension("source")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
        }
    }

    // MARK: - File Watching

    private func startWatching(url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            // Debounce: wait briefly for batch changes (e.g. git operations)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                if self.suppressWatcher {
                    self.suppressWatcher = false
                    return
                }
                self.rescan()
                self.externalChangeDetected = true
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        watcherSource = source
        watcherFD = fd
    }

    private func stopWatching() {
        watcherSource?.cancel()
        watcherSource = nil
        watcherFD = -1
    }

    // MARK: - Helpers

    func findNode(for url: URL, in node: FileNode? = nil) -> FileNode? {
        let searchNode = node ?? rootNode
        guard let searchNode else { return nil }

        if searchNode.url == url { return searchNode }

        if let children = searchNode.children {
            for child in children {
                if let found = findNode(for: url, in: child) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - Expansion State Persistence

    func saveExpansionState() {
        guard let root = rootNode, let base = workspaceURL else { return }
        var collapsed: [String] = []
        collectCollapsed(node: root, base: base, into: &collapsed)
        UserDefaults.standard.set(collapsed, forKey: Self.collapsedKey)
    }

    private func collectCollapsed(node: FileNode, base: URL, into collapsed: inout [String]) {
        guard node.isDirectory else { return }
        if !node.isExpanded {
            let relative = node.url.path.replacingOccurrences(of: base.path, with: "")
            collapsed.append(relative)
        }
        for child in node.children ?? [] {
            collectCollapsed(node: child, base: base, into: &collapsed)
        }
    }

    private func restoreExpansionState() {
        guard let root = rootNode, let base = workspaceURL else { return }
        let collapsed = Set(UserDefaults.standard.stringArray(forKey: Self.collapsedKey) ?? [])
        guard !collapsed.isEmpty else { return }
        applyCollapsed(node: root, base: base, collapsed: collapsed)
    }

    private func applyCollapsed(node: FileNode, base: URL, collapsed: Set<String>) {
        guard node.isDirectory else { return }
        let relative = node.url.path.replacingOccurrences(of: base.path, with: "")
        if collapsed.contains(relative) {
            node.isExpanded = false
        }
        for child in node.children ?? [] {
            applyCollapsed(node: child, base: base, collapsed: collapsed)
        }
    }
}
