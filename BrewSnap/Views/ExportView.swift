import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(AppState.self) private var appState
    @State private var jsonPreview: String = ""
    @State private var isExporting = false

    var body: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snapshot").font(.title2.bold())
                    if let snap = appState.snapshot {
                        Text("\(snap.formulaeCount) formulae · \(snap.casksCount) casks · \(snap.taps.count) taps")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text("Aún no has creado ningún snapshot").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task { await createSnapshot() }
                } label: {
                    Label(appState.isScanning ? "Escaneando…" : "Create Snapshot", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#FBB040"))
                .disabled(appState.isScanning)
            }

            if let err = appState.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .padding(8).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if let snap = appState.snapshot {
                HStack(spacing: 12) {
                    StatCard(title: "Host", value: snap.hostname, icon: "laptopcomputer")
                    StatCard(title: "macOS", value: snap.macOS, icon: "apple.logo")
                    StatCard(title: "Arch", value: snap.arch, icon: "cpu")
                    StatCard(title: "Homebrew", value: snap.homebrew, icon: "shippingbox")
                }

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
                            if let remote = t.remote { Text(remote).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                        }
                    }.tabItem { Label("Taps (\(snap.taps.count))", systemImage: "arrow.triangle.branch") }
                }
            }

            if !jsonPreview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JSON Preview").font(.headline)
                        Spacer()
                        Button("Copiar") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(jsonPreview, forType: .string) }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Guardar…") { saveJSON() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    ScrollView { Text(jsonPreview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(height: 220).padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()
        }
        .padding(20)
        .task { if appState.snapshot == nil { await createSnapshot() } }
    }

    private func createSnapshot() async {
        await appState.scan()
        if let snap = appState.snapshot {
            jsonPreview = (try? snap.toPrettyJSON()) ?? ""
        }
    }

    private func saveJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(appState.selectedProfile.fileName)"
        if panel.runModal() == .OK, let url = panel.url, let snap = appState.snapshot {
            try? SnapshotService.save(snap, to: url)
        }
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

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0; Scanner(string: h).scanHexInt64(&rgb)
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF)/255, green: Double((rgb >> 8) & 0xFF)/255, blue: Double(rgb & 0xFF)/255, opacity: 1)
    }
}
