import SwiftUI

struct EditSlotView: View {
    let number: Int
    let column: BoardModel.Column?
    let isPinned: Bool
    let rowCount: Int
    let onPick: () -> Void
    let onClear: () -> Void
    let onMoveTask: (Int, Int) -> Void

    @State private var drag: TileDrag?

    private struct TileDrag: Equatable {
        let row: Int
        var offset: CGFloat
    }

    private static let rowPitch = TaskTileView.height + 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                KeyCapView(label: "\(number)", style: .column)
                if isPinned, let column {
                    Text(column.project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear this slot")
                    .focusable(false)
                } else {
                    Text(column?.project.name ?? "Recent")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)

            Group {
                if let column, column.tasks.count > rowCount {
                    ScrollView(.vertical) {
                        VStack(spacing: 10) {
                            ForEach(column.tasks.indices, id: \.self) { row in
                                tile(column.tasks[row], row: row)
                            }
                        }
                    }
                    .frame(height: CGFloat(rowCount) * TaskTileView.height + CGFloat(rowCount - 1) * 10)
                } else {
                    VStack(spacing: 10) {
                        ForEach(0..<rowCount, id: \.self) { row in
                            if let column, row < column.tasks.count {
                                tile(column.tasks[row], row: row)
                            } else {
                                RoundedRectangle(cornerRadius: TaskTileView.cornerRadius)
                                    .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .frame(height: TaskTileView.height)
                            }
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.15), value: drag.map { targetRow(for: $0) })
            .allowsHitTesting(isPinned)
            .opacity(isPinned ? 1 : 0.38)
        }
        .padding(8)
        .background {
            if isPinned {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .quinarySystemFill))
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(nsColor: .tertiaryLabelColor))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(nsColor: .tertiaryLabelColor), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPick)
    }

    private var movableRowCount: Int {
        column?.tasks.count ?? 0
    }

    private func tile(_ task: HarvestTask, row: Int) -> some View {
        TaskTileView(number: nil, task: task, status: .idle, invertsKeyCap: false, showsDragHandle: isPinned, onClick: onPick)
            .offset(y: offset(forRow: row))
            .zIndex(drag?.row == row ? 1 : 0)
            .shadow(color: .black.opacity(drag?.row == row ? 0.2 : 0), radius: 8, y: 2)
            .highPriorityGesture(dragGesture(forRow: row))
    }

    private func targetRow(for drag: TileDrag) -> Int {
        let target = drag.row + Int((drag.offset / Self.rowPitch).rounded())
        return min(max(target, 0), movableRowCount - 1)
    }

    private func offset(forRow row: Int) -> CGFloat {
        guard let drag else { return 0 }
        if row == drag.row {
            return drag.offset
        }
        let target = targetRow(for: drag)
        if drag.row < row, row <= target {
            return -Self.rowPitch
        }
        if target <= row, row < drag.row {
            return Self.rowPitch
        }
        return 0
    }

    private func dragGesture(forRow row: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                drag = TileDrag(row: row, offset: value.translation.height)
            }
            .onEnded { value in
                let target = targetRow(for: TileDrag(row: row, offset: value.translation.height))
                drag = nil
                if target != row {
                    onMoveTask(row, target)
                }
            }
    }
}
