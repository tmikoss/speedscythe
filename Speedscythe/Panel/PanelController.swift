import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@MainActor
@Observable
final class PanelState {
    var boardState: BoardState = .idle
    var errorMessage: String?
    var notesDraft = ""
    var notesEntryID: Int?
}

extension BoardModel {
    @MainActor
    init(store: AppStore, preferences: Preferences) {
        self.init(
            assignments: store.assignments,
            slots: Self.slotResolution(store: store, preferences: preferences).slots,
            taskOrders: preferences.taskOrders
        )
    }

    @MainActor
    static func slotResolution(store: AppStore, preferences: Preferences) -> SlotResolution {
        SlotResolver.resolve(
            pinned: preferences.pinnedSlots,
            slotCount: preferences.slotCount,
            recentOrder: store.recentProjectOrder,
            previousRecentSlots: preferences.recentSlotAssignments,
            activeProjects: Set(store.assignments.filter(\.isActive).map(\.project.id))
        )
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let naturalColumnWidth: CGFloat = 164
    private static let minColumnWidth: CGFloat = 120
    private static let screenMargin: CGFloat = 80
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    private let store: AppStore
    private let preferences: Preferences
    private let timerService: TimerService
    private let state = PanelState()
    private let panel = PickerPanel()
    private let openSettings: () -> Void
    private let hostingView: NSHostingView<BoardView>
    private var keyMonitor: Any?
    private var observesLayout = false

    private var board: BoardModel {
        BoardModel(store: store, preferences: preferences)
    }

    init(store: AppStore, preferences: Preferences, timerService: TimerService, openSettings: @escaping () -> Void) {
        self.store = store
        self.preferences = preferences
        self.timerService = timerService
        self.openSettings = openSettings
        hostingView = NSHostingView(
            rootView: BoardView(
                store: store,
                preferences: preferences,
                state: state,
                columnWidth: Self.naturalColumnWidth,
                onEvent: { _ in },
                onEdit: { _ in },
                onOpenSettings: {}
            )
        )
        super.init()
        panel.contentView = hostingView
        panel.delegate = self
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show(editing: Bool = false) {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }

        state.boardState = editing ? .editing : .idle
        state.errorMessage = nil
        layout(on: screen)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()

        if store.lastRefresh.map({ Date.now.timeIntervalSince($0) > 30 }) ?? true {
            store.refreshInBackground()
        }
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func layout(on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        if !store.assignments.isEmpty {
            preferences.recentSlotAssignments = BoardModel.slotResolution(store: store, preferences: preferences).recentSlots
        }
        let columnCount = BoardView.columnCount(board: board, state: state.boardState, preferences: preferences)
        hostingView.rootView = BoardView(
            store: store,
            preferences: preferences,
            state: state,
            columnWidth: columnWidth(columnCount: columnCount, availableWidth: visibleFrame.width - Self.screenMargin),
            onEvent: { [weak self] event in self?.handle(event) },
            onEdit: { [weak self] edit in self?.handle(edit) },
            onOpenSettings: { [weak self] in
                self?.hide()
                self?.openSettings()
            }
        )

        let size = hostingView.fittingSize
        panel.setFrame(
            NSRect(x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2, width: size.width, height: size.height),
            display: true
        )
        panel.invalidateShadow()
        observeLayout()
    }

    private func observeLayout() {
        guard !observesLayout else { return }
        observesLayout = true
        withObservationTracking {
            _ = board
            _ = BoardView.content(store: store)
            _ = state.errorMessage
            _ = store.errorMessage
            _ = store.auth.isConnecting
            _ = store.auth.errorMessage
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observesLayout = false
                if self.panel.isVisible {
                    self.relayout()
                }
            }
        }
    }

    private func relayout() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        layout(on: screen)
    }

    private func handle(_ edit: BoardEdit) {
        switch edit {
        case .pick(let slot):
            showProjectMenu(slot: slot)
            return
        case .clear(let slot):
            preferences.pinnedSlots[slot] = nil
        case .moveTask(let slot, let from, let to):
            guard let column = board.columns.first(where: { $0.slot == slot }) else { return }
            var taskIDs = column.tasks.map(\.id)
            taskIDs.insert(taskIDs.remove(at: from), at: to)
            preferences.taskOrders[column.project.id] = taskIDs
        case .addSlot:
            preferences.slotCount = min(preferences.slotCount + 1, Preferences.slotRange.upperBound)
        case .removeSlot:
            guard preferences.slotCount > Preferences.slotRange.lowerBound else { return }
            preferences.slotCount -= 1
            preferences.pinnedSlots[preferences.slotCount] = nil
        }
        relayout()
    }

