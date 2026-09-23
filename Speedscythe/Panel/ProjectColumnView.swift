import SwiftUI

struct ProjectColumnView: View {
    enum Emphasis {
        case normal
        case selected
        case dimmed
    }

    let store: AppStore
    let number: Int
    let column: BoardModel.Column
    let rowCount: Int
    let emphasis: Emphasis
    let startingTask: Int?
    let onHeaderClick: () -> Void
    let onTileClick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                KeyCapView(label: "\(number)", style: emphasis == .selected ? .inverted : .column)
                Text(column.project.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                if column.showsClientName {
                    Text(column.client.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onHeaderClick)

            ForEach(0..<rowCount, id: \.self) { row in
                if row < column.tasks.count {
                    TaskTileView(
                        number: row < 9 ? row + 1 : nil,
                        task: column.tasks[row],
                        status: status(forRow: row),
                        invertsKeyCap: emphasis == .selected,
                        onClick: { onTileClick(row) }
                    )
                } else {
                    RoundedRectangle(cornerRadius: TaskTileView.cornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(height: TaskTileView.height)
                }
            }
        }
        .padding(8)
        .background {
            if emphasis == .selected {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .quinarySystemFill))
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .opacity(emphasis == .dimmed ? 0.38 : 1)
    }

    private func status(forRow row: Int) -> TaskTileView.Status {
        let task = column.tasks[row]
        if startingTask == row {
            return .starting
        }
        if let runningEntry = store.runningEntry, runningEntry.project.id == column.project.id, runningEntry.task.id == task.id {
            let now = Date.now
            return .running(since: now - (store.runningElapsed(at: now) ?? 0))
        }
        let today = store.todayDuration(projectID: column.project.id, taskID: task.id)
        return today > 0 ? .today(today) : .idle
    }
}
