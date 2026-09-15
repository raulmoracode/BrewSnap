// ExportView.swift
// BrewSnap — Export screen with 2 options: upload to repo or download locally.

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
                Text("Save your Homebrew environment as JSON and choose where to keep it.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let err = appState.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .padding(8).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if let snap = appState.snapshot, snap.formulae.isEmpty && snap.casks.isEmpty && snap.taps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No packages found — check brew", systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.orange).font(.callout.weight(.semibold))
                    Text("brew: \(ShellExecutor.brewExecutable()) · exists: \(FileManager.default.isExecutableFile(atPath: ShellExecutor.brewExecutable()) ? "yes" : "no")")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Run in Terminal: brew list --formula --versions | wc -l")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            // Siempre visible — 2 opciones (responsive: HStack si cabe, VStack si no)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                // Option 1: Upload to repo
                VStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#1D3557"))
                    Text("Upload to repo")
                        .font(.headline)
                    Text("Sync the JSON to your private GitHub repo")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 32)
                    Button {
                        Task { await uploadToRepo() }
                    } label: {
                        Label(isUploading ? "Uploading…" : "Upload to repo", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#1D3557"))
                    .disabled(appState.snapshot == nil || (appState.snapshot?.formulae.isEmpty == true && appState.snapshot?.casks.isEmpty == true) || isUploading || appState.githubToken.isEmpty)
                    if appState.githubToken.isEmpty {
                        Text("Configure your token in Settings")
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

                // Option 2: Download locally
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#FBB040"))
                    Text("Download locally")
                        .font(.headline)
                    Text("Save the JSON to your Mac")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(height: 32)
                    Button {
                        saveJSON()
                    } label: {
                        Label("Download JSON", systemImage: "arrow.down.doc.fill")
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
                        Text("Upload to repo").font(.headline)
                        Text("Sync the JSON to your private GitHub repo").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(height: 32)
                        Button { Task { await uploadToRepo() } } label: { Label(isUploading ? "Uploading…" : "Upload to repo", systemImage: "arrow.triangle.2.circlepath") }
                            .buttonStyle(.borderedProminent).tint(Color(hex: "#1D3557")).disabled(appState.snapshot == nil || (appState.snapshot?.formulae.isEmpty == true && appState.snapshot?.casks.isEmpty == true) || isUploading || appState.githubToken.isEmpty)
                    }.frame(maxWidth: .infinity).padding(16).background(.background, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundStyle(Color.secondary.opacity(0.35)))
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 32)).foregroundStyle(Color(hex: "#FBB040"))
                        Text("Download locally").font(.headline)
                        Text("Save the JSON to your Mac").font(.caption).foregroundStyle(.secondary).frame(height: 32)
                        Button { saveJSON() } label: { Label("Download JSON", systemImage: "arrow.down.doc.fill") }
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
                            Text("Scanning…").font(.headline)
                        } else {
                            Image(systemName: "shippingbox.fill").font(.system(size: 36)).foregroundStyle(.secondary)
                            Text("Preparing snapshot…").font(.headline)
                        }
                        Text("Generated automatically")
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

    /// Creates a fresh snapshot and updates the JSON preview.
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
            uploadMessage = "Saved to \(url.lastPathComponent) ✓"
            uploadIsError = false
        }
    }

    private func uploadToRepo() async {
        guard let snap = appState.snapshot else { return }
        let token = appState.githubToken
        guard !token.isEmpty else {
            uploadMessage = "Configure your token in Settings"
            uploadIsError = true
            return
        }
        let owner = appState.repoOwner.trimmingCharacters(in: .whitespaces)
        guard !owner.isEmpty else {
            uploadMessage = "Configure the repo owner in Sync or Settings"
            uploadIsError = true
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let gh = GitHubService(token: token)
            try await gh.commitSnapshot(owner: owner, repo: appState.repoName, snapshot: snap, profile: appState.selectedProfile.name)
            uploadMessage = "Uploaded to \(owner)/\(appState.repoName) ✓"
            uploadIsError = false
        } catch {
            uploadMessage = error.localizedDescription
            uploadIsError = true
        }
    }
}
