// BrewTap.swift
// BrewSnap — Homebrew tap model.

import Foundation

struct BrewTap: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let remote: String?
    let trusted: Bool
}
