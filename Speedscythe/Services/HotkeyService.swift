import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openPicker = Self("openPicker", initial: .init(.t, modifiers: [.control, .option]))
    // No handler is attached to this name, so KeyboardShortcuts never registers it globally. PanelController matches it in the panel only.
    static let stopTimer = Self("stopTimer", initial: .init(.delete))
}

@MainActor
enum HotkeyService {
    static func register(onTrigger: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .openPicker, action: onTrigger)
    }
}
