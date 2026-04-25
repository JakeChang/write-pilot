import Foundation

@Observable
class FileNode: Identifiable {
    var id: String { url.path }
    var name: String
    var url: URL
    var isDirectory: Bool
    var children: [FileNode]?
    var isExpanded: Bool

    init(
        name: String,
        url: URL,
        isDirectory: Bool,
        children: [FileNode]? = nil,
        isExpanded: Bool = true
    ) {
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.isExpanded = isExpanded
    }

    /// `children == nil` means this is a file; `[]` means empty folder
    var isFile: Bool { children == nil }

    var sortedChildren: [FileNode]? {
        children?.sorted { lhs, rhs in
            // Folders first, then alphabetical
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    var isMarkdown: Bool {
        fileExtension == "md" || fileExtension == "markdown"
    }
}

extension FileNode: Hashable {
    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.url.path == rhs.url.path
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
}
