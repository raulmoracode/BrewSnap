// MenuBarView.swift
// BrewSnap — Menu bar extra (dropdown).

import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isSyncing = false
    @State private var message: String?
    @State private var messageIsError = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill").foregroundStyle(Color(hex: "#FBB040"))
                Text("BrewSnap").font(.headline)
                Spacer()
            }

            if let snap = appState.snapshot {
                Text("Last snapshot: \(snap.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            Button {
                Task { await sync() }
            } label: {
                Label(isSyncing ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#FBB040"))
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()
            .disabled(isSyncing)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(messageIsError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                mainWindowAction(requestTab: nil)
            } label: {
                Label("Open BrewSnap…", systemImage: "arrow.up.left.and.arrow.down.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()

            Button {
                mainWindowAction(requestTab: .settings)
            } label: {
                Label("Settings…", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#FF2C2C"))
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
            .handCursor()
        }
        .padding(12)
        .frame(width: 220)
        .background(.regularMaterial)
    }

    /// If the main window is open, just close the dropdown and do nothing.
    /// Otherwise open the window (optionally switching to the requested tab).
    private func mainWindowAction(requestTab: MainView.Tab?) {
        let existing = appState.mainWindow
            ?? NSApp.windows.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("BrewSnapMain") })
        if let window = existing, window.isVisible {
            dismiss()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            openWindow(id: "main")
        }
        if let requestTab {
            appState.requestedTab = requestTab.rawValue
        }
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        message = nil
        await appState.scan()
        guard let snapshot = appState.snapshot else {
            message = "Could not create a snapshot"
            messageIsError = true
            return
        }
        guard snapshot.isComplete else {
            message = "Snapshot incomplete - check brew"
            messageIsError = true
            return
        }
        let token = appState.githubToken
        guard !token.isEmpty else {
            message = "Configure a token in Settings"
            messageIsError = true
            return
        }
        let owner = appState.repoOwner.trimmingCharacters(in: .whitespaces)
        guard !owner.isEmpty else {
            message = "Configure owner and repo in Settings"
            messageIsError = true
            return
        }
        do {
            let gh = GitHubService(token: token)
            try await gh.commitSnapshot(owner: owner, repo: appState.repoName, snapshot: snapshot, profile: appState.selectedProfile.name)
            message = "Synced \(owner)/\(appState.repoName) ✓"
            messageIsError = false
            appState.syncStatus = .synced(Date())
        } catch {
            message = error.localizedDescription
            messageIsError = true
            appState.syncStatus = .error(error.localizedDescription)
        }
    }
}

private struct HandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func handCursor() -> some View {
        modifier(HandCursorModifier())
    }
}
