import AppKit
import KeyboardShortcuts
import Observation

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: AppStore
    private let timerService: TimerService
    private let openPicker: () -> Void
    private let openEditor: () -> Void
    private let openSettings: () -> Void
    private let runningItem = NSMenuItem(title: "No timer running", action: nil, keyEquivalent: "")
    private let stopItem = NSMenuItem(title: "Stop timer", action: nil, keyEquivalent: "")
    private var refreshTimer: Timer?

    init(
        store: AppStore,
        timerService: TimerService,
        openPicker: @escaping () -> Void,
        openEditor: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.store = store
        self.timerService = timerService
        self.openPicker = openPicker
        self.openEditor = openEditor
        self.openSettings = openSettings
        super.init()

        statusItem.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        runningItem.isEnabled = false
        menu.addItem(runningItem)
        stopItem.target = self
        stopItem.action = #selector(stopSelected)
        menu.addItem(stopItem)
        menu.addItem(.separator())
        let pickerItem = NSMenuItem(title: "Open picker", action: #selector(pickerSelected), keyEquivalent: "")
        pickerItem.target = self
        pickerItem.setShortcut(for: .openPicker)
        menu.addItem(pickerItem)
        let editorItem = NSMenuItem(title: "Edit board…", action: #selector(editorSelected), keyEquivalent: "")
        editorItem.target = self
        menu.addItem(editorItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsSelected), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Speedscythe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        observeStore()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateButton()
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let runningEntry = store.runningEntry {
            runningItem.title = "\(runningEntry.project.name) · \(runningEntry.task.name)"
        } else {
            runningItem.title = "No timer running"
        }
        stopItem.isEnabled = store.runningEntry != nil
    }

    private func observeStore() {
        withObservationTracking {
            updateButton()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeStore()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        if store.session == nil || store.errorMessage != nil {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Speedscythe needs attention")
            button.title = ""
        } else {
            let image = NSImage(named: "MenuBarIcon")
            image?.accessibilityDescription = "Speedscythe"
            button.image = image
            button.title = store.runningElapsed(at: .now).map { " \(ElapsedFormat.hoursMinutes($0))" } ?? ""
        }
    }

    @objc private func stopSelected() {
        Task {
            do {
                try await timerService.stop()
            } catch {
                store.reportError(error.localizedDescription)
            }
        }
    }

    @objc private func pickerSelected() {
        openPicker()
    }

    @objc private func editorSelected() {
        openEditor()
    }

    @objc private func settingsSelected() {
        openSettings()
    }
}
