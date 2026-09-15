// SyncView.swift
// BrewSnap — Sincronización con GitHub.

import SwiftUI

struct SyncView: View {
    @Environment(AppState.self) private var appState
    @State private var ownerInput: String = ""
    @State private var isSyncing = false
    @State private var message: String?
    @State private var isError = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sync con GitHub").font(.title2.bold())
            Text("Sincroniza tu snapshot con un repositorio privado en GitHub. Un clic, sin comandos git.")
                .font(.subheadline).foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Repositorio").font(.headline)
                        Spacer()
                        statusBadge
                    }
                    HStack {
                        TextField("owner", text: $ownerInput).textFieldStyle(.roundedBorder).frame(width: 160)
                        Text("/").foregroundStyle(.secondary)
                        Text(appState.repoName).font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .onAppear { ownerInput = appState.repoOwner }

                    if let snapshot = appState.snapshot {
                        Text("Snapshot listo: \(snapshot.formulaeCount) formulae, \(snapshot.casksCount) casks")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Primero crea un snapshot en la pestaña Export", systemImage: "info.circle").font(.caption).foregroundStyle(.orange)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await doSync() }
                        } label: {
                            Label(isSyncing ? "Syncing…" : "Update", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent).disabled(appState.snapshot == nil || isSyncing || ownerInput.isEmpty)

                        Button("Crear repo privado") {
                            Task { await createRepo() }
                        }
                        .buttonStyle(.bordered).disabled(ownerInput.isEmpty || appState.githubToken.isEmpty)
                    }

                    if let msg = message {
                        Label(msg, systemImage: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.callout).foregroundStyle(isError ? .red : .green)
                            .padding(8).background((isError ? Color.red : Color.green).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.padding(4)
            }

            GroupBox("Cómo funciona") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Genera JSON y lo sube vía GitHub API (PUT /contents)", systemImage: "1.circle.fill")
                    Label("Si no hay cambios: \"Already up to date\"", systemImage: "2.circle.fill")
                    Label("Cada sync es un commit: snapshot: 67 formulae, 23 casks — 2026-09-15", systemImage: "3.circle.fill")
                }.font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(4)
            }

            Spacer()
        }.padding(20)
    }

    private var statusBadge: some View {
        switch appState.syncStatus {
        case .idle: StatusBadge(status: .idle)
        case .syncing: StatusBadge(status: .syncing)
        case .synced: StatusBadge(status: .synced)
        case .outOfSync: StatusBadge(status: .outOfSync)
        case .error: StatusBadge(status: .error)
        }
    }

    // MARK: - Private Methods

    private func doSync() async {
        guard let snapshot = appState.snapshot else { return }
        let token = appState.githubToken
        guard !token.isEmpty else { message = "Configura tu token en Settings"; isError = true; return }
        isSyncing = true; defer { isSyncing = false }
        do {
            let gh = GitHubService(token: token)
            let owner = ownerInput.trimmingCharacters(in: .whitespaces)
            appState.repoOwner = owner
            try await gh.commitSnapshot(owner: owner, repo: appState.repoName, snapshot: snapshot, profile: appState.selectedProfile.name)
            message = "Sincronizado correctamente ✓"; isError = false
            appState.syncStatus = .synced(Date())
        } catch {
            message = error.localizedDescription; isError = true
            appState.syncStatus = .error(error.localizedDescription)
        }
    }

    private func createRepo() async {
        let token = appState.githubToken
        guard !token.isEmpty else { message = "Configura tu token en Settings"; isError = true; return }
        isSyncing = true; defer { isSyncing = false }
        do {
            let gh = GitHubService(token: token)
            let owner = try await gh.validateToken()
            ownerInput = owner; appState.repoOwner = owner
            try await gh.createPrivateRepo(name: appState.repoName)
            message = "Repositorio \(owner)/\(appState.repoName) creado ✓"; isError = false
        } catch GitHubError.repoExists {
            message = "El repo ya existe — puedes hacer Update"; isError = false
        } catch {
            message = error.localizedDescription; isError = true
        }
    }
}
