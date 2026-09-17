// MainView.swift
// BrewSnap — Main navigation (7 tabs).

import SwiftUI
import AppKit

struct MainView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .packages

    enum Tab: String, CaseIterable {
        case importTab = "Import"
        case export = "Export"
        case packages = "Packages"
        case repository = "Repository"
        case settings = "Settings"
        case general = "General"
        var icon: String {
            switch self {
            case .importTab: return "square.and.arrow.down"
            case .export: return "square.and.arrow.up"
            case .packages: return "shippingbox.fill"
            case .repository: return "link"
            case .settings: return "gearshape.fill"
            case .general: return "info.circle.fill"
            }
        }
    }

    // MARK: - Body

    private var mainItems: [HookSidebarItem] {
        [.plain("Import", icon: "square.and.arrow.down"),
         .plain("Export", icon: "square.and.arrow.up"),
         .plain("Packages", icon: "shippingbox.fill"),
         .plain("Settings", icon: "gearshape.fill"),
         .plain("General", icon: "info.circle.fill")]
    }
    private var mainSelectedIndex: Binding<Int> {
        Binding(
            get: {
                switch selectedTab {
                case .importTab: return 0
                case .export: return 1
                case .packages: return 2
                case .settings: return 3
                case .general: return 4
                default: return 0
                }
            },
            set: { idx in
                guard idx >= 0 && idx < 5 else { return }
                selectedTab = [.importTab, .export, .packages, .settings, .general][idx]
            }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HookSidebar(items: mainItems, selectedIndex: mainSelectedIndex, showsRail: false)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
                .background(.thickMaterial)
                HStack(spacing: 2) {
                    Text("by").font(.caption2).foregroundStyle(.secondary)
                    if let url = URL(string: "https://raulmoracode.com/links") {
                        Link("raulmoracode", destination: url)
                            .font(.caption2.weight(.semibold))
                            .handCursor()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.thickMaterial)
                Divider()
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Homebrew")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(appState.snapshot?.homebrew ?? "-")
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
                .background(.thickMaterial)
            }
            .background(.thickMaterial)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .importTab: ImportView()
                case .export: ExportView()
                case .packages: PackagesView()
                case .repository: RepositoryView()
                case .settings: SettingsView()
                case .general: GeneralView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(selectedTab.rawValue)
        .toolbarBackground(.thinMaterial, for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .onChange(of: appState.requestedTab) { _, rawValue in
            guard let raw = rawValue, let tab = Tab(rawValue: raw) else { return }
            selectedTab = tab
            appState.requestedTab = nil
        }
        .background { WindowAccessor { appState.mainWindow = $0 } }
        .task {
            if appState.snapshot == nil {
                await appState.scan()
            }
        }
    }
}

// MARK: - Window Accessor

/// Tags the main window with a stable identifier and exposes it to AppState,
/// so the menu bar can reuse the existing window instead of opening new ones.
private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowObservingView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowObservingView)?.onResolve = onResolve
        (nsView as? WindowObservingView)?.attach()
    }
}

private final class WindowObservingView: NSView {
    var onResolve: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    func attach() {
        guard let window else { return }
        window.identifier = NSUserInterfaceItemIdentifier("BrewSnapMain")
        onResolve?(window)
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
