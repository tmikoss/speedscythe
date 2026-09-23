import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore(auth: AuthService())
    private let preferences = Preferences()
    private var settingsWindowController: SettingsWindowController?
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        let timerService = TimerService(context: store, continueToday: { [preferences] in preferences.continueToday })
        let settingsWindowController = SettingsWindowController(store: store, preferences: preferences)
        let panelController = PanelController(
            store: store,
            preferences: preferences,
            timerService: timerService,
            openSettings: { settingsWindowController.show() }
        )
        self.settingsWindowController = settingsWindowController
        self.panelController = panelController
        HotkeyService.register { panelController.toggle() }
        statusItemController = StatusItemController(
            store: store,
            timerService: timerService,
            openPicker: { panelController.show() },
            openEditor: { panelController.show(editing: true) },
            openSettings: { settingsWindowController.show() }
        )
    }
}
