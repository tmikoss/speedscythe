import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PanelState {
    var boardState: BoardState = .idle
    var errorMessage: String?
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let slotCount = 6
    private static let naturalColumnWidth: CGFloat = 164
    private static let minColumnWidth: CGFloat = 120
    private static let screenMargin: CGFloat = 80
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    private let store: AppStore
    private let timerService: TimerService
    private let state = PanelState()
    private let panel = PickerPanel()
    private let hostingView: NSHostingView<BoardView>
    private var keyMonitor: Any?

    private var board: BoardModel {
        BoardModel(assignments: store.assignments, projectOrder: store.recentProjectOrder, slotCount: Self.slotCount)
    }

    init(store: AppStore, timerService: TimerService) {
        self.store = store
        self.timerService = timerService
        hostingView = NSHostingView(rootView: BoardView(store: store, state: state, slotCount: Self.slotCount, columnWidth: Self.naturalColumnWidth, onEvent: { _ in }))
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

    func show() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        state.boardState = .idle
        state.errorMessage = nil
        hostingView.rootView = BoardView(
            store: store,
            state: state,
            slotCount: Self.slotCount,
            columnWidth: columnWidth(columnCount: board.columns.count, availableWidth: visibleFrame.width - Self.screenMargin),
            onEvent: { [weak self] event in self?.handle(event) }
        )

        let size = hostingView.fittingSize
        panel.setFrame(
            NSRect(x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2, width: size.width, height: size.height),
            display: true
        )
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
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

    private func handle(_ event: BoardEvent) {
        let (boardState, effect) = BoardState.reduce(state.boardState, event, board: board)
        state.boardState = boardState
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
        case nil:
            break
        }
    }

    private func boardEvent(for event: NSEvent) -> BoardEvent? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 53 {
            return .escape
        }
        if event.keyCode == 51, modifiers == .command {
            return .stopShortcut
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
            MainActor.assumeIsolated {
                if let self, let boardEvent = self.boardEvent(for: event) {
                    self.handle(boardEvent)
                }
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}
