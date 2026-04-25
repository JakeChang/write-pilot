import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let markdownContent: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        let html = wrapInHTML(convertMarkdownToHTML(markdownContent))
        context.coordinator.lastContent = markdownContent
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard markdownContent != context.coordinator.lastContent else { return }
        context.coordinator.lastContent = markdownContent
        let html = wrapInHTML(convertMarkdownToHTML(markdownContent))
        webView.loadHTMLString(html, baseURL: nil)
    }

    class Coordinator {
        var lastContent = ""
    }

    // MARK: - Simple Markdown → HTML

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var inList = false

        for line in lines {
            // Code block toggle
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>\n"
                } else {
                    html += "<pre><code>"
                }
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                html += escapeHTML(line) + "\n"
                continue
            }

            // Close list if line is not a list item
            let isListItem = line.matches(of: /^\s*[-*+]\s+/.self).first != nil
                || line.matches(of: /^\s*\d+\.\s+/.self).first != nil
            if inList && !isListItem && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "</ul>\n"
                inList = false
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                if inList {
                    html += "</ul>\n"
                    inList = false
                }
                continue
            }

            // Headers
            if let match = trimmed.firstMatch(of: /^(#{1,6})\s+(.+)$/) {
                let level = match.1.count
                let text = String(match.2)
                html += "<h\(level)>\(inlineFormat(text))</h\(level)>\n"
                continue
            }

            // Horizontal rule
            if trimmed.matches(of: /^-{3,}$/.self).first != nil {
                html += "<hr>\n"
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                let text = String(trimmed.dropFirst(2))
                html += "<blockquote>\(inlineFormat(text))</blockquote>\n"
                continue
            }

            // List items
            if let match = trimmed.firstMatch(of: /^[-*+]\s+(.+)$/) {
                if !inList {
                    html += "<ul>\n"
                    inList = true
                }
                html += "<li>\(inlineFormat(String(match.1)))</li>\n"
                continue
            }

            // Paragraph
            html += "<p>\(inlineFormat(trimmed))</p>\n"
        }

        if inCodeBlock { html += "</code></pre>\n" }
        if inList { html += "</ul>\n" }

        return html
    }

    private func inlineFormat(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images ![alt](url)
        result = result.replacingOccurrences(
            of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)",
            with: "<img src=\"$2\" alt=\"$1\" style=\"max-width:100%\">",
            options: .regularExpression
        )

        // Links [text](url)
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Bold
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic
        result = result.replacingOccurrences(
            of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)",
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Inline code
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "<code class=\"inline\">$1</code>",
            options: .regularExpression
        )

        return result
    }

    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - HTML Template

    private func wrapInHTML(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root {
                color-scheme: light dark;
            }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 15px;
                line-height: 1.7;
                padding: 20px 24px;
                max-width: 720px;
                color: light-dark(#1d1d1f, #f5f5f7);
                background: transparent;
            }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 1.2em;
                margin-bottom: 0.4em;
                font-weight: 600;
            }
            h1 { font-size: 1.8em; }
            h2 { font-size: 1.4em; }
            h3 { font-size: 1.2em; }
            blockquote {
                border-left: 3px solid light-dark(#007aff, #0a84ff);
                margin-left: 0;
                padding: 4px 16px;
                color: light-dark(#6e6e73, #98989d);
                background: light-dark(#f5f5f7, #1c1c1e);
                border-radius: 4px;
            }
            pre {
                background: light-dark(#f5f5f7, #1c1c1e);
                border-radius: 6px;
                padding: 12px 16px;
                overflow-x: auto;
            }
            code {
                font-family: 'SF Mono', Menlo, monospace;
                font-size: 0.9em;
            }
            code.inline {
                background: light-dark(#f5f5f7, #1c1c1e);
                padding: 2px 6px;
                border-radius: 3px;
            }
            a { color: light-dark(#007aff, #0a84ff); }
            hr {
                border: none;
                border-top: 1px solid light-dark(#d2d2d7, #38383a);
                margin: 1.5em 0;
            }
            ul, ol { padding-left: 1.5em; }
            li { margin-bottom: 0.3em; }
            img { max-width: 100%; border-radius: 6px; margin: 8px 0; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
