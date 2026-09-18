// PackagesView.swift
// BrewSnap — 3 columns All / Formulae / Casks.

import SwiftUI

struct PackagesView: View {
    // MARK: - Properties

    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let snap = appState.snapshot {
                if snap.formulae.isEmpty && snap.casks.isEmpty {
                    emptyState
                } else {
                    columns(snap: snap)
                }
            } else if appState.isScanning {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large)
                    Text("Reading Homebrew…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 420)
            } else {
                ContentUnavailableView(
                    "No snapshot",
                    systemImage: "shippingbox",
                    description: Text("Create a snapshot in Export to see your packages")
                )
            }
        }
        .padding(20)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await appState.scan() }
                } label: {
                    Label(appState.isScanning ? "Scanning…" : "Rescan", systemImage: "arrow.triangle.2.circlepath")
                }.disabled(appState.isScanning)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Packages").font(.title2.bold()).tracking(-0.4)
                Text("Browse and search your installed formulae and casks.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search packages…", text: $searchText)
                    .textFieldStyle(.plain).frame(width: 200)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
            Text("No packages found").font(.headline)
            Text("brew: \(ShellExecutor.brewExecutable())").font(.caption.monospaced()).foregroundStyle(.secondary)
            if let err = appState.lastError {
                Text(err).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func columns(snap: BrewSnapshot) -> some View {
        // Filter by search
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        func matches(_ name: String) -> Bool { q.isEmpty || name.lowercased().contains(q) }

        let filteredFormulae = snap.formulae.filter { matches($0.name) }.sorted { $0.name < $1.name }
        let filteredCasks = snap.casks.filter { matches($0.name) }.sorted { $0.name < $1.name }

        // All = mix of formulae + casks, alphabetically sorted, with type tag
        struct AllItem: Identifiable {
            let id: String
            let name: String
            let version: String
            let kind: String // "F" o "C"
            let isPinned: Bool
            let homepage: String?
        }
        let allItems: [AllItem] = (filteredFormulae.map { AllItem(id: "f-\($0.name)", name: $0.name, version: $0.version, kind: "F", isPinned: $0.pinned, homepage: $0.homepage) }
            + filteredCasks.map { AllItem(id: "c-\($0.name)", name: $0.name, version: $0.version, kind: "C", isPinned: false, homepage: $0.homepage) })
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        return HStack(spacing: 12) {
            // COL 1: All
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "All", count: allItems.count)
                Group {
                    if allItems.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(allItems) { item in
                            PackageRow(name: item.name, version: item.version, isPinned: item.isPinned, homepage: item.homepage)
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .scrollIndicators(.hidden)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))

            // COL 2: Formulae
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "Formulae", count: filteredFormulae.count)
                Group {
                    if filteredFormulae.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredFormulae, id: \.name) { f in
                            PackageRow(name: f.name, version: f.version, tap: f.tap, isPinned: f.pinned, homepage: f.homepage)
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .scrollIndicators(.hidden)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))

            // COL 3: Casks
            VStack(alignment: .leading, spacing: 0) {
                ColumnHeader(title: "Casks", count: filteredCasks.count)
                Group {
                    if filteredCasks.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredCasks, id: \.name) { c in
                            PackageRow(name: c.name, version: c.version, tap: c.tap, homepage: c.homepage)
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .scrollIndicators(.hidden)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ColumnHeader: View {
    let title: String
    let count: Int
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text("\(count)").font(.caption.weight(.semibold))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.thickMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
    }
}