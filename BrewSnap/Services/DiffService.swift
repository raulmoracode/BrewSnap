// DiffService.swift
// BrewSnap — Comparación entre snapshots.

import Foundation

struct SnapshotDiff: Sendable {
    var addedFormulae: [BrewFormula]
    var removedFormulae: [BrewFormula]
    var updatedFormulae: [(old: BrewFormula, new: BrewFormula)]
    var addedCasks: [BrewCask]
    var removedCasks: [BrewCask]
    var updatedCasks: [(old: BrewCask, new: BrewCask)]
    var addedTaps: [BrewTap]
    var removedTaps: [BrewTap]

    var isEmpty: Bool {
        addedFormulae.isEmpty && removedFormulae.isEmpty && updatedFormulae.isEmpty &&
        addedCasks.isEmpty && removedCasks.isEmpty && updatedCasks.isEmpty &&
        addedTaps.isEmpty && removedTaps.isEmpty
    }

    var summary: String {
        if isEmpty { return "Already up to date" }
        var parts: [String] = []
        if !addedFormulae.isEmpty { parts.append("+\(addedFormulae.count) formulae") }
        if !removedFormulae.isEmpty { parts.append("-\(removedFormulae.count) formulae") }
        if !updatedFormulae.isEmpty { parts.append("~\(updatedFormulae.count) updated") }
        if !addedCasks.isEmpty { parts.append("+\(addedCasks.count) casks") }
        if !removedCasks.isEmpty { parts.append("-\(removedCasks.count) casks") }
        return parts.joined(separator: ", ")
    }
}

enum DiffService {
    static func diff(old: BrewSnapshot, new: BrewSnapshot) -> SnapshotDiff {
        let oldF = Dictionary(uniqueKeysWithValues: old.formulae.map { ($0.name, $0) })
        let newF = Dictionary(uniqueKeysWithValues: new.formulae.map { ($0.name, $0) })

        let addedF = new.formulae.filter { oldF[$0.name] == nil }
        let removedF = old.formulae.filter { newF[$0.name] == nil }
        let updatedF: [(BrewFormula, BrewFormula)] = new.formulae.compactMap { nf in
            guard let of = oldF[nf.name], of.version != nf.version else { return nil }
            return (of, nf)
        }

        let oldC = Dictionary(uniqueKeysWithValues: old.casks.map { ($0.name, $0) })
        let newC = Dictionary(uniqueKeysWithValues: new.casks.map { ($0.name, $0) })
        let addedC = new.casks.filter { oldC[$0.name] == nil }
        let removedC = old.casks.filter { newC[$0.name] == nil }
        let updatedC: [(BrewCask, BrewCask)] = new.casks.compactMap { nc in
            guard let oc = oldC[nc.name], oc.version != nc.version else { return nil }
            return (oc, nc)
        }

        let oldT = Set(old.taps.map(\.name))
        let newT = Set(new.taps.map(\.name))
        let addedT = new.taps.filter { !oldT.contains($0.name) }
        let removedT = old.taps.filter { !newT.contains($0.name) }

        return SnapshotDiff(
            addedFormulae: addedF,
            removedFormulae: removedF,
            updatedFormulae: updatedF,
            addedCasks: addedC,
            removedCasks: removedC,
            updatedCasks: updatedC,
            addedTaps: addedT,
            removedTaps: removedT
        )
    }
}
