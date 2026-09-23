import SwiftUI

struct TaskTileView: View {
    enum Status: Equatable {
        case idle
        case today(TimeInterval)
        case running(since: Date)
        case starting

        var isRunning: Bool {
            if case .running = self { true } else { false }
        }
    }

    static let height: CGFloat = 88
    static let cornerRadius: CGFloat = 12

    let number: Int?
    let shortcut: String?
    let task: HarvestTask
    let status: Status
    let invertsKeyCap: Bool
    let showsDragHandle: Bool
    let onClick: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if let number {
                        KeyCapView(label: "\(number)", style: invertsKeyCap ? .inverted : .tile)
                    }
                    if let shortcut {
                        KeyCapView(label: shortcut, style: .tile)
                    }
                    if showsDragHandle {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    statusView
                }
                .frame(height: 24)
                Spacer(minLength: 0)
                Text(task.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Self.cornerRadius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(status.isRunning ? Color("RunningAccent") : Color(nsColor: .separatorColor)))
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }

    private var fill: Color {
        if status.isRunning {
            return Color("RunningFill")
        }
        return Color(nsColor: isHovered ? .quaternarySystemFill : .quinarySystemFill)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .today(let duration):
            Text(ElapsedFormat.hoursMinutes(duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color("TodayText"))
        case .running(let since):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(ElapsedFormat.hoursMinutesSeconds(context.date.timeIntervalSince(since)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color("RunningText"))
            }
        case .starting:
            ProgressView()
                .controlSize(.small)
        }
    }
}
