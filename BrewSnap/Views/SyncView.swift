// SyncView.swift
// BrewSnap — GitHub sync.

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
            Text("Sync with GitHub").font(.title2.bold())
            Text("Sync your snapshot with a private repository en GitHub. Un clic, sin comandos git.")
                .font(.subheadline).foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Repository").font(.headline)
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
                        Text("Snapshot ready: \(snapshot.formulaeCount) formulae, \(snapshot.casksCount) casks")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("First create a snapshot in the Export tab", systemImage: "info.circle").font(.caption).foregroundStyle(.orange)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await doSync() }
                        } label: {
                            Label(isSyncing ? "Syncing…" : "Update", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent).disabled(appState.snapshot == nil || isSyncing || ownerInput.isEmpty)

                        Button("Create private repo") {
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

            GroupBox("How it works") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Generates JSON and uploads via GitHub API (PUT /contents)", systemImage: "1.circle.fill")
                    Label("Si no hay cambios: \"Already up to date\"", systemImage: "2.circle.fill")
                    Label("Each sync is a commit: snapshot: 67 formulae, 23 casks — 2026-09-15", systemImage: "3.circle.fill")
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
        guard !token.isEmpty else { message = "Configure your token in Settings"; isError = true; return }
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
        guard !token.isEmpty else { message = "Configure your token in Settings"; isError = true; return }
        isSyncing = true; defer { isSyncing = false }
        do {
            let gh = GitHubService(token: token)
            let owner = try await gh.validateToken()
            ownerInput = owner; appState.repoOwner = owner
            try await gh.createPrivateRepo(name: appState.repoName)
            message = "Repository \(owner)/\(appState.repoName) creado ✓"; isError = false
        } catch GitHubError.repoExists {
            message = "Repo already exists — you can Update"; isError = false
        } catch {
            message = error.localizedDescription; isError = true
        }
    }
}
