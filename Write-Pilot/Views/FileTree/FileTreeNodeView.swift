import SwiftUI

struct FileTreeNodeView: View {
    @Environment(FileService.self) private var fileService
    let node: FileNode
    var aiService: AIService?

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: Binding(
                get: { node.isExpanded },
                set: {
                    node.isExpanded = $0
                    fileService.saveExpansionState()
                }
            )) {
                if let children = node.sortedChildren {
                    ForEach(children) { child in
                        FileTreeNodeView(node: child, aiService: aiService)
                    }
                }
            } label: {
                FileTreeRow(node: node, aiService: aiService)
                    .tag(node)
            }
        } else {
            FileTreeRow(node: node, aiService: aiService)
                .tag(node)
        }
    }
}
