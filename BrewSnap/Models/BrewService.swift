// BrewService.swift
// BrewSnap — Modelo de servicio Homebrew.

import Foundation

struct BrewService: Codable, Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let status: ServiceStatus
    let restart: Bool

    enum ServiceStatus: String, Codable, Sendable {
        case started
        case stopped
        case scheduled
        case unknown
        case error
    }
}
