import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    @Bindable var preferences: Preferences

    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Open picker", name: .openPicker)
                KeyboardShortcuts.Recorder("Stop timer in the panel", name: .stopTimer)
                KeyboardShortcuts.Recorder("Edit notes in the panel", name: .editNotes)
                HStack {
                    Spacer()
                    Button("Reset shortcuts") { KeyboardShortcuts.reset(.openPicker, .stopTimer, .editNotes) }
                }
            }
            Section("Timers") {
                Toggle(isOn: $preferences.continueToday) {
                    Text("Continue the matching entry from today")
                    Text("Off: every start creates a new entry.")
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(get: { loginItemStatus == .enabled }, set: setLaunchAtLogin))
                if loginItemStatus == .requiresApproval {
                    Text("Allow Speedscythe in System Settings → General → Login Items.")
                        .foregroundStyle(.secondary)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItemStatus = SMAppService.mainApp.status }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        loginItemStatus = SMAppService.mainApp.status
    }
}
