import AppKit

class MarkdownHighlighter {
    private let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    private struct Rule {
        let pattern: String
        let attributes: [NSAttributedString.Key: Any]
        let options: NSRegularExpression.Options

        init(_ pattern: String, _ attributes: [NSAttributedString.Key: Any], options: NSRegularExpression.Options = []) {
            self.pattern = pattern
            self.attributes = attributes
            self.options = options
        }
    }

    private lazy var rules: [(regex: NSRegularExpression, attributes: [NSAttributedString.Key: Any])] = {
        let defs: [Rule] = [
            // Headers
            Rule("^#{1,6}\\s+.+$", [
                .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ], options: .anchorsMatchLines),

            // Bold **text** or __text__
            Rule("(\\*\\*|__)(.+?)(\\1)", [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            ]),

            // Italic *text* or _text_
            Rule("(?<!\\*)(\\*|_)(?!\\*|_)(.+?)(?<!\\*|_)(\\1)(?!\\*|_)", [
                .obliqueness: 0.2
            ]),

            // Inline code `text`
            Rule("`([^`]+)`", [
                .foregroundColor: NSColor.systemPink,
                .backgroundColor: NSColor.quaternaryLabelColor
            ]),

            // Code block ``` (full line)
            Rule("^```.*$", [
                .foregroundColor: NSColor.systemGray,
                .backgroundColor: NSColor.quaternaryLabelColor
            ], options: .anchorsMatchLines),

            // Blockquote > text
            Rule("^>\\s+.+$", [
                .foregroundColor: NSColor.secondaryLabelColor
            ], options: .anchorsMatchLines),

            // Links [text](url)
            Rule("\\[([^\\]]+)\\]\\(([^)]+)\\)", [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]),

            // Images ![alt](url)
            Rule("!\\[([^\\]]*?)\\]\\(([^)]+)\\)", [
                .foregroundColor: NSColor.systemTeal
            ]),

            // List items - or * or +
            Rule("^\\s*[-*+]\\s+", [
                .foregroundColor: NSColor.systemOrange
            ], options: .anchorsMatchLines),

            // Numbered list
            Rule("^\\s*\\d+\\.\\s+", [
                .foregroundColor: NSColor.systemOrange
            ], options: .anchorsMatchLines),

            // Horizontal rule ---
            Rule("^-{3,}$", [
                .foregroundColor: NSColor.separatorColor
            ], options: .anchorsMatchLines),
        ]

        return defs.compactMap { def in
            guard let regex = try? NSRegularExpression(pattern: def.pattern, options: def.options) else {
                return nil
            }
            return (regex: regex, attributes: def.attributes)
        }
    }()

    func applyHighlighting(to textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string

        // Reset to base attributes
        textStorage.addAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)

        // Apply each rule
        for rule in rules {
            rule.regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let matchRange = match?.range else { return }
                textStorage.addAttributes(rule.attributes, range: matchRange)
            }
        }
    }

    func applyHighlighting(to textStorage: NSTextStorage, in editedRange: NSRange) {
        let text = textStorage.string as NSString
        // Expand to full lines around the edit
        let lineRange = text.lineRange(for: editedRange)

        // Reset edited lines
        textStorage.addAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ], range: lineRange)

        // Apply rules only to the affected lines
        let lineText = text.substring(with: lineRange)
        for rule in rules {
            rule.regex.enumerateMatches(
                in: lineText,
                range: NSRange(location: 0, length: lineText.utf16.count)
            ) { match, _, _ in
                guard let matchRange = match?.range else { return }
                let absoluteRange = NSRange(
                    location: matchRange.location + lineRange.location,
                    length: matchRange.length
                )
                guard absoluteRange.location + absoluteRange.length <= textStorage.length else { return }
                textStorage.addAttributes(rule.attributes, range: absoluteRange)
            }
        }
    }
}
