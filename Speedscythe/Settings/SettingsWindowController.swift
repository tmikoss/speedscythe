import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(store: AppStore) {
        window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
        window.title = "Speedscythe Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
