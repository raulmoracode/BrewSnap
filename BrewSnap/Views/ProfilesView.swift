// ProfilesView.swift
// BrewSnap — Gestión de perfiles (work, personal).

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
            Text("Perfiles").font(.title2.bold())
            Text("Cada perfil es un archivo JSON independiente en el repo (work.json, personal.json…).")
                .font(.subheadline).foregroundStyle(.secondary)

            List {
                ForEach(appState.profiles, id: \.name) { profile in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(profile.displayName).font(.headline)
                                if profile.name == appState.selectedProfile.name {
                                    Text("Activo").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.accentColor, in: Capsule()).foregroundStyle(.white)
                                }
                            }
                            Text(profile.fileName).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profile.name != appState.selectedProfile.name {
                            Button("Activar") { appState.selectedProfile = profile }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }.padding(.vertical, 4)
                }
            }.frame(height: 220)

            HStack(spacing: 8) {
                TextField("Nuevo perfil (ej: dev)", text: $newProfileName).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Button("Añadir") {
                    let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !name.isEmpty, !appState.profiles.contains(where: { $0.name == name }) else { return }
                    appState.profiles.append(BrewProfile(name: name, createdAt: Date(), isActive: false))
                    newProfileName = ""
                }.buttonStyle(.borderedProminent).disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Comparar snapshots").font(.headline)
                Text("Fase 2: compara dos snapshots para ver diferencias tipo git diff.").font(.caption).foregroundStyle(.secondary)
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
