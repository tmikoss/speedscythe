import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore(auth: AuthService())
    private var settingsWindowController: SettingsWindowController?
    private var panelController: PanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        let timerService = TimerService(context: store)
        let settingsWindowController = SettingsWindowController(store: store)
        let panelController = PanelController(store: store, timerService: timerService)
        self.settingsWindowController = settingsWindowController
        self.panelController = panelController
        HotkeyService.register { panelController.toggle() }
        statusItemController = StatusItemController(
            store: store,
            timerService: timerService,
            openPicker: { panelController.show() },
            openSettings: { settingsWindowController.show() }
        )
    }
}
