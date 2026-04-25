import SwiftUI
import Sparkle

// MARK: - Menu bar bridge

@Observable
final class MenuBarBridge {
    var wordCountService: DailyWordCountService?
}

private struct MenuBarRoot: View {
    let bridge: MenuBarBridge
    var body: some View {
        if let service = bridge.wordCountService {
            MenuBarWordCountView(service: service)
        } else {
            Color.clear.frame(width: 260, height: 1)
        }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let bridge = MenuBarBridge()
    private var labelHostingView: NSHostingView<AnyView>?
    private weak var observedService: DailyWordCountService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.line",
                                   accessibilityDescription: "Write Pilot")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hc = NSHostingController(rootView: MenuBarRoot(bridge: bridge))
        let p = NSPopover()
        p.contentViewController = hc
        p.behavior = .transient
        p.animates = false
        popover = p
    }

    func attachWordCount(service: DailyWordCountService) {
        observedService = service
        bridge.wordCountService = service
        setupLabel(service: service)
        observeLabelChanges()
    }

    private func setupLabel(service: DailyWordCountService) {
        guard let button = statusItem?.button else { return }
        button.image = nil
        labelHostingView?.removeFromSuperview()

        let view = NSHostingView(rootView: AnyView(MenuBarWordCountLabel(service: service)))
        view.sizingOptions = .intrinsicContentSize
        view.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        labelHostingView = view
        updateStatusItemLength()
    }

    private func observeLabelChanges() {
        guard let service = observedService else { return }
        withObservationTracking {
            _ = service.todayCount
        } onChange: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self?.updateStatusItemLength()
                self?.observeLabelChanges()
            }
        }
    }

    private func updateStatusItemLength() {
        guard let view = labelHostingView else { return }
        let width = view.intrinsicContentSize.width
        statusItem?.length = max(width + 4, 26)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let win = popover.contentViewController?.view.window {
                win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                win.makeKey()
            }
        }
    }
}

// MARK: - App

@main
struct WritePilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var fileService = FileService()
    @State private var dailyWordCount = DailyWordCountService()
    private let aiService = AIService()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup {
            ContentView(aiService: aiService, dailyWordCount: dailyWordCount)
                .environment(fileService)
                .onAppear {
                    // 滿版啟動
                    if let screen = NSScreen.main {
                        let frame = screen.visibleFrame
                        if let window = NSApp.windows.first {
                            window.setFrame(frame, display: true)
                        }
                    }
                    _ = fileService.restoreWorkspace()
                    Task {
                        if let key = KeychainService.retrieve() {
                            await aiService.configure(apiKey: key)
                        }
                    }
                    appDelegate.attachWordCount(service: dailyWordCount)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            WritePilotCommands(fileService: fileService)
        }

        Settings {
            SettingsView(aiService: aiService, updater: updaterController.updater)
                .environment(fileService)
        }
    }
}
