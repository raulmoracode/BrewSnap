// ImportView.swift
// BrewSnap — Zona para importar JSON (drag & drop).

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppState.self) private var appState
    @State private var importedSnapshot: BrewSnapshot?
    @State private var fileName: String?
    @State private var errorMessage: String?
    @State private var isTargeted = false
    @State private var jsonText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import").font(.title2.bold())
                Text("Añade un JSON de BrewSnap para previsualizarlo o restaurarlo")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // Zona drop
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.quaternaryLabelColor).opacity(0.15))
                    )

                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    Text("Arrastra tu JSON aquí")
                        .font(.headline)
                    Text("o haz clic para seleccionar")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button {
                        selectFile()
                    } label: {
                        Label("Seleccionar archivo", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#FBB040"))

                    if let name = fileName {
                        Label(name, systemImage: "doc.fill")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(32)
            }
            .frame(height: 200)
            .contentShape(Rectangle())
            .onTapGesture { selectFile() }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                handleURL(url)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }

            if let err = errorMessage {
                Label(err, systemImage: "xmark.circle.fill")
                    .font(.callout).foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if let snap = importedSnapshot {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        StatCard(title: "Host", value: snap.hostname, icon: "laptopcomputer")
                        StatCard(title: "macOS", value: snap.macOS, icon: "apple.logo")
                        StatCard(title: "Arch", value: snap.arch, icon: "cpu")
                        StatCard(title: "Homebrew", value: snap.homebrew, icon: "shippingbox")
                    }
                    Text("\(snap.formulaeCount) formulae · \(snap.casksCount) casks · \(snap.taps.count) taps · \(snap.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)

                    TabView {
                        List(snap.formulae, id: \.name) { f in
                            PackageRow(name: f.name, version: f.version, tap: f.tap, isPinned: f.pinned)
                        }.tabItem { Label("Formulae (\(snap.formulae.count))", systemImage: "cube") }

                        List(snap.casks, id: \.name) { c in
                            PackageRow(name: c.name, version: c.version, tap: c.tap)
                        }.tabItem { Label("Casks (\(snap.casks.count))", systemImage: "app.badge") }

                        List(snap.taps, id: \.name) { t in
                            HStack {
                                Text(t.name).font(.system(.body, design: .monospaced))
                                Spacer()
                                if let r = t.remote { Text(r).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                            }
                        }.tabItem { Label("Taps (\(snap.taps.count))", systemImage: "arrow.triangle.branch") }
                    }
                    .frame(height: 260)

                    HStack(spacing: 12) {
                        Button {
                            appState.snapshot = snap
                            appState.lastError = nil
                        } label: { Label("Usar como snapshot actual", systemImage: "checkmark.circle.fill") }
                        .buttonStyle(.borderedProminent).tint(.green)
                        Button("Copiar JSON") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(jsonText, forType: .string)
                        }.buttonStyle(.bordered)
                        Button("Limpiar", role: .destructive) { clear() }
                            .buttonStyle(.bordered)
                        Spacer()
                    }

                    DisclosureGroup("Ver JSON") {
                        ScrollView {
                            Text(jsonText).font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        // Necesita acceso security-scoped si viene de drop
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        fileName = url.lastPathComponent
        errorMessage = nil
        do {
            let data = try Data(contentsOf: url)
            jsonText = String(data: data, encoding: .utf8) ?? ""
            let snap = try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
            importedSnapshot = snap
        } catch {
            importedSnapshot = nil
            jsonText = ""
            errorMessage = "JSON inválido: \(error.localizedDescription)"
        }
    }

    private func clear() {
        importedSnapshot = nil
        fileName = nil
        errorMessage = nil
        jsonText = ""
    }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).lineLimit(1)
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ImportView().environment(AppState()).frame(width: 800, height: 600)
}
