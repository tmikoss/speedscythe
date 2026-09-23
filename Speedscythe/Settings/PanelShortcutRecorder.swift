import AppKit
import KeyboardShortcuts
import SwiftUI

struct PanelShortcutRecorder: View {
    let title: LocalizedStringKey
    let name: KeyboardShortcuts.Name

    init(_ title: LocalizedStringKey, name: KeyboardShortcuts.Name) {
        self.title = title
        self.name = name
    }

    var body: some View {
        LabeledContent {
            Field(name: name)
        } label: {
            Text(title)
        }
    }

    private struct Field: NSViewRepresentable {
        let name: KeyboardShortcuts.Name

        func makeNSView(context: Context) -> PanelShortcutField {
            PanelShortcutField(name: name)
        }

        func updateNSView(_ nsView: PanelShortcutField, context: Context) {}
    }
}

// A copy of KeyboardShortcuts.RecorderCocoa that also records keys without modifiers, for shortcuts that only the panel matches.
final class PanelShortcutField: NSSearchField, NSSearchFieldDelegate {
    private static let minimumWidth = 130.0
    // KeyboardShortcuts posts this notification when a stored shortcut changes, but it does not make the name public.
    private static let shortcutDidChange = Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")

    private let name: KeyboardShortcuts.Name
    private var canBecomeKey = false
    private var cancelButton: NSButtonCell?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    private var searchCell: NSSearchFieldCell? {
        cell as? NSSearchFieldCell
    }

    init(name: KeyboardShortcuts.Name) {
        self.name = name
        super.init(frame: NSRect(x: 0, y: 0, width: Self.minimumWidth, height: 24))
        delegate = self
        placeholderString = "Record Shortcut"
        alignment = .center
        searchCell?.searchButtonCell = nil
        wantsLayer = true
        setContentHuggingPriority(.defaultHigh, for: .vertical)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelButton = searchCell?.cancelButtonCell
        updateStringValue()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeKeyView: Bool { canBecomeKey }

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = Self.minimumWidth
        return size
    }

    // On macOS 27 and later, NSSearchField lays out its text in a clip view or a label subview. This mirrors the inset of the cancel button to the left, so that the text is centered in the full field.
    override func layout() {
        super.layout()
        guard #available(macOS 27, *) else { return }
        for subview in subviews {
            let className = NSStringFromClass(type(of: subview))
            guard className.contains("ClipView") || className.contains("SimpleLabel") else { continue }
            let rightInset = bounds.width - subview.frame.maxX
            guard rightInset > subview.frame.minX else { continue }
            subview.frame = NSRect(x: rightInset, y: subview.frame.minY, width: bounds.width - rightInset * 2, height: subview.frame.height)
        }
    }

    override func viewDidMoveToWindow() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        guard let window else {
            endRecording()
            return
        }
        updateStringValue()
        observers = [
            NotificationCenter.default.addObserver(forName: Self.shortcutDidChange, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateStringValue()
                }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.endRecording()
                    self?.window?.makeFirstResponder(nil)
                }
            },
            NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.preventBecomingKey()
                }
            },
        ]
        preventBecomingKey()
    }

    override func becomeFirstResponder() -> Bool {
        guard window != nil, super.becomeFirstResponder() else { return false }
        placeholderString = "Press Shortcut"
        showCancelButton(!stringValue.isEmpty)
        setCaretColor(.clear)
        if keyMonitor == nil {
            // The global picker hotkey would otherwise take the key press before the field can record it.
            KeyboardShortcuts.isEnabled = false
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseUp, .rightMouseUp]) { [weak self] event in
                let passesThrough = MainActor.assumeIsolated {
                    self?.passesThrough(event) ?? true
                }
                return passesThrough ? event : nil
            }
        }
        return true
    }

    func controlTextDidChange(_ notification: Notification) {
        if stringValue.isEmpty {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        showCancelButton(!stringValue.isEmpty)
        if stringValue.isEmpty {
            // The placeholder is centered only after the field becomes first responder again.
            window?.makeFirstResponder(self)
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        setCaretColor(.labelColor)
        // On macOS 26 and later, AppKit ends and restarts editing internally and posts this notification for each restart. On the next turn, a restart has an active field editor again, and a real end does not.
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let editor = currentEditor(), window?.firstResponder === editor {
                setCaretColor(.clear)
                return
            }
            endRecording()
        }
    }

    private func passesThrough(_ event: NSEvent) -> Bool {
        if event.type == .leftMouseUp || event.type == .rightMouseUp {
            if !isMousePoint(convert(event.locationInWindow, from: nil), in: bounds.insetBy(dx: -3, dy: -3)) {
                window?.makeFirstResponder(nil)
            }
            return true
        }
        if event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            switch event.specialKey {
            case .tab:
                window?.makeFirstResponder(nil)
                return true
            case .delete, .deleteForward, .backspace:
                searchCell?.cancelButtonCell?.performClick(self)
                return false
            default:
                break
            }
            if event.keyCode == 53 {
                window?.makeFirstResponder(nil)
                return false
            }
            if PanelController.digitKeyCodes[event.keyCode] != nil {
                NSSound.beep()
                return false
            }
        }
        guard let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return false
        }
        stringValue = "\(shortcut)"
        showCancelButton(true)
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        window?.makeFirstResponder(nil)
        return false
    }

    private func endRecording() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
        KeyboardShortcuts.isEnabled = true
        placeholderString = "Record Shortcut"
        showCancelButton(!stringValue.isEmpty)
        setCaretColor(.labelColor)
    }

    private func preventBecomingKey() {
        canBecomeKey = false
        Task { @MainActor [weak self] in
            self?.canBecomeKey = true
        }
    }

    private func updateStringValue() {
        stringValue = KeyboardShortcuts.getShortcut(for: name).map { "\($0)" } ?? ""
        showCancelButton(!stringValue.isEmpty)
    }

    private func showCancelButton(_ isShown: Bool) {
        searchCell?.cancelButtonCell = isShown ? cancelButton : nil
    }

    private func setCaretColor(_ color: NSColor) {
        (currentEditor() as? NSTextView)?.insertionPointColor = color
    }
}
