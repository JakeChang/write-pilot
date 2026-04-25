import SwiftUI

struct WritePilotCommands: Commands {
    var fileService: FileService

    var body: some Commands {
        // File menu
        CommandGroup(after: .newItem) {
            Button("開啟工作區…") {
                fileService.openWorkspace()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        // Editor menu
        CommandMenu("編輯器") {
            Button("切換來源檢視") {
                NotificationCenter.default.post(name: .toggleSourceView, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }

        // AI menu
        CommandMenu("AI 助手") {
            Button("開啟 AI 建議") {
                NotificationCenter.default.post(name: .openAISuggest, object: nil)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Button("切換助手模式") {
                NotificationCenter.default.post(name: .switchAIMode, object: "assist")
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("切換讀者模式") {
                NotificationCenter.default.post(name: .switchAIMode, object: "reader")
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("切換來源模式") {
                NotificationCenter.default.post(name: .switchAIMode, object: "source")
            }
            .keyboardShortcut("3", modifiers: .command)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleSourceView = Notification.Name("toggleSourceView")
    static let openAISuggest = Notification.Name("openAISuggest")
    static let switchAIMode = Notification.Name("switchAIMode")
}
