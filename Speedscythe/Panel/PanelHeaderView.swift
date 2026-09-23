import KeyboardShortcuts
import SwiftUI

struct PanelHeaderView: View {
    let store: AppStore
    let isEditing: Bool
    let canEdit: Bool
    let slotCount: Int
    let onStop: () -> Void
    let onEditToggle: () -> Void
    let onEdit: (BoardEdit) -> Void

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
            if canEdit && isEditing {
                HStack(spacing: 4) {
                    Button { onEdit(.removeSlot) } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(slotCount <= Preferences.slotRange.lowerBound)
                    .help("Remove the last column")
                    .focusable(false)
                    Button { onEdit(.addSlot) } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(slotCount >= Preferences.slotRange.upperBound)
                    .help("Add a column")
                    .focusable(false)
                }
                .buttonStyle(HeaderButtonStyle())
            }
            if canEdit {
                Button(action: onEditToggle) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(HeaderButtonStyle(isActive: isEditing))
                .help(isEditing ? "Finish editing the board" : "Edit the board")
                .focusable(false)
            }
            Button(action: onStop) {
                HStack(spacing: 10) {
                    Text("Stop timer")
                    if let shortcut = KeyboardShortcuts.getShortcut(for: .stopTimer) {
                        KeyCapView(label: shortcut.description, style: .shortcut)
                    }
                }
            }
            .buttonStyle(StopButtonStyle())
            .disabled(store.runningEntry == nil)
            .focusable(false)
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

private struct HeaderButtonStyle: ButtonStyle {
    var isActive = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundStyle(isActive ? Color(nsColor: .windowBackgroundColor) : .primary)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 10).fill(isActive ? Color.primary : Color(nsColor: .quinarySystemFill)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isActive ? Color.primary : Color(nsColor: .separatorColor)))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? 1 : 0.5)
    }
}
