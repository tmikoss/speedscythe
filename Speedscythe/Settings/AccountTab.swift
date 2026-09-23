import SwiftUI

struct AccountTab: View {
    let store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = store.auth.session {
                Text(connectionText)
                Text("Expires \(session.expiresAt, format: .relative(presentation: .named))")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Reconnect") { store.auth.connect() }
                    Button("Disconnect") { store.auth.disconnect() }
                }
            } else {
                Text("Not connected to Harvest")
                Button("Connect") { store.auth.connect() }
            }
            if store.auth.isConnecting {
                Text("Waiting for Harvest in your browser…")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage = store.auth.errorMessage ?? store.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var connectionText: String {
        guard let user = store.user, let company = store.company else { return "Connected" }
        return "Connected as \(user.firstName) \(user.lastName) · \(company.name)"
    }
}
