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
    let task: HarvestTask
    let status: Status
    let invertsKeyCap: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    if let number {
                        KeyCapView(label: "\(number)", style: invertsKeyCap ? .inverted : .tile)
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
            .background(RoundedRectangle(cornerRadius: Self.cornerRadius).fill(status.isRunning ? Color("RunningFill") : Color(nsColor: .quinarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(status.isRunning ? Color("RunningAccent") : Color(nsColor: .separatorColor)))
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .idle:
            EmptyView()
        case .today(let duration):
            Text("Today \(ElapsedFormat.hoursMinutes(duration))")
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
