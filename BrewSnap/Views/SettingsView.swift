// SettingsView.swift
// BrewSnap — Configuración GitHub token y repo.

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var tokenInput: String = ""
    @State private var repoNameInput: String = ""
    @State private var showToken = false
    @State private var validationMessage: String?
    @State private var isValidating = false

    var body: some View {
        Form {
            Section("GitHub") {
                HStack {
                    if showToken {
                        TextField("ghp_…", text: $tokenInput).textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("ghp_…", text: $tokenInput).textFieldStyle(.roundedBorder)
                    }
                    Button(showToken ? "Ocultar" : "Mostrar") { showToken.toggle() }.controlSize(.small)
                }
                LabeledContent("Token") {
                    Text("Se guarda en Keychain").font(.caption).foregroundStyle(.secondary)
                }
                TextField("Nombre del repo", text: $repoNameInput).textFieldStyle(.roundedBorder)
                LabeledContent("Repo") {
                    Text("Privado · \(repoNameInput.isEmpty ? "brewsnap" : repoNameInput)").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        Task { await validate() }
                    } label: { Label(isValidating ? "Validando…" : "Validar token", systemImage: "checkmark.shield.fill") }
                    .disabled(tokenInput.isEmpty || isValidating)
                    if let tokenURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=BrewSnap") {
                        Link("Crear token en GitHub", destination: tokenURL)
                            .font(.caption)
                    }
                }
                if let msg = validationMessage {
                    Text(msg).font(.caption).foregroundStyle(msg.contains("✓") ? .green : .red)
                }
            }

            Section("General") {
                LabeledContent("Bundle ID", value: "com.raulmorasanchez.BrewSnap")
                LabeledContent("Versión", value: "1.0.0 (MVP)")
                if let repoURL = URL(string: "https://github.com/raulmoracode/brewsnap") {
                    Link("Repositorio brewsnap", destination: repoURL)
                }
                if let tapURL = URL(string: "https://github.com/raulmoracode/homebrew-tap") {
                    Link("Homebrew tap", destination: tapURL)
                }
            }

            Section {
                Button("Guardar") { save() }.buttonStyle(.borderedProminent)
                Button("Borrar token del Keychain", role: .destructive) {
                    try? KeychainService.delete(); tokenInput = ""; validationMessage = "Token borrado"
                }.disabled(tokenInput.isEmpty && appState.githubToken.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            tokenInput = (try? KeychainService.load()) ?? ""
            repoNameInput = appState.repoName
        }
        .scrollContentBackground(.hidden)
    }

    private func save() {
        if !tokenInput.isEmpty { try? KeychainService.save(token: tokenInput) }
        if !repoNameInput.isEmpty { appState.repoName = repoNameInput }
        validationMessage = "Guardado ✓"
    }

    private func validate() async {
        isValidating = true; defer { isValidating = false }
        do {
            let gh = GitHubService(token: tokenInput)
            let user = try await gh.validateToken()
            validationMessage = "✓ Token válido — usuario: \(user)"
        } catch {
            validationMessage = "✗ \(error.localizedDescription)"
        }
    }
}
