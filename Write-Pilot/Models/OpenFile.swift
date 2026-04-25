import Foundation

@Observable
class OpenFile: Identifiable {
    let id: UUID
    var node: FileNode
    var content: String
    var hasUnsavedChanges: Bool
    var cursorLine: Int
    var cursorColumn: Int

    init(node: FileNode, content: String = "") {
        self.id = UUID()
        self.node = node
        self.content = content
        self.hasUnsavedChanges = false
        self.cursorLine = 1
        self.cursorColumn = 1
    }

    var fileName: String { node.name }
    var url: URL { node.url }
}

extension OpenFile: Hashable {
    static func == (lhs: OpenFile, rhs: OpenFile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
