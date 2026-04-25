import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var workspaceURL: URL?
    var sourceTracker: SourceTracker?
    var dailyWordCount: DailyWordCountService?
    var onTextChange: ((String) -> Void)?
    var onCursorChange: ((Int, Int) -> Void)?
    var onSelectionChange: ((String, NSRange) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.drawsBackground = false

        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

        context.coordinator.textView = textView

        // Set initial text
        textView.string = text
        context.coordinator.lastSyncedText = text
        if let ts = textView.textStorage {
            context.coordinator.highlighter.applyHighlighting(to: ts)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Keep coordinator's parent reference up to date
        context.coordinator.parent = self

        // Skip during IME composition
        guard !textView.hasMarkedText() else { return }

        // Only overwrite textView if the change came from OUTSIDE (e.g. file reload, AI apply)
        // If text == lastSyncedText, it means the binding value matches what textDidChange
        // last wrote, so this is just SwiftUI re-rendering — no need to touch the textView.
        if text != context.coordinator.lastSyncedText {
            context.coordinator.isUpdating = true
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.lastSyncedText = text
            if let ts = textView.textStorage {
                context.coordinator.highlighter.applyHighlighting(to: ts)
            }
            context.coordinator.isUpdating = false
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        var isUpdating = false
        var lastSyncedText: String = ""
        var lastInputWasPaste = false
        var lastReplacementLength = 0
        var lastDeletedLength = 0
        weak var textView: NSTextView?
        let highlighter = MarkdownHighlighter()

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        /// Detect paste: called before text changes. If replacement is multi-char, it's a paste.
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isUpdating else { return true }
            if let replacement = replacementString {
                // Only count non-whitespace characters
                let contentCount = replacement.filter { !$0.isWhitespace && !$0.isNewline }.count
                let deletedContent = affectedCharRange.length > 0
                    ? (textView.string as NSString).substring(with: affectedCharRange)
                        .filter { !$0.isWhitespace && !$0.isNewline }.count
                    : 0

                lastDeletedLength = deletedContent
                lastReplacementLength = contentCount

                // A single raw character = typing; multiple = paste
                lastInputWasPaste = replacement.count > 1
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true

            let newText = textView.string
            parent.text = newText
            lastSyncedText = newText
            parent.onTextChange?(newText)

            // Track source: deletions reduce proportionally, additions add to typed or pasted
            if lastDeletedLength > 0 {
                parent.sourceTracker?.removeChars(count: lastDeletedLength)
                lastDeletedLength = 0
            }
            if lastReplacementLength > 0 {
                if lastInputWasPaste {
                    parent.sourceTracker?.addPasted(count: lastReplacementLength)
                } else {
                    parent.sourceTracker?.addTyped(count: lastReplacementLength)
                }
                parent.dailyWordCount?.addChars(count: lastReplacementLength)
                lastReplacementLength = 0
            }

            // Re-highlight the edited region
            if let ts = textView.textStorage {
                let editedRange = ts.editedRange
                if editedRange.location != NSNotFound {
                    highlighter.applyHighlighting(to: ts, in: editedRange)
                } else {
                    highlighter.applyHighlighting(to: ts)
                }
            }

            isUpdating = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let line = string.substring(to: selectedRange.location)
                .components(separatedBy: "\n").count
            let column = selectedRange.location - lineRange.location + 1
            parent.onCursorChange?(line, column)

            if selectedRange.length > 0 {
                let selectedText = string.substring(with: selectedRange)
                parent.onSelectionChange?(selectedText, selectedRange)
            } else {
                parent.onSelectionChange?("", selectedRange)
            }
        }

        func replaceSelection(with text: String) {
            guard let textView else { return }
            let range = textView.selectedRange()
            if range.length > 0 {
                isUpdating = true
                textView.insertText(text, replacementRange: range)
                let newText = textView.string
                parent.text = newText
                lastSyncedText = newText
                isUpdating = false
            }
        }

        // MARK: - Image Drag & Drop

        private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]

        func textView(_ textView: NSTextView, draggedFilesAt urls: [URL]) -> Bool {
            handleImageDrop(urls: urls, textView: textView)
        }

        private func handleImageDrop(urls: [URL], textView: NSTextView) -> Bool {
            guard let workspaceURL = parent.workspaceURL else { return false }

            let fm = FileManager.default
            let imagesDir = workspaceURL.appendingPathComponent("images")

            if !fm.fileExists(atPath: imagesDir.path) {
                try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            }

            var insertedAny = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                guard Self.imageExtensions.contains(ext) else { continue }

                let destURL = imagesDir.appendingPathComponent(url.lastPathComponent)

                if !fm.fileExists(atPath: destURL.path) {
                    do {
                        try fm.copyItem(at: url, to: destURL)
                    } catch {
                        continue
                    }
                }

                let mdText = "![](images/\(url.lastPathComponent))"
                let insertRange = textView.selectedRange()
                isUpdating = true
                textView.insertText("\n\(mdText)\n", replacementRange: insertRange)
                let newText = textView.string
                parent.text = newText
                lastSyncedText = newText
                parent.onTextChange?(newText)
                isUpdating = false
                insertedAny = true
            }

            return insertedAny
        }
    }
}
