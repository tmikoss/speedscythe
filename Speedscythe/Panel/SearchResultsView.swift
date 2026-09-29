import SwiftUI

struct SearchResultsView: View {
    static let rowHeight: CGFloat = 40
    static let rowGap: CGFloat = 4

    let store: AppStore
    let matches: [TaskMatch]
    let selection: Int
    let onChoose: (TaskMatch) -> Void

    var body: some View {
        VStack(spacing: Self.rowGap) {
            if matches.isEmpty {
                Text("No matching tasks")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    Row(
                        match: match,
                        isSelected: index == selection,
                        isRunning: isRunning(match),
                        today: store.todayDuration(projectID: match.project.id, taskID: match.task.id),
                        onClick: { onChoose(match) }
                    )
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: CGFloat(TaskMatcher.maxResults) * Self.rowHeight + CGFloat(TaskMatcher.maxResults - 1) * Self.rowGap)
    }

    private func isRunning(_ match: TaskMatch) -> Bool {
        guard let runningEntry = store.runningEntry else { return false }
        return runningEntry.project.id == match.project.id && runningEntry.task.id == match.task.id
    }

    private struct Row: View {
        let match: TaskMatch
        let isSelected: Bool
        let isRunning: Bool
        let today: TimeInterval
        let onClick: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: onClick) {
                HStack(spacing: 12) {
                    if isRunning {
                        Circle()
                            .fill(Color("RunningAccent"))
                            .frame(width: 10, height: 10)
                    }
                    Text("\(match.project.name) · \(match.task.name)")
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 16)
                    if today > 0 {
                        Text(ElapsedFormat.hoursMinutes(today))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color("TodayText"))
                    }
                    Text(match.client.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: SearchResultsView.rowHeight, maxHeight: SearchResultsView.rowHeight)
                .background {
                    if isSelected || isHovered {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: isHovered ? .quaternarySystemFill : .quinarySystemFill))
                    }
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(nsColor: .tertiaryLabelColor))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isHovered = $0 }
        }
    }
}
