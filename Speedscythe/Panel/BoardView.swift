import AppKit
import SwiftUI

struct BoardView: View {
    static let padding: CGFloat = 28
    static let columnGap: CGFloat = 8
    static let cornerRadius: CGFloat = 20

    let store: AppStore
    let state: PanelState
    let slotCount: Int
    let columnWidth: CGFloat
    let onEvent: (BoardEvent) -> Void

    var body: some View {
        let board = BoardModel(assignments: store.assignments, projectOrder: store.recentProjectOrder, slotCount: slotCount)
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeaderView(store: store, hint: hint(for: board), onStop: { onEvent(.stopShortcut) })
                if let errorMessage = state.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            HStack(alignment: .top, spacing: Self.columnGap) {
                ForEach(Array(board.columns.enumerated()), id: \.element.id) { index, column in
                    ProjectColumnView(
                        store: store,
                        number: index + 1,
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
        .padding(Self.padding)
        .frame(width: width(columnCount: board.columns.count))
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
        return max(columnsWidth, 3 * columnWidth + 2 * Self.columnGap) + Self.padding * 2
    }

    private func hint(for board: BoardModel) -> String {
        switch state.boardState {
        case .idle:
            "\(Self.range(board.columns.count)) project, then \(Self.range(board.maxTaskKeyCount)) task · or click any tile · Esc close"
        case .projectSelected(let column) where board.columns.indices.contains(column):
            "\(board.columns[column].project.name): press \(Self.range(min(9, board.columns[column].tasks.count))) for a task · Esc back"
        case .projectSelected:
            "Esc back"
        case .starting:
            "Starting timer…"
        }
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
