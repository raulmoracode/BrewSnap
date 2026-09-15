// ProfilesView.swift
// BrewSnap — Profile management (work, personal).

import SwiftUI

struct ProfilesView: View {
    @Environment(AppState.self) private var appState
    @State private var newProfileName = ""
    @State private var diffSnapshot: BrewSnapshot?
    @State private var showDiff = false

    // MARK: - Body

    var body: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 16) {
            Text("Profiles").font(.title2.bold())
            Text("Each profile is a standalone JSON file in the repo (work.json, personal.json…).")
                .font(.subheadline).foregroundStyle(.secondary)

            List {
                ForEach(appState.profiles, id: \.name) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(profile.displayName).font(.headline)
                                if profile.name == appState.selectedProfile.name {
                                    Text("Active").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.accentColor, in: Capsule()).foregroundStyle(.white)
                                }
                            }
                            Text(profile.fileName).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile.name != appState.selectedProfile.name {
                            Button("Activate") { appState.selectedProfile = profile }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }.padding(.vertical, 4)
                }
            }.frame(height: 220)

            HStack(spacing: 8) {
                TextField("New profile (e.g. dev)", text: $newProfileName).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Button("Add") {
                    let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !name.isEmpty, !appState.profiles.contains(where: { $0.name == name }) else { return }
                    appState.profiles.append(BrewProfile(name: name, createdAt: Date(), isActive: false))
                    newProfileName = ""
                }.buttonStyle(.borderedProminent).disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Compare snapshots").font(.headline)
                Text("Phase 2: compare two snapshots to see git diff-like differences.").font(.caption).foregroundStyle(.secondary)
                Button {
                    if let snap = appState.snapshot { diffSnapshot = snap; showDiff = true }
                } label: { Label("Compare (preview)", systemImage: "arrow.left.arrow.right") }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showDiff) {
                    if let a = diffSnapshot, let b = appState.snapshot {
                        DiffView(diff: SnapshotService.diff(a, b)).padding().frame(minWidth: 500, minHeight: 400)
                    }
                }
            }

            Spacer()
        }.padding(20)
    }
}
