// SettingsView.swift
// BrewSnap — GitHub token and repo configuration.

import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var tokenInput: String = ""
    @State private var repoOwnerInput: String = ""
    @State private var repoNameInput: String = ""
    @State private var showToken = false
    @State private var validationMessage: String?
    @State private var tokenValidationMessage: String?
    @State private var isValidating = false
    @State private var isCreatingRepo = false
    @State private var isDeletingRepo = false
    @State private var showDeleteRepoConfirm = false
    @State private var hasStoredToken = false
    @State private var isTokenLocked = false
    @State private var launchAtLogin = false
    @State private var tokenFieldHeight: CGFloat = 0

    /// Placeholder bullets shown while the token is validated and locked.
    private let maskToken = "••••••••"

    private var hasToken: Bool { !tokenInput.isEmpty || hasStoredToken }

    private var repoWebURL: URL? {
        let owner = repoOwnerInput.trimmingCharacters(in: .whitespaces)
        let name = repoNameInput.trimmingCharacters(in: .whitespaces).isEmpty ? "brewsnap-config" : repoNameInput.trimmingCharacters(in: .whitespaces)
        guard !owner.isEmpty else { return nil }
        return URL(string: "https://github.com/\(owner)/\(name)")
    }

    private var tokenStateBadge: (text: String, color: Color, icon: String) {
        if isTokenLocked {
            return ("Connected", .green, "checkmark.circle.fill")
        } else if hasToken {
            return ("Unverified", .orange, "questionmark.circle.fill")
        } else {
            return ("Not configured", .secondary, "circle.dashed")
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                githubCard
                launchCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Settings")
        .onAppear {
            // No Keychain reads here: SecItemCopyMatching triggers the
            // system password prompt. UserDefaults flags only.
showToken = false
            hasStoredToken = appState.hasGithubToken
            isTokenLocked = hasStoredToken
            tokenInput = hasStoredToken ? maskToken : ""
            repoOwnerInput = appState.repoOwner
            repoNameInput = "brewsnap-config"
            appState.repoName = "brewsnap-config"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .scrollContentBackground(.hidden)
        .alert("Delete repository?", isPresented: $showDeleteRepoConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteRepo() }
            }
        } message: {
            Text("\(repoOwnerInput)/\(repoNameInput.isEmpty ? "brewsnap-config" : repoNameInput) will be removed from GitHub. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.largeTitle.bold()).tracking(-0.5)
            Text("Connect BrewSnap to GitHub and control how it launches.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - GitHub Card

    private var githubCard: some View {
        SettingsCard(title: "GitHub") {
            // Token row
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Personal Access Token")
                        .font(.subheadline.weight(.semibold))
                    StatusBadgex(text: tokenStateBadge.text, color: tokenStateBadge.color, icon: tokenStateBadge.icon)
                    Spacer()
                    if let tokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo%2Cdelete_repo&description=BrewSnap") {
                        Link(destination: tokenURL) {
                            Label("Create one on GitHub", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Group {
                        if showToken {
                            TextField("ghp_…", text: $tokenInput)
                        } else {
                            SecureField("ghp_…", text: $tokenInput)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .disabled(isTokenLocked)
                    .frame(maxHeight: .infinity)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onGeometryChange(for: CGFloat.self, of: \.size.height) { tokenFieldHeight = $0 }
                        }
                    )

                    Button {
                        toggleShowToken()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .frame(maxHeight: .infinity)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .pressable()
                    .help(showToken ? "Hide token" : "Show token")

                    Button {
                        Task { await validate() }
                    } label: {
                        if isValidating {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Validate", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                    .background(.green, in: RoundedRectangle(cornerRadius: 6))
                    .opacity(!hasToken || isValidating ? 0.45 : 1)
                    .pressable()
                    .disabled(!hasToken || isValidating)

                    Button(role: .destructive) {
                        deleteToken()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 9)
                            .frame(maxHeight: .infinity)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .opacity(!hasToken ? 0.45 : 1)
                    .pressable()
                    .disabled(!hasToken)
                    .help("Delete token from Keychain")
                }
                .frame(height: tokenFieldHeight > 0 ? tokenFieldHeight : 26)

                if let tokenMsg = tokenValidationMessage {
                    InlineMessage(text: tokenMsg)
                }
            }

            Divider()

            // Repo row
            VStack(alignment: .leading, spacing: 10) {
                Text("Repository")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    TextField("owner", text: $repoOwnerInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .disabled(true)
                        .foregroundStyle(.secondary)
                        .help("Owner filled in when you validate the token")
                    Text("/").foregroundStyle(.secondary)
                    Text("brewsnap-config")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .help("The repo name is always brewsnap-config")
                    Spacer()
                    if let url = repoWebURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
                        .pressable()
                        .help("Open \(repoOwnerInput)/\(repoNameInput) on GitHub")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await createRepo() }
                    } label: {
                        if isCreatingRepo {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Creating…") }
                        } else {
                            Label("Create private repo", systemImage: "plus.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#1D3557"))
                    .disabled(!hasToken || isValidating || isCreatingRepo)

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteRepoConfirm = true
                    } label: {
                        if isDeletingRepo {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Deleting…") }
                        } else {
                            Label("Delete repo", systemImage: "trash.fill")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(repoOwnerInput.trimmingCharacters(in: .whitespaces).isEmpty
                              || repoNameInput.trimmingCharacters(in: .whitespaces).isEmpty
                              || !hasToken || isDeletingRepo)
                }

                if let msg = validationMessage {
                    InlineMessage(text: msg)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: tokenValidationMessage)
        .animation(.easeOut(duration: 0.2), value: validationMessage)
    }

    // MARK: - Launch Card

    private var launchCard: some View {
        SettingsCard(title: "Launch at login") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Abrir al iniciar sesión")
                        .font(.subheadline.weight(.semibold))
                    Text("Inicia BrewSnap automáticamente al iniciar sesión.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }
        }
    }

    // MARK: - Private Methods

    private func effectiveToken() -> String {
        let typed = tokenInput.trimmingCharacters(in: .whitespaces)
        // Dots mean "stored in Keychain, not typed": fall back to Keychain.
        if !typed.isEmpty, typed != maskToken { return typed }
        // Keychain is only touched here (explicit user action)
        return (try? KeychainService.load()) ?? ""
    }

    private func setHasStoredToken(_ value: Bool) {
        hasStoredToken = value
        appState.hasGithubToken = value
    }

    private func showTokenMessage(_ text: String) {
        tokenValidationMessage = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if tokenValidationMessage == text {
                tokenValidationMessage = nil
            }
        }
    }

    private func toggleShowToken() {
        if !showToken, tokenInput.isEmpty || tokenInput == maskToken, hasStoredToken {
            // Load on demand when tapping Show
            if let stored = try? KeychainService.load() {
                tokenInput = stored
            } else {
                showTokenMessage("Could not read the token from Keychain")
                setHasStoredToken(false)
                return
            }
        }
        showToken.toggle()
    }

    private func noteStoredTokenIfNeeded(typedWasEmpty: Bool) {
        // Migration: token in Keychain but flag still false
        if typedWasEmpty && !hasStoredToken {
            setHasStoredToken(true)
        }
    }

    private func deleteToken() {
        appState.clearGithubToken()
        tokenInput = ""
        showToken = false
        setHasStoredToken(false)
        isTokenLocked = false
        repoOwnerInput = ""
        appState.repoOwner = ""
        showTokenMessage("Token deleted")
    }

    private func validate() async {
        let typedWasEmpty = tokenInput.trimmingCharacters(in: .whitespaces).isEmpty
        let token = effectiveToken()
        guard !token.isEmpty else {
            showTokenMessage("Configure your token first")
            return
        }
        isValidating = true; defer { isValidating = false }
        do {
            let gh = GitHubService(token: token)
            let user = try await gh.validateToken()
            appState.githubToken = token
            setHasStoredToken(true)
            isTokenLocked = true
            noteStoredTokenIfNeeded(typedWasEmpty: typedWasEmpty)
            repoOwnerInput = user
            appState.repoOwner = user
            showTokenMessage("✓ Valid token - user: \(user)")
        } catch {
            showTokenMessage("✗ \(error.localizedDescription)")
        }
    }

    private func createRepo() async {
        let token = effectiveToken()
        guard !token.isEmpty else {
            validationMessage = "Configure your token first"
            return
        }
        isCreatingRepo = true; defer { isCreatingRepo = false }
        do {
            let gh = GitHubService(token: token)
            let owner = try await gh.validateToken()
            repoOwnerInput = owner
            appState.repoOwner = owner
            appState.repoName = "brewsnap-config"
            repoNameInput = "brewsnap-config"
            try await gh.createPrivateRepo(name: "brewsnap-config")
            appState.hasConfiguredRepo = true
            validationMessage = "Repository \(owner)/brewsnap-config created ✓"
        } catch GitHubError.repoExists {
            validationMessage = "Repo already exists - you can Update in Sync"
        } catch {
            validationMessage = "✗ \(error.localizedDescription)"
        }
    }

    private func deleteRepo() async {
        let token = effectiveToken()
        let owner = repoOwnerInput.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty, !owner.isEmpty else {
            validationMessage = "Missing token or owner to delete"
            return
        }
        isDeletingRepo = true; defer { isDeletingRepo = false }
        do {
            try await GitHubService(token: token).deleteRepo(owner: owner, repo: "brewsnap-config")
            appState.hasConfiguredRepo = false
            validationMessage = "Repository \(owner)/brewsnap-config deleted ✓"
        } catch let GitHubError.api(message, code) where code == 403 || code == 404 {
            validationMessage = "✗ \(message) - token needs the delete_repo scope: create one in Create one on GitHub, save it and validate"
        } catch {
            validationMessage = "✗ \(error.localizedDescription)"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            validationMessage = "Could not change login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Reusable Components

/// A titled card container used to group related settings.
private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.quaternary, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

/// Small pill showing connection/validation state next to a section label.
private struct StatusBadgex: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}

/// Feedback line for success/error text returned by GitHub calls,
/// styled as a small colored banner instead of plain caption text.
private struct InlineMessage: View {
    let text: String

    private var isSuccess: Bool { text.contains("✓") }
    private var color: Color { isSuccess ? .green : .red }
    private var icon: String { isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill" }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .transition(.opacity)
    }
}
