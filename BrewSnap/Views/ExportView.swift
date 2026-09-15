import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(AppState.self) private var appState
    @State private var jsonPreview: String = ""
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var uploadIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export").font(.title2.bold())
                    if let snap = appState.snapshot {
                        Text("\(snap.formulaeCount) formulae · \(snap.casksCount) casks · \(snap.taps.count) taps")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text("Crea tu snapshot y elige cómo exportarlo")
                            .font(.subheadline).foregroundStyle(.secondary)
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

                if snap.formulae.isEmpty && snap.casks.isEmpty && snap.taps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No se detectaron paquetes — verifica brew", systemImage: "exclamationmark.octagon.fill")
                            .foregroundStyle(.orange).font(.callout.weight(.semibold))
                        Text("brew: \(ShellExecutor.brewExecutable()) · existe: \(FileManager.default.isExecutableFile(atPath: ShellExecutor.brewExecutable()) ? "sí" : "no")")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text("Ejecuta en Terminal: brew list --formula --versions | wc -l  (debería dar 60 en tu máquina)")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Reintentar") { Task { await createSnapshot() } }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }

                // Zona 2 opciones — parecida a Import
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(NSColor.quaternaryLabelColor).opacity(0.08))
                        )
                    HStack(spacing: 16) {
                        // Opción 1: Subir al repo
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: "#1D3557"))
                            Text("Subir al repo")
                                .font(.headline)
                            Text("Sincroniza el JSON a tu repo privado en GitHub")
                                .font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(height: 32)
                            Button {
                                Task { await uploadToRepo() }
                            } label: {
                                Label(isUploading ? "Subiendo…" : "Subir al repo", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "#1D3557"))
                            .disabled(snap.formulae.isEmpty && snap.casks.isEmpty || isUploading || appState.githubToken.isEmpty)
                            if appState.githubToken.isEmpty {
                                Text("Configura tu token en Settings")
                                    .font(.caption2).foregroundStyle(.orange)
                            } else if !appState.repoOwner.isEmpty {
                                Text("\(appState.repoOwner)/\(appState.repoName)")
                                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))

                        // Separador
                        Rectangle().fill(Color.secondary.opacity(0.15)).frame(width: 1)

                        // Opción 2: Descargar local
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: "#FBB040"))
                            Text("Descargar local")
                                .font(.headline)
                            Text("Guarda el JSON en tu Mac")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(height: 32)
                            Button {
                                saveJSON()
                            } label: {
                                Label("Descargar JSON", systemImage: "arrow.down.doc.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "#FBB040"))
                            Text(snap.formulaeCount + snap.casksCount > 0 ? "\(appState.selectedProfile.fileName)" : " ")
                                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
                    }
                    .padding(16)
                }
                .frame(height: 220)

                if let msg = uploadMessage {
                    Label(msg, systemImage: uploadIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(uploadIsError ? .red : .green)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((uploadIsError ? Color.red : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
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
                .frame(height: 220)
            } else {
                // Sin snapshot — zona parecida a Import vacía
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.quaternaryLabelColor).opacity(0.08)))
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Aún no hay snapshot").font(.headline)
                        Text("Pulsa Create Snapshot para escanear tu entorno Homebrew")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(32)
                }
                .frame(height: 200)
            }

            if !jsonPreview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JSON Preview").font(.headline)
                        Spacer()
                        Button("Copiar") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(jsonPreview, forType: .string) }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Descargar…") { saveJSON() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    ScrollView { Text(jsonPreview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(height: 180).padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()
        }
        .padding(20)
        .task { if appState.snapshot == nil { await createSnapshot() } }
    }

    private func createSnapshot() async {
        uploadMessage = nil
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
            uploadMessage = "Guardado en \(url.lastPathComponent) ✓"
            uploadIsError = false
        }
    }

    private func uploadToRepo() async {
        guard let snap = appState.snapshot else { return }
        let token = appState.githubToken
        guard !token.isEmpty else {
            uploadMessage = "Configura tu token en Settings"
            uploadIsError = true
            return
        }
        let owner = appState.repoOwner.trimmingCharacters(in: .whitespaces)
        guard !owner.isEmpty else {
            uploadMessage = "Configura el owner del repo en Sync o Settings"
            uploadIsError = true
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let gh = GitHubService(token: token)
            try await gh.commitSnapshot(owner: owner, repo: appState.repoName, snapshot: snap, profile: appState.selectedProfile.name)
            uploadMessage = "Subido a \(owner)/\(appState.repoName) ✓"
            uploadIsError = false
        } catch {
            uploadMessage = error.localizedDescription
            uploadIsError = true
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
