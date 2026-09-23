import SwiftUI

struct PanelHeaderView: View {
    let store: AppStore
    let hint: String
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if let runningEntry = store.runningEntry {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color("RunningAccent"))
                        .frame(width: 10, height: 10)
                    Text("Running")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("\(runningEntry.project.name) · \(runningEntry.task.name)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(ElapsedFormat.hoursMinutesSeconds(store.runningElapsed(at: context.date) ?? 0))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color("RunningText"))
                    }
                }
            } else {
                Text("No timer running")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Button(action: onStop) {
                HStack(spacing: 10) {
                    Text("Stop timer")
                    KeyCapView(label: "⌘⌫", style: .shortcut)
                }
            }
            .buttonStyle(StopButtonStyle())
            .disabled(store.runningEntry == nil)
        }
        .frame(height: 40)
    }
}

private struct StopButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .quinarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(nsColor: .separatorColor)))
            .opacity(isEnabled ? 1 : 0.5)
    }
}
