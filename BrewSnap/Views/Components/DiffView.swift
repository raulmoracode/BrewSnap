// DiffView.swift
// BrewSnap — Diff view between snapshots.

import SwiftUI

struct DiffView: View {
    let diff: SnapshotDiff

    var body: some View {
        if diff.isEmpty {
            ContentUnavailableView("Already up to date", systemImage: "checkmark.circle.fill", description: Text("No hay diferencias entre los snapshots"))
        } else {
            List {
                if !diff.addedFormulae.isEmpty {
                    Section("Added (\(diff.addedFormulae.count))") {
                        ForEach(diff.addedFormulae, id: \.name) { f in
                            HStack {
                                Label(f.name, systemImage: "plus.circle.fill").foregroundStyle(.green)
                                Spacer(); Text(f.version).foregroundStyle(.secondary).font(.caption.monospaced())
                            }
                        }
                    }
                }
                if !diff.removedFormulae.isEmpty {
                    Section("Eliminados (\(diff.removedFormulae.count))") {
                        ForEach(diff.removedFormulae, id: \.name) { f in
                            HStack {
                                Label(f.name, systemImage: "minus.circle.fill").foregroundStyle(.red)
                                Spacer(); Text(f.version).foregroundStyle(.secondary).font(.caption.monospaced())
                            }
                        }
                    }
                }
                if !diff.updatedFormulae.isEmpty {
                    Section("Actualizados (\(diff.updatedFormulae.count))") {
                        ForEach(diff.updatedFormulae, id: \.new.name) { pair in
                            HStack {
                                Label(pair.new.name, systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
                                Spacer()
                                Text("\(pair.old.version) → \(pair.new.version)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !diff.addedCasks.isEmpty {
                    Section("Added casks") {
                        ForEach(diff.addedCasks, id: \.name) { c in
                            Label(c.name, systemImage: "plus.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                if !diff.addedTaps.isEmpty {
                    Section("Added taps") {
                        ForEach(diff.addedTaps, id: \.name) { t in
                            Label(t.name, systemImage: "plus.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }
}
