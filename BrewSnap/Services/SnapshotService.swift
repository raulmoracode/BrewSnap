// SnapshotService.swift
// BrewSnap — Generación y persistencia de snapshots.

import Foundation

enum SnapshotService {
    static func generate() async throws -> BrewSnapshot {
        let service = HomebrewService()
        return try await service.scan()
    }

    static func save(_ snapshot: BrewSnapshot, to url: URL) throws {
        let data = try JSONEncoder.brewsnap.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    static func load(from url: URL) throws -> BrewSnapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder.brewsnap.decode(BrewSnapshot.self, from: data)
    }

    static func toJSONString(_ snapshot: BrewSnapshot) throws -> String {
        try snapshot.toPrettyJSON()
    }

    /// Compare two snapshots via DiffService
    static func diff(_ a: BrewSnapshot, _ b: BrewSnapshot) -> SnapshotDiff {
        DiffService.diff(old: a, new: b)
    }
}
