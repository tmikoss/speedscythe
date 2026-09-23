import SwiftUI

struct SettingsView: View {
    enum Pane: CaseIterable, Identifiable {
        case account
        case general

        var id: Self { self }

        var title: String {
            switch self {
            case .account: "Account"
            case .general: "General"
            }
        }

        var systemImage: String {
            switch self {
            case .account: "person.crop.circle"
            case .general: "gearshape"
            }
        }
    }

    let store: AppStore
    let preferences: Preferences

    @State private var selection: Pane? = .account

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            let pane = selection ?? .account
            Group {
                switch pane {
                case .account:
                    AccountTab(store: store)
                case .general:
                    GeneralTab(preferences: preferences)
                }
            }
            .navigationTitle(pane.title)
        }
        .frame(width: 640, height: 420)
    }
}
