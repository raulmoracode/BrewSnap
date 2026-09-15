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
    @State private var gitHubOwner = ""
    @State private var gitHubRepo = ""
    @State private var gitHubProfile = ""
    @State private var isFetchingGitHub = false
    @State private var gitHubMessage: String?
    @State private var gitHubIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import").font(.title2.bold())
                    Text("Añade un JSON de BrewSnap para previsualizarlo o restaurarlo — local o desde tu repo privado")
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

            // GitHub import — descarga desde repo privado (inverso a Export → Subir)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Desde repo privado de GitHub", systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                    Spacer()
                    if isFetchingGitHub { ProgressView().scaleEffect(0.7) }
                }
                Text("Descarga el JSON directamente de tu repo privado, igual que lo subes en Export")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("owner", text: $gitHubOwner).textFieldStyle(.roundedBorder).frame(width: 130)
                    Text("/").foregroundStyle(.secondary)
                    TextField("repo", text: $gitHubRepo).textFieldStyle(.roundedBorder).frame(width: 130)
                    TextField("perfil", text: $gitHubProfile).textFieldStyle(.roundedBorder).frame(width: 100)
                    Button {
                        Task { await fetchFromGitHub() }
                    } label: {
                        Label(isFetchingGitHub ? "Descargando…" : "Descargar", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#1D3557"))
                    .disabled(gitHubOwner.isEmpty || gitHubRepo.isEmpty || isFetchingGitHub || appState.githubToken.isEmpty)
                }
                if appState.githubToken.isEmpty {
                    Text("Configura tu token en Settings").font(.caption2).foregroundStyle(.orange)
                }
                if let msg = gitHubMessage {
                    Label(msg, systemImage: gitHubIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(gitHubIsError ? .red : .green)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((gitHubIsError ? Color.red : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                HStack(spacing: 6) {
                    ForEach(appState.profiles, id: \.name) { profile in
                        Button(profile.name) { gitHubProfile = profile.name }
                            .buttonStyle(.bordered).controlSize(.small)
                            .tint(gitHubProfile == profile.name ? Color.accentColor : .secondary)
                    }
                    Spacer()
                    Button("Usar repo de Settings") {
                        gitHubOwner = appState.repoOwner
                        gitHubRepo = appState.repoName
                    }.controlSize(.small)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
            .onAppear {
                gitHubOwner = appState.repoOwner
                gitHubRepo = appState.repoName
                gitHubProfile = appState.selectedProfile.name
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
        gitHubMessage = nil
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

    private func fetchFromGitHub() async {
        let token = appState.githubToken
        guard !token.isEmpty else {
            gitHubMessage = "Configura tu token en Settings"
            gitHubIsError = true
            return
        }
        let owner = gitHubOwner.trimmingCharacters(in: .whitespaces)
        let repo = gitHubRepo.trimmingCharacters(in: .whitespaces)
        let profile = gitHubProfile.trimmingCharacters(in: .whitespaces).isEmpty ? "brewsnap" : gitHubProfile.trimmingCharacters(in: .whitespaces)
        guard !owner.isEmpty, !repo.isEmpty else {
            gitHubMessage = "Owner y repo requeridos"
            gitHubIsError = true
            return
        }
        isFetchingGitHub = true
        defer { isFetchingGitHub = false }
        do {
            let service = GitHubService(token: token)
            let (sha, content) = try await service.fetchFile(owner: owner, repo: repo, path: "\(profile).json")
            _ = sha
            let data = Data(content.utf8)
            // content ya es JSON decodificado de base64
            let snapData = content.data(using: .utf8) ?? data
            let snap = try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: snapData)
            importedSnapshot = snap
            jsonText = content
            fileName = "\(profile).json (GitHub)"
            errorMessage = nil
            gitHubMessage = "Descargado \(profile).json de \(owner)/\(repo) ✓"
            gitHubIsError = false
            // Guarda repo para futuras syncs
            appState.repoOwner = owner
            appState.repoName = repo
        } catch {
            gitHubMessage = error.localizedDescription
            gitHubIsError = true
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
