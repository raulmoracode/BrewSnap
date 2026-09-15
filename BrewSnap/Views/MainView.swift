// MainView.swift
// BrewSnap — Main navigation (7 tabs).

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .importTab

    enum Tab: String, CaseIterable {
        case importTab = "Import"
        case export = "Export"
        case packages = "Packages"
        case sync = "Sync"
        case repository = "Repository"
        case settings = "Settings"
        var icon: String {
            switch self {
            case .importTab: return "square.and.arrow.down"
            case .export: return "square.and.arrow.up"
            case .packages: return "shippingbox.fill"
            case .sync: return "arrow.triangle.2.circlepath"
            case .repository: return "link"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 0) {
                List(selection: $selectedTab) {
                    Section("Main") {
                        Label(Tab.importTab.rawValue, systemImage: Tab.importTab.icon).tag(Tab.importTab)
                        Label(Tab.export.rawValue, systemImage: Tab.export.icon).tag(Tab.export)
                        Label(Tab.packages.rawValue, systemImage: Tab.packages.icon).tag(Tab.packages)
                        Label(Tab.sync.rawValue, systemImage: Tab.sync.icon).tag(Tab.sync)
                    }
                    Section("Project") {
                        Label(Tab.repository.rawValue, systemImage: Tab.repository.icon).tag(Tab.repository)
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon).tag(Tab.settings)
                    }
                }
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(Color(hex: "#FBB040"))
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Homebrew")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(appState.snapshot?.homebrew ?? "—")
                            .font(.caption.monospaced()).lineLimit(1)
                    }
                    Spacer()
                    if appState.isScanning {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else if let snap = appState.snapshot {
                        Text("\(snap.formulaeCount + snap.casksCount)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(.quaternary.opacity(0.35))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .importTab: ImportView()
                case .export: ExportView()
                case .packages: PackagesView()
                case .sync: SyncView()
                case .repository: RepositoryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("BrewSnap")
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .task {
            if appState.snapshot == nil {
                await appState.scan()
            }
        }
    }
}
