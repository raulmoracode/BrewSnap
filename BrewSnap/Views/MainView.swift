import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .export

    enum Tab: String, CaseIterable {
        case export = "Export"
        case packages = "Packages"
        case sync = "Sync"
        case profiles = "Profiles"
        var icon: String {
            switch self {
            case .export: return "square.and.arrow.up"
            case .packages: return "shippingbox.fill"
            case .sync: return "arrow.triangle.2.circlepath"
            case .profiles: return "person.2"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: { Label("Settings", systemImage: "gearshape") }
                }
            }
        } detail: {
            Group {
                switch selectedTab {
                case .export: ExportView()
                case .packages: PackagesView()
                case .sync: SyncView()
                case .profiles: ProfilesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("BrewSnap")
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    }
}
