import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openPicker = Self("openPicker", initial: .init(.t, modifiers: [.control, .option]))
    // No handler is attached to these names, so KeyboardShortcuts never registers them globally. PanelController matches them in the panel only.
    static let stopTimer = Self("stopTimer", initial: .init(.delete))
    static let editNotes = Self("editNotes", initial: .init(.n))
}

@MainActor
enum HotkeyService {
    static func register(onTrigger: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .openPicker, action: onTrigger)
    }
}
