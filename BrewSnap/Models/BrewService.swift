// BrewService.swift
// BrewSnap — Homebrew service model.

import Foundation

struct BrewService: Codable, Identifiable, Hashable, Sendable {
    // MARK: - Properties

    var id: String { name }
    let name: String
    let status: ServiceStatus
    let restart: Bool

    // MARK: - Status

    enum ServiceStatus: String, Codable, Sendable {
        case started
        case stopped
        case scheduled
        case unknown
        case error
    }
}
