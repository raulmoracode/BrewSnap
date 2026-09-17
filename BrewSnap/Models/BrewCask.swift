// BrewCask.swift
// BrewSnap — Homebrew cask model (part of snapshot JSON).

import Foundation

/// Cask Homebrew (ej. `visual-studio-code`).
struct BrewCask: Codable, Identifiable, Hashable, Sendable {
    // MARK: - Properties

    var id: String { name }

    let name: String
    let version: String
    let tap: String?
    let autoUpdate: Bool
    let homepage: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name, version, tap, autoUpdate, homepage
    }
}
