// BrewFormula.swift
// BrewSnap — Homebrew formula model (part of snapshot JSON).

import Foundation

/// Homebrew formula (e.g. `git`, `python@3.13`).
struct BrewFormula: Codable, Identifiable, Hashable, Sendable {
    // MARK: - Properties

    var id: String { name }

    let name: String
    let version: String
    let tap: String?
    let pinned: Bool
    let kegOnly: Bool
    let installedOnRequest: Bool
    let homepage: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name, version, tap, pinned, kegOnly, installedOnRequest, homepage
    }
}
