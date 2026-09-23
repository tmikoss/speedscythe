import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(store: AppStore, preferences: Preferences) {
        let hostingController = NSHostingController(rootView: SettingsView(store: store, preferences: preferences))
        hostingController.sceneBridgingOptions = .all
        window = NSWindow(contentViewController: hostingController)
        window.title = "Speedscythe Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
