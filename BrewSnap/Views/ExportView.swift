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
                Text("Export").font(.title2.bold()).tracking(-0.4)
                Text("Save your Homebrew environment as JSON and choose where to keep it.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let err = appState.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
                    .padding(8).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if let snap = appState.snapshot, !snap.isComplete {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Upload blocked: this snapshot is incomplete", systemImage: "lock.fill")
                        .font(.callout.weight(.semibold))
                    ForEach(snap.warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.orange)
                .padding(12)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if let snap = appState.snapshot, snap.formulae.isEmpty && snap.casks.isEmpty && snap.taps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No packages found - check brew", systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.orange).font(.callout.weight(.semibold))
                    Text("brew: \(ShellExecutor.brewExecutable()) · exists: \(FileManager.default.isExecutableFile(atPath: ShellExecutor.brewExecutable()) ? "yes" : "no")")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text("Run in Terminal: brew list --formula --versions | wc -l")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            // Big Download locally box
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.quaternaryLabelColor).opacity(0.08)))

                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "#FBB040"))
                    Text("Download locally")
                        .font(.title3.weight(.semibold))
                    Text("Save the JSON to your Mac")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button {
                        saveJSON()
                    } label: {
                        Label("Download JSON", systemImage: "arrow.down.doc.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#FBB040"))
                    .disabled(appState.snapshot == nil)
                }
                .padding(28)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { saveJSON() }

            // Upload to repo button
            Button {
                Task { await uploadToRepo() }
            } label: {
                Label(isUploading ? "Uploading…" : "Upload to repo", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#1D3557"))
            .controlSize(.large)
            .disabled(appState.snapshot == nil || appState.snapshot?.isComplete == false || (appState.snapshot?.formulae.isEmpty == true && appState.snapshot?.casks.isEmpty == true) || isUploading || !appState.hasGithubToken)

            if let msg = uploadMessage, uploadIsError {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button {
                        uploadMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Dismiss")
                    Text(msg)
                        .font(.callout).foregroundStyle(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            } else if let msg = uploadMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
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
                        Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(jsonPreview, forType: .string) }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Download…") { saveJSON() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                    ScrollView { Text(jsonPreview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(height: 180).padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            }
            .padding(20)
            .animation(.easeOut(duration: 0.2), value: uploadMessage)
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
        guard snap.isComplete else {
            uploadMessage = "Upload blocked: snapshot is incomplete"
            uploadIsError = true
            return
        }
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