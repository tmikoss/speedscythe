import SwiftUI

struct SettingsView: View {
    let store: AppStore

    var body: some View {
        TabView {
            AccountTab(store: store)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .frame(width: 460)
        .padding()
    }
}
