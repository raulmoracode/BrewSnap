// BrewFormula.swift
// BrewSnap — Modelo de fórmula Homebrew (parte de snapshot JSON).

import Foundation

/// Fórmula Homebrew (ej. `git`, `python@3.13`).
struct BrewFormula: Codable, Identifiable, Hashable, Sendable {
    // MARK: - Properties

    var id: String { name }

    let name: String
    let version: String
    let tap: String?
    let pinned: Bool
    let kegOnly: Bool
    let installedOnRequest: Bool

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name, version, tap, pinned, kegOnly, installedOnRequest
    }
}
