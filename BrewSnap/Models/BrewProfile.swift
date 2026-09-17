// BrewProfile.swift
// BrewSnap — Profile model (work, personal, etc.).

import Foundation

struct BrewProfile: Codable, Identifiable, Hashable, Sendable {
    // MARK: - Properties

    var id: String { name }
    let name: String
    var fileName: String { "\(name).json" }
    var displayName: String { name.capitalized }
    let createdAt: Date
    let isActive: Bool

    // MARK: - Defaults

    static let `default` = BrewProfile(name: "default", createdAt: Date(), isActive: true)
    static let work = BrewProfile(name: "work", createdAt: Date(), isActive: false)
    static let personal = BrewProfile(name: "personal", createdAt: Date(), isActive: false)
}