    private func showProjectMenu(slot: Int) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let assignments = store.assignments
            .filter(\.isActive)
            .sorted { "\($0.client.name) — \($0.project.name)".localizedCaseInsensitiveCompare("\($1.client.name) — \($1.project.name)") == .orderedAscending }
        let pinnedElsewhere = Set(preferences.pinnedSlots.filter { $0.key != slot }.values)
        var clientID: Int?
        for assignment in assignments {
            if assignment.client.id != clientID {
                clientID = assignment.client.id
                menu.addItem(.sectionHeader(title: assignment.client.name))
            }
            let item = NSMenuItem(title: assignment.project.name, action: #selector(projectPicked(_:)), keyEquivalent: "")
            item.target = self
            item.tag = slot
            item.representedObject = assignment.project.id
            item.state = preferences.pinnedSlots[slot] == assignment.project.id ? .on : .off
            item.isEnabled = !pinnedElsewhere.contains(assignment.project.id)
            menu.addItem(item)
        }
        let windowLocation = panel.mouseLocationOutsideOfEventStream
        menu.popUp(positioning: nil, at: hostingView.convert(windowLocation, from: nil), in: hostingView)
    }

    @objc private func projectPicked(_ item: NSMenuItem) {
        guard let projectID = item.representedObject as? Int else { return }
        preferences.pinnedSlots[item.tag] = projectID
        relayout()
    }

    private func handle(_ event: BoardEvent) {
        let (boardState, effect) = BoardState.reduce(state.boardState, event, board: board)
        let layoutChanged = boardState.isEditing != state.boardState.isEditing || boardState.showsNotesField != state.boardState.showsNotesField
        if boardState == .editingNotes, !state.boardState.showsNotesField, let runningEntry = store.runningEntry {
            state.notesDraft = (runningEntry.notes ?? "").replacingOccurrences(of: "\n", with: " ")
            state.notesEntryID = runningEntry.id
            panel.makeFirstResponder(hostingView)
        }
        state.boardState = boardState
        if layoutChanged {
            relayout()
        }
        switch effect {
        case .close:
            hide()
        case .stop:
            state.errorMessage = nil
            Task {
                do {
                    try await timerService.stop()
                } catch {
                    state.errorMessage = error.localizedDescription
                }
            }
        case .start(let projectID, let taskID):
            state.errorMessage = nil
            Task {
                do {
                    try await timerService.start(projectID: projectID, taskID: taskID, source: .picker)
                    handle(.startSucceeded)
                } catch {
                    state.errorMessage = error.localizedDescription
                    handle(.startFailed)
                }
            }
        case .saveNotes:
            guard let entryID = state.notesEntryID else { return }
            state.errorMessage = nil
            Task {
                do {
                    try await timerService.updateNotes(entryID: entryID, notes: state.notesDraft)
                    handle(.notesSaved)
                } catch {
                    state.errorMessage = error.localizedDescription
                    handle(.notesFailed)
                }
            }
        case nil:
            break
        }
    }

    private func boardEvent(for event: NSEvent) -> BoardEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 53 {
            return .escape
        }
        let shortcut = KeyboardShortcuts.Shortcut(event: event)
        if let shortcut, shortcut == KeyboardShortcuts.getShortcut(for: .stopTimer) {
            return .stopShortcut
        }
        if let shortcut, shortcut == KeyboardShortcuts.getShortcut(for: .editNotes), store.runningEntry != nil {
            return .notesShortcut
        }
        if modifiers.isEmpty, let digit = Self.digitKeyCodes[event.keyCode] {
            return .digit(digit)
        }
        return nil
    }

    private func columnWidth(columnCount: Int, availableWidth: CGFloat) -> CGFloat {
        guard columnCount > 0 else { return Self.naturalColumnWidth }
        let chrome = BoardView.padding * 2 + BoardView.columnGap * CGFloat(columnCount - 1)
        let fittingWidth = (availableWidth - chrome) / CGFloat(columnCount)
        return max(Self.minColumnWidth, min(Self.naturalColumnWidth, fittingWidth))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let passesThrough = MainActor.assumeIsolated {
                guard let self else { return false }
                switch self.state.boardState {
                case .editingNotes:
                    switch event.keyCode {
                    case 53:
                        self.handle(.escape)
                    case 36, 76:
                        self.handle(.submit)
                    default:
                        return true
                    }
                case .savingNotes:
                    break
                default:
                    if let boardEvent = self.boardEvent(for: event) {
                        self.handle(boardEvent)
                    }
                }
                return false
            }
            return passesThrough ? event : nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}
