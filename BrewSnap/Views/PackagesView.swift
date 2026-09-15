import SwiftUI

struct PackagesView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedFilter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "All"
        case formulae = "Formulae"
        case casks = "Casks"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let snap = appState.snapshot {
                if snap.formulae.isEmpty && snap.casks.isEmpty {
                    emptyState
                } else {
                    columns(snap: snap)
                }
            } else {
                ContentUnavailableView(
                    "Sin snapshot",
                    systemImage: "shippingbox",
                    description: Text("Crea un snapshot en Export para ver tus paquetes")
                )
            }
        }
        .padding(16)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.scan() }
                } label: {
                    Label(appState.isScanning ? "Escaneando…" : "Rescan", systemImage: "arrow.triangle.2.circlepath")
                }.disabled(appState.isScanning)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Packages").font(.title2.bold())
                if let snap = appState.snapshot {
                    Text("\(snap.formulaeCount + snap.casksCount) paquetes · \(snap.formulaeCount) formulae · \(snap.casksCount) casks")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Todos tus paquetes Homebrew").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar paquete…", text: $searchText)
                    .textFieldStyle(.plain).frame(width: 200)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
            Text("No se encontraron paquetes").font(.headline)
            Text("brew: \(ShellExecutor.brewExecutable())").font(.caption.monospaced()).foregroundStyle(.secondary)
            if let err = appState.lastError {
                Text(err).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func columns(snap: BrewSnapshot) -> some View {
        // Filtra por búsqueda
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        func matches(_ name: String) -> Bool { q.isEmpty || name.lowercased().contains(q) }

        let filteredFormulae = snap.formulae.filter { matches($0.name) }.sorted { $0.name < $1.name }
        let filteredCasks = snap.casks.filter { matches($0.name) }.sorted { $0.name < $1.name }

        // All = mezcla formulae + casks, orden alfabético, con tag de tipo
        struct AllItem: Identifiable {
            let id: String
            let name: String
            let version: String
            let kind: String // "F" o "C"
            let isPinned: Bool
        }
        let allItems: [AllItem] = (filteredFormulae.map { AllItem(id: "f-\($0.name)", name: $0.name, version: $0.version, kind: "F", isPinned: $0.pinned) }
            + filteredCasks.map { AllItem(id: "c-\($0.name)", name: $0.name, version: $0.version, kind: "C", isPinned: false) })
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        return HStack(spacing: 12) {
            // COL 1: All
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "All", count: allItems.count, icon: "shippingbox.fill", color: Color(hex: "#1D3557"))
                if allItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(allItems) { item in
                        HStack(spacing: 8) {
                            Text(item.kind)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(item.kind == "F" ? Color.orange : Color.purple, in: RoundedRectangle(cornerRadius: 4))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(item.name).font(.system(.callout, design: .monospaced)).lineLimit(1)
                                    if item.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange) }
                                }
                                Text(item.kind == "F" ? "formula" : "cask").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.version).font(.caption.monospaced()).foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))

            // COL 2: Formulae
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "Formulae", count: filteredFormulae.count, icon: "cube.fill", color: .orange)
                if filteredFormulae.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredFormulae, id: \.name) { f in
                        PackageRow(name: f.name, version: f.version, tap: f.tap, isPinned: f.pinned)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))

            // COL 3: Casks
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "Casks", count: filteredCasks.count, icon: "app.badge.fill", color: .purple)
                if filteredCasks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredCasks, id: \.name) { c in
                        PackageRow(name: c.name, version: c.version, tap: c.tap)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
        }
    }
}

private struct ColumnHeader: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.headline)
            Text("\(count)").font(.caption.weight(.semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.quaternary.opacity(0.5))
    }
}

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0; Scanner(string: h).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF)/255, green: Double((rgb >> 8) & 0xFF)/255, blue: Double(rgb & 0xFF)/255, opacity: 1)
    }
}
