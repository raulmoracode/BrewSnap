// ImportView.swift
// BrewSnap — Zone for importing JSON (drag & drop).

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppState.self) private var appState
    @State private var importedSnapshot: BrewSnapshot?
    @State private var fileName: String?
    @State private var importMessage: String?
    @State private var importIsError = false
    @State private var isTargeted = false
    @State private var jsonText: String = ""
    @State private var isDownloading = false
    @State private var isRestoring = false
    @State private var restoreProgress: [String] = []
    @State private var restoreMessage: String?
    @State private var importedFromGitHub = false
    @State private var showJSONPopover = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import").font(.title2.bold()).tracking(-0.4)
                    Text("Import a BrewSnap JSON from GitHub or a local file.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

            // Big local JSON drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.quaternaryLabelColor).opacity(0.08))
                    )

                VStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color(hex: "#FBB040"))
                    Text("Import from local JSON")
                        .font(.title3.weight(.semibold))
                    Text("Drag a BrewSnap JSON or click to select")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button {
                        selectFile()
                    } label: {
                        Label("Select file", systemImage: "folder.badge.plus")
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
                .padding(28)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { selectFile() }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                handleURL(url)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }

            // Import from GitHub button
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await downloadFromRepo() }
                } label: {
                    Label(isDownloading ? "Downloading…" : "Import from GitHub", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#1D3557"))
                .controlSize(.large)
                .disabled(isDownloading || isRestoring || !appState.hasGithubToken || appState.repoOwner.isEmpty)
            }

            if let msg = importMessage, importIsError {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button {
                        importMessage = nil
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
            } else if let msg = importMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.callout).foregroundStyle(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
            }

            if let snap = importedSnapshot, !importedFromGitHub {
                VStack(alignment: .leading, spacing: 12) {
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
                            Task { await restore(dryRun: false) }
                        } label: {
                            Label(isRestoring ? "Restoring…" : "Restore this Mac", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(isRestoring || !snap.isComplete)

                        Button {
                            clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(isRestoring)

                        Button("View JSON") {
                            showJSONPopover.toggle()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .help("Open the JSON in a code block")
                        .popover(isPresented: $showJSONPopover, arrowEdge: .top) {
                            JSONCodeBlockPopup(text: jsonText)
                        }
                    }

                    if !restoreProgress.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(restoreProgress, id: \.self) { Text($0).font(.caption.monospaced()) }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if let restoreMessage {
                        Text(restoreMessage).font(.callout).foregroundStyle(restoreMessage.hasPrefix("Error") ? .red : .green)
                    }
                }
            }

                Spacer()
            }
            .padding(20)
            .animation(.easeOut(duration: 0.2), value: importMessage)
        }
    }

    // MARK: - Private Methods

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
        // Needs security-scoped access when coming from drop
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        fileName = url.lastPathComponent
        importedFromGitHub = false
        importMessage = nil
        importIsError = false
        do {
            let data = try Data(contentsOf: url)
            jsonText = String(data: data, encoding: .utf8) ?? ""
            let snap = try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
            importedSnapshot = snap
        } catch {
            importedSnapshot = nil
            jsonText = ""
            importMessage = "Invalid JSON: \(error.localizedDescription)"
            importIsError = true
        }
    }

    private func clear() {
        importedSnapshot = nil
        importedFromGitHub = false
        fileName = nil
        importMessage = nil
        importIsError = false
        jsonText = ""
        restoreProgress = []
        restoreMessage = nil
    }

    private func downloadFromRepo() async {
        guard !appState.repoOwner.isEmpty, appState.hasGithubToken else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let file = try await GitHubService(token: appState.githubToken).fetchFile(
                owner: appState.repoOwner,
                repo: "brewsnap",
                path: "\(appState.selectedProfile.name).json"
            )
            guard let data = file.content.data(using: .utf8) else { throw ShellError.outputDecodingFailed }
            let snapshot = try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
            importedFromGitHub = true
            importedSnapshot = snapshot
            appState.snapshot = snapshot
            appState.lastError = nil
            jsonText = file.content
            fileName = "\(appState.repoOwner)/brewsnap/\(appState.selectedProfile.name).json"
            importMessage = "Imported \(appState.repoOwner)/brewsnap ✓"
            importIsError = false
        } catch {
            importMessage = "GitHub import failed: \(error.localizedDescription)"
            importIsError = true
        }
    }

    private func restore(dryRun: Bool) async {
        guard let snap = importedSnapshot else { return }
        isRestoring = true
        restoreProgress = []
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            try await HomebrewService().restore(snap, dryRun: dryRun) { line in
                Task { @MainActor in restoreProgress.append(line) }
            }
            restoreMessage = dryRun ? "Dry run complete" : "Restore complete"
            if !dryRun { appState.snapshot = try? await SnapshotService.generate() }
        } catch {
            restoreMessage = "Error: \(error.localizedDescription)"
        }
    }
}

private struct JSONCodeBlockPopup: View {
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("brewsnap.json").font(.headline)
                Spacer()
                Button(copied ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            ScrollView {
                Text(text)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .frame(width: 540, height: 440)
    }
}

#Preview {
    ImportView().environment(AppState()).frame(width: 800, height: 600)
}
