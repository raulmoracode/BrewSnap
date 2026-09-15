// ExportView.swift
// BrewSnap — Pantalla Export con 2 opciones: subir al repo o descargar local.

import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    // MARK: - Properties

    @Environment(AppState.self) private var appState
    @State private var jsonPreview: String = ""
    @State private var isUploading = false
    @State private var uploadMessage: String?
    @State private var uploadIsError = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export").font(.title2.bold())
                if let snap = appState.snapshot {
                    Text("\(snap.formulaeCount) formulae · \(snap.casksCount) casks · \(snap.taps.count) taps")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Elige cómo exportar tu snapshot")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Text("Guarda tu entorno Homebrew en un JSON y elige dónde conservarlo — descarga en tu Mac o sincronizado en un repositorio privado.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if let err = appState.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .padding(8).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if let snap = appState.snapshot, snap.formulae.isEmpty && snap.casks.isEmpty && snap.taps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No se detectaron paquetes — verifica brew", systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.orange).font(.callout.weight(.semibold))
                    Text("brew: \(ShellExecutor.brewExecutable()) · existe: \(FileManager.default.isExecutableFile(atPath: ShellExecutor.brewExecutable()) ? "sí" : "no")")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Ejecuta en Terminal: brew list --formula --versions | wc -l")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            // Siempre visible — 2 opciones (responsive: HStack si cabe, VStack si no)
            ViewThatFits(in: .horizontal) {
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
                    .disabled(appState.snapshot == nil || (appState.snapshot?.formulae.isEmpty == true && appState.snapshot?.casks.isEmpty == true) || isUploading || appState.githubToken.isEmpty)
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
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(Color.secondary.opacity(0.35)))

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
                    .disabled(appState.snapshot == nil)
                    Text(appState.snapshot != nil ? "\(appState.selectedProfile.fileName)" : " ")
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(Color.secondary.opacity(0.35)))
                }

                // Fallback vertical cuando no cabe en horizontal
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundStyle(Color(hex: "#1D3557"))
                        Text("Subir al repo").font(.headline)
                        Text("Sincroniza el JSON a tu repo privado en GitHub").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(height: 32)
                        Button { Task { await uploadToRepo() } } label: { Label(isUploading ? "Subiendo…" : "Subir al repo", systemImage: "arrow.triangle.2.circlepath") }
                            .buttonStyle(.borderedProminent).tint(Color(hex: "#1D3557")).disabled(appState.snapshot == nil || (appState.snapshot?.formulae.isEmpty == true && appState.snapshot?.casks.isEmpty == true) || isUploading || appState.githubToken.isEmpty)
                    }.frame(maxWidth: .infinity).padding(16).background(.background, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(Color.secondary.opacity(0.35)))
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 32)).foregroundStyle(Color(hex: "#FBB040"))
                        Text("Descargar local").font(.headline)
                        Text("Guarda el JSON en tu Mac").font(.caption).foregroundStyle(.secondary).frame(height: 32)
                        Button { saveJSON() } label: { Label("Descargar JSON", systemImage: "arrow.down.doc.fill") }
                            .buttonStyle(.borderedProminent).tint(Color(hex: "#FBB040")).disabled(appState.snapshot == nil)
                    }.frame(maxWidth: .infinity).padding(16).background(.background, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(Color.secondary.opacity(0.35)))
                }
            }

            if let msg = uploadMessage {
                Label(msg, systemImage: uploadIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(uploadIsError ? .red : .green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((uploadIsError ? Color.red : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            if appState.snapshot == nil {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.quaternaryLabelColor).opacity(0.08)))
                    VStack(spacing: 12) {
                        if appState.isScanning {
                            ProgressView().scaleEffect(1.2)
                            Text("Escaneando…").font(.headline)
                        } else {
                            Image(systemName: "shippingbox.fill").font(.system(size: 36)).foregroundStyle(.secondary)
                            Text("Preparando snapshot…").font(.headline)
                        }
                        Text("Se genera automáticamente")
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
            }
            .padding(20)
        }
        .task { if appState.snapshot == nil { await createSnapshot() } }
    }

    // MARK: - Private Methods

    /// Crea un snapshot fresco y actualiza el preview JSON.
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
