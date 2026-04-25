import Foundation
import CoreGraphics

@Observable
class EditorState {
    var selectedText: String = ""
    var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var activeFileURL: URL?
    var replacementText: String?
    var showFloatingMenu = false
    var floatingMenuPosition: CGPoint = .zero

    /// Set by floating menu, consumed by ContentView to trigger AI action
    var pendingAIPrompt: String?
    /// Set to switch AI panel mode (e.g. "reader")
    var switchToAIMode: String?
}
