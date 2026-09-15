import Foundation

// MARK: - Package (Formula)

struct BrewFormula: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let version: String
    let tap: String?
    let pinned: Bool
    let kegOnly: Bool
    let installedOnRequest: Bool

    enum CodingKeys: String, CodingKey {
        case name, version, tap, pinned, kegOnly, installedOnRequest
    }
}

// MARK: - Cask

struct BrewCask: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let version: String
    let tap: String?
    let autoUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case name, version, tap, autoUpdate
    }
}

// Backward compat alias used by older docs
typealias Package = BrewFormula
