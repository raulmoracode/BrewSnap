// BrewSnapshot.swift
// BrewSnap — Main snapshot JSON model (versioned, Codable).

import Foundation

struct BrewSnapshot: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let hostname: String
    let macOS: String
    let arch: String
    let homebrew: String
    var formulae: [BrewFormula]
    var casks: [BrewCask]
    var taps: [BrewTap]
    var services: [BrewService]
    var formulaeCount: Int
    var casksCount: Int
    var totalDiskUsage: String?

    enum CodingKeys: String, CodingKey {
        case version, createdAt, hostname, macOS, arch, homebrew
        case formulae, casks, taps, services
        case formulaeCount, casksCount, totalDiskUsage
    }

    init(
        version: Int = 1,
        createdAt: Date = Date(),
        hostname: String,
        macOS: String,
        arch: String,
        homebrew: String,
        formulae: [BrewFormula] = [],
        casks: [BrewCask] = [],
        taps: [BrewTap] = [],
        services: [BrewService] = [],
        totalDiskUsage: String? = nil
    ) {
        self.version = version
        self.createdAt = createdAt
        self.hostname = hostname
        self.macOS = macOS
        self.arch = arch
        self.homebrew = homebrew
        self.formulae = formulae
        self.casks = casks
        self.taps = taps
        self.services = services
        self.formulaeCount = formulae.count
        self.casksCount = casks.count
        self.totalDiskUsage = totalDiskUsage
    }

    // Custom decoding to handle missing counts in older snapshots
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        hostname = try c.decode(String.self, forKey: .hostname)
        macOS = try c.decode(String.self, forKey: .macOS)
        arch = try c.decode(String.self, forKey: .arch)
        homebrew = try c.decode(String.self, forKey: .homebrew)
        formulae = try c.decodeIfPresent([BrewFormula].self, forKey: .formulae) ?? []
        casks = try c.decodeIfPresent([BrewCask].self, forKey: .casks) ?? []
        taps = try c.decodeIfPresent([BrewTap].self, forKey: .taps) ?? []
        services = try c.decodeIfPresent([BrewService].self, forKey: .services) ?? []
        formulaeCount = try c.decodeIfPresent(Int.self, forKey: .formulaeCount) ?? formulae.count
        casksCount = try c.decodeIfPresent(Int.self, forKey: .casksCount) ?? casks.count
        totalDiskUsage = try c.decodeIfPresent(String.self, forKey: .totalDiskUsage)
    }

    static var preview: BrewSnapshot {
        BrewSnapshot(
            hostname: "MacBook-Pro-de-Raul",
            macOS: "15.7",
            arch: "arm64",
            homebrew: "4.5.0",
            formulae: [
                BrewFormula(name: "git", version: "2.47.0", tap: nil, pinned: false, kegOnly: false, installedOnRequest: true),
                BrewFormula(name: "python@3.13", version: "3.13.7", tap: nil, pinned: true, kegOnly: false, installedOnRequest: true),
            ],
            casks: [
                BrewCask(name: "visual-studio-code", version: "1.93.0", tap: nil, autoUpdate: true),
            ],
            taps: [
                BrewTap(name: "hashicorp/tap", remote: "https://github.com/hashicorp/homebrew-tap", trusted: true),
            ],
            services: [
                BrewService(name: "postgresql@16", status: .started, restart: true),
            ],
            totalDiskUsage: "4.2 GB"
        )
    }
}
