import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .importTab

    enum Tab: String, CaseIterable {
        case importTab = "Import"
        case export = "Export"
        case packages = "Packages"
        case sync = "Sync"
        case profiles = "Profiles"
        case repository = "Repository"
        case settings = "Settings"
        var icon: String {
            switch self {
            case .importTab: return "square.and.arrow.down"
            case .export: return "square.and.arrow.up"
            case .packages: return "shippingbox.fill"
            case .sync: return "arrow.triangle.2.circlepath"
            case .profiles: return "person.2"
            case .repository: return "link"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Principal") {
                    Label(Tab.importTab.rawValue, systemImage: Tab.importTab.icon).tag(Tab.importTab)
                    Label(Tab.export.rawValue, systemImage: Tab.export.icon).tag(Tab.export)
                    Label(Tab.packages.rawValue, systemImage: Tab.packages.icon).tag(Tab.packages)
                    Label(Tab.sync.rawValue, systemImage: Tab.sync.icon).tag(Tab.sync)
                    Label(Tab.profiles.rawValue, systemImage: Tab.profiles.icon).tag(Tab.profiles)
                }
                Section("Proyecto") {
                    Label(Tab.repository.rawValue, systemImage: Tab.repository.icon).tag(Tab.repository)
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon).tag(Tab.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .importTab: ImportView()
                case .export: ExportView()
                case .packages: PackagesView()
                case .sync: SyncView()
                case .profiles: ProfilesView()
                case .repository: RepositoryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("BrewSnap")
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
    }
}
