import SwiftUI

struct AccountTab: View {
    let store: AppStore

    var body: some View {
        Form {
            Section("Harvest") {
                if let session = store.auth.session {
                    LabeledContent("Connected as", value: connectionText)
                    LabeledContent("Connection expires") {
                        Text(session.expiresAt, format: .relative(presentation: .named))
                    }
                    if session.expiresSoon(at: .now) {
                        Text("Harvest connection expires soon. Reconnect to keep timers working.")
                            .foregroundStyle(.orange)
                    }
                } else {
                    LabeledContent("Status", value: "Not connected")
                }
                if store.auth.isConnecting {
                    Text("Waiting for Harvest in your browser…")
                        .foregroundStyle(.secondary)
                }
                if let errorMessage = store.auth.errorMessage ?? store.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    if store.auth.session != nil {
                        Button("Disconnect") { store.auth.disconnect() }
                        Button("Reconnect") { store.auth.connect() }
                    } else {
                        Button("Connect") { store.auth.connect() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var connectionText: String {
        guard let user = store.user, let company = store.company else { return "Unknown user" }
        return "\(user.firstName) \(user.lastName) · \(company.name)"
    }
}
