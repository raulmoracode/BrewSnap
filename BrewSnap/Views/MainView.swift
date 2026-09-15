// MainView.swift
// BrewSnap — Main navigation (7 tabs).

import SwiftUI
import AppKit

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
                            .contentShape(Rectangle()).handCursor()
                        Label(Tab.export.rawValue, systemImage: Tab.export.icon).tag(Tab.export)
                            .contentShape(Rectangle()).handCursor()
                        Label(Tab.packages.rawValue, systemImage: Tab.packages.icon).tag(Tab.packages)
                            .contentShape(Rectangle()).handCursor()
                        Label(Tab.sync.rawValue, systemImage: Tab.sync.icon).tag(Tab.sync)
                            .contentShape(Rectangle()).handCursor()
                    }
                    Section("Project") {
                        Button {
                            if let url = URL(string: "https://github.com/raulmoracode/brewsnap") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label(Tab.repository.rawValue, systemImage: Tab.repository.icon)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).handCursor()
                        Label(Tab.settings.rawValue, systemImage: Tab.settings.icon).tag(Tab.settings)
                            .contentShape(Rectangle()).handCursor()
                    }
                }
                HStack(spacing: 2) {
                    Text("by").font(.caption2).foregroundStyle(.secondary)
                    if let url = URL(string: "https://raulmoracode.com") {
                        Link("raulmoracode", destination: url)
                            .font(.caption2.weight(.semibold))
                            .handCursor()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .contentShape(Rectangle()).handCursor()
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

// MARK: - Hand Cursor

private struct HandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func handCursor() -> some View {
        modifier(HandCursorModifier())
    }
}
