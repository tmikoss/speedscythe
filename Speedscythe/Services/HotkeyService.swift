import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openPicker = Self("openPicker", initial: .init(.t, modifiers: [.control, .option]))
}

@MainActor
enum HotkeyService {
    static func register(onTrigger: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .openPicker, action: onTrigger)
    }
}
