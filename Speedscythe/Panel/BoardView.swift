import AppKit
import KeyboardShortcuts
import SwiftUI

enum BoardEdit {
    case pick(slot: Int)
    case clear(slot: Int)
    case moveTask(slot: Int, from: Int, to: Int)
    case addSlot
    case removeSlot
}

struct BoardView: View {
    enum Content: Equatable {
        case notConnected
        case loading
        case loadFailed(String)
        case noProjects
        case board
    }

    static let padding: CGFloat = 28
    static let columnGap: CGFloat = 8
    static let cornerRadius: CGFloat = 20

    let store: AppStore
    let preferences: Preferences
    @Bindable var state: PanelState
    let columnWidth: CGFloat
    let onEvent: (BoardEvent) -> Void
    let onEdit: (BoardEdit) -> Void
    let onOpenSettings: () -> Void

    @FocusState private var notesFocused: Bool

    var body: some View {
        let board = BoardModel(store: store, preferences: preferences)
        let content = Self.content(store: store)
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeaderView(
                    store: store,
                    isEditing: state.boardState.isEditing,
                    showsNotesField: state.boardState.showsNotesField,
                    canEdit: content == .board,
                    slotCount: preferences.slotCount,
                    onStop: { onEvent(.stopShortcut) },
                    onEditToggle: { onEvent(.editToggled) },
                    onEdit: onEdit
                )
                if state.boardState.showsNotesField {
                    TextField("Notes", text: $state.notesDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 15))
                        .focused($notesFocused)
                        .disabled(state.boardState == .savingNotes)
                        .onChange(of: state.boardState, initial: true) { _, boardState in
                            // SwiftUI ignores the focus change in the update that inserts the field, because the field is not on screen yet.
                            Task { notesFocused = boardState == .editingNotes }
                        }
                }
                if let session = store.session, session.expiresSoon(at: .now) {
                    HStack(spacing: 12) {
                        Text("Harvest connection expires soon")
                            .font(.system(size: 13))
                        Button("Reconnect") { store.auth.connect() }
                            .focusable(false)
                    }
                }
                if let errorMessage = state.errorMessage ?? (content == .board ? store.errorMessage : nil) {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            if content == .board {
                columns(board: board)
                    .opacity(state.boardState.showsNotesField ? 0.38 : 1)
                    .allowsHitTesting(!state.boardState.showsNotesField)
                Text(hint(for: board))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            } else {
                message(for: content)
            }
        }
        .padding(Self.padding)
        .frame(width: width(columnCount: Self.columnCount(board: board, state: state.boardState, preferences: preferences)))
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack {
                VisualEffectBackground(cornerRadius: Self.cornerRadius)
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(Color(nsColor: .separatorColor)))
    }

    @MainActor
    static func content(store: AppStore) -> Content {
        if store.session == nil {
            return .notConnected
        }
        if !store.assignments.contains(where: \.isActive) {
            if store.lastRefresh != nil {
                return .noProjects
            }
            if let errorMessage = store.errorMessage, !store.isRefreshing {
                return .loadFailed(errorMessage)
            }
            return .loading
        }
        return .board
    }

    @ViewBuilder
    private func message(for content: Content) -> some View {
        VStack(spacing: 12) {
            switch content {
            case .notConnected:
                Text("Connect your Harvest account to start timers")
                    .font(.system(size: 15, weight: .semibold))
                if store.auth.isConnecting {
                    Text("Waiting for Harvest in your browser…")
                        .foregroundStyle(.secondary)
                } else if let errorMessage = store.errorMessage ?? store.auth.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Connect") { store.auth.connect() }
                    Button("Open Settings", action: onOpenSettings)
                }
            case .loading:
                ProgressView()
                    .controlSize(.small)
                Text("Loading projects…")
                    .foregroundStyle(.secondary)
            case .loadFailed(let errorMessage):
                Text("Speedscythe cannot load your projects")
                    .font(.system(size: 15, weight: .semibold))
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                Button("Try Again") { store.refreshInBackground() }
            case .noProjects:
                Text("No projects are assigned to you in Harvest.")
                    .font(.system(size: 15, weight: .semibold))
            case .board:
                EmptyView()
            }
        }
        .font(.system(size: 13))
        .multilineTextAlignment(.center)
        .focusable(false)
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func columns(board: BoardModel) -> some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            if state.boardState.isEditing {
                ForEach(0..<preferences.slotCount, id: \.self) { slot in
                    let column = board.columns.first { $0.slot == slot }
                    EditSlotView(
                        number: slot + 1,
                        column: column,
                        isPinned: column.map { preferences.pinnedSlots[slot] == $0.project.id } ?? false,
                        rowCount: board.visibleRowCount,
                        onPick: { onEdit(.pick(slot: slot)) },
                        onClear: { onEdit(.clear(slot: slot)) },
                        onMoveTask: { from, to in onEdit(.moveTask(slot: slot, from: from, to: to)) }
                    )
                    .frame(width: columnWidth)
                }
            } else {
                ForEach(Array(board.columns.enumerated()), id: \.element.id) { index, column in
                    ProjectColumnView(
                        store: store,
                        number: column.number,
                        column: column,
                        rowCount: board.visibleRowCount,
                        emphasis: emphasis(for: index),
                        startingTask: startingTask(in: index),
                        onHeaderClick: { onEvent(.columnClicked(index)) },
                        onTileClick: { task in onEvent(.tileClicked(column: index, task: task)) }
                    )
                    .frame(width: columnWidth)
                }
            }
        }
    }

    @MainActor
    static func columnCount(board: BoardModel, state: BoardState, preferences: Preferences) -> Int {
        state.isEditing ? preferences.slotCount : board.columns.count
    }

    private func emphasis(for column: Int) -> ProjectColumnView.Emphasis {
        guard let selected = state.boardState.selectedColumn else { return .normal }
        return selected == column ? .selected : .dimmed
    }

    private func startingTask(in column: Int) -> Int? {
        if case .starting(column, let task) = state.boardState {
            return task
        }
        return nil
    }

    private func width(columnCount: Int) -> CGFloat {
        let columnsWidth = CGFloat(columnCount) * columnWidth + CGFloat(max(columnCount - 1, 0)) * Self.columnGap
        let minColumns = CGFloat(Preferences.slotRange.lowerBound)
        return max(columnsWidth, minColumns * columnWidth + (minColumns - 1) * Self.columnGap) + Self.padding * 2
    }

    private func hint(for board: BoardModel) -> String {
        switch state.boardState {
        case .idle:
            "\(Self.range(board.maxProjectNumber)) project, then \(Self.range(board.maxTaskKeyCount)) task · or click any tile\(notesHint) · Esc close"
        case .projectSelected(let column) where board.columns.indices.contains(column):
            "\(board.columns[column].project.name): press \(Self.range(min(9, board.columns[column].tasks.count))) for a task · Esc back"
        case .projectSelected:
            "Esc back"
        case .starting:
            "Starting timer…"
        case .editing:
            "Click a column to pick its project · Esc done"
        case .editingNotes:
            "Enter save · Esc cancel"
        case .savingNotes:
            "Saving notes…"
        }
    }

    private var notesHint: String {
        guard store.runningEntry != nil, let shortcut = KeyboardShortcuts.getShortcut(for: .editNotes) else { return "" }
        return " · \(shortcut.description) notes"
    }

    private static func range(_ count: Int) -> String {
        count > 1 ? "1–\(count)" : "1"
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.maskImage(cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func maskImage(cornerRadius: CGFloat) -> NSImage {
        let edge = cornerRadius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        image.resizingMode = .stretch
        return image
    }
}
