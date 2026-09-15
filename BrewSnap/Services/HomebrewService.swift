// HomebrewService.swift
// BrewSnap — Service that scans the Homebrew environment via CLI and generates snapshots.

import Foundation

// MARK: - Error

/// HomebrewService specific errors.
enum BrewServiceError: LocalizedError {
    case brewNotFound
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "Homebrew is not installed or not in PATH"
        case .commandFailed(let message):
            return message
        }
    }
}

// MARK: - Service

/// Scans the Homebrew system sequentially (avoids brew lock deadlock).
final class HomebrewService: Sendable {

    // MARK: - Public API

    /// Generates a complete snapshot of the Homebrew environment.
    func scan() async throws -> BrewSnapshot {
        print("[BrewSnap] scan start")
        let startedAt = Date()

        let systemInfo = await withTimeout(
            "systemInfo",
            seconds: 5,
            { await VersionHelper.systemInfo() },
            fallback: (
                hostname: Host.current().localizedName ?? "unknown",
                macOS: "15.0",
                arch: "arm64",
                homebrew: "unknown"
            )
        )

        let formulaeRaw: [(name: String, version: String)] = await withTimeout(
            "formulae",
            seconds: 12,
            { try await self.fetchFormulae() },
            fallback: []
        )
        print("[BrewSnap] formulae \(formulaeRaw.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let casksRaw: [(name: String, version: String)] = await withTimeout(
            "casks",
            seconds: 12,
            { try await self.fetchCasks() },
            fallback: []
        )
        print("[BrewSnap] casks \(casksRaw.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let taps: [BrewTap] = await withTimeout(
            "taps",
            seconds: 15,
            { try await self.fetchTaps() },
            fallback: []
        )
        print("[BrewSnap] taps \(taps.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let services: [BrewService] = await withTimeout(
            "services",
            seconds: 8,
            { try await self.fetchServices() },
            fallback: []
        )
        print("[BrewSnap] services \(services.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let pinned: Set<String> = await withTimeout(
            "pinned",
            seconds: 5,
            { try await self.fetchPinned() },
            fallback: []
        )

        let diskUsage: String? = await withTimeout(
            "diskUsage",
            seconds: 5,
            { try await self.fetchDiskUsage() },
            fallback: nil
        )

        print("[BrewSnap] scan done \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let formulae: [BrewFormula] = formulaeRaw.map { item in
            BrewFormula(
                name: item.name,
                version: item.version,
                tap: nil,
                pinned: pinned.contains(item.name),
                kegOnly: false,
                installedOnRequest: true
            )
        }

        let casks: [BrewCask] = casksRaw.map { item in
            BrewCask(name: item.name, version: item.version, tap: nil, autoUpdate: false)
        }

        return BrewSnapshot(
            hostname: systemInfo.hostname,
            macOS: systemInfo.macOS,
            arch: systemInfo.arch,
            homebrew: systemInfo.homebrew,
            formulae: formulae.sorted { $0.name < $1.name },
            casks: casks.sorted { $0.name < $1.name },
            taps: taps.sorted { $0.name < $1.name },
            services: services,
            totalDiskUsage: diskUsage
        )
    }

    // MARK: - Private Helpers

    private func brewExecutable() -> String {
        ShellExecutor.brewExecutable()
    }

    /// Runs a job with timeout and returns fallback on expiry.
    private func withTimeout<T: Sendable>(
        _ label: String,
        seconds: Double,
        _ work: @escaping @Sendable () async throws -> T,
        fallback: T
    ) async -> T {
        do {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await work() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw CancellationError()
                }
                guard let first = try await group.next() else { return fallback }
                group.cancelAll()
                return first
            }
        } catch {
            print("[BrewSnap] timeout/error in \(label): \(error)")
            return fallback
        }
    }

    // MARK: - Fetchers

    private func fetchFormulae() async throws -> [(name: String, version: String)] {
        let brew = brewExecutable()
        let result: ShellResult
        do {
            result = try await ShellExecutor.run(brew, args: ["list", "--formula", "--versions"])
        } catch {
            result = try await ShellExecutor.runShell("\(brew) list --formula --versions")
        }

        if !result.isSuccess, !result.stderr.isEmpty {
            print("[BrewSnap] fetchFormulae stderr: \(result.stderr) (brew=\(brew))")
        }

        guard !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let fallback = try? await ShellExecutor.runShell("brew list --formula --versions 2>&1; echo __EXIT:$?"),
               fallback.stdout.contains("__EXIT:0") {
                return VersionHelper.parseBrewVersions(output: fallback.stdout)
            }
            return []
        }

        return VersionHelper.parseBrewVersions(output: result.stdout)
    }

    private func fetchCasks() async throws -> [(name: String, version: String)] {
        let brew = brewExecutable()
        let candidates = [
            ["list", "--cask", "--versions"],
            ["list", "--casks", "--versions"],
        ]

        for args in candidates {
            if let result = try? await ShellExecutor.run(brew, args: args),
               result.isSuccess, !result.stdout.isEmpty {
                return VersionHelper.parseBrewVersions(output: result.stdout)
            }
        }

        let result = try? await ShellExecutor.runShell(
            "\(brew) list --cask --versions 2>/dev/null || \(brew) list --casks --versions 2>/dev/null || brew list --cask --versions 2>/dev/null || true"
        )
        return VersionHelper.parseBrewVersions(output: result?.stdout ?? "")
    }

    private func fetchTaps() async throws -> [BrewTap] {
        let brew = brewExecutable()
        var names: [String] = []

        if let result = try? await ShellExecutor.run(brew, args: ["tap"]), result.isSuccess {
            names = result.stdout
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else if let result = try? await ShellExecutor.runShell("\(brew) tap 2>/dev/null || brew tap 2>/dev/null || true") {
            names = result.stdout
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        guard !names.isEmpty else {
            print("[BrewSnap] fetchTaps: 0 taps (brew=\(brew))")
            return []
        }

        // Fast path sin per-tap tap-info para no bloquear scan.
        return names.map { BrewTap(name: $0, remote: nil, trusted: true) }
    }

    private func fetchServices() async throws -> [BrewService] {
        let brew = brewExecutable()
        var stdout: String?

        if let result = try? await ShellExecutor.run(brew, args: ["services", "list", "--json"]) {
            stdout = result.stdout
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) services list --json 2>/dev/null || brew services list --json 2>/dev/null || true"
        ) {
            stdout = result.stdout
        }

        guard let output = stdout, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return VersionHelper.parseBrewServices(jsonString: output)
    }

    private func fetchPinned() async throws -> Set<String> {
        let brew = brewExecutable()
        var output = ""

        if let result = try? await ShellExecutor.run(brew, args: ["list", "--pinned"]) {
            output = result.stdout
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) list --pinned 2>/dev/null || brew list --pinned 2>/dev/null || true"
        ) {
            output = result.stdout
        }

        let pins = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Set(pins)
    }

    private func fetchDiskUsage() async throws -> String? {
        let brew = brewExecutable()
        var cellar = ""

        if let result = try? await ShellExecutor.run(brew, args: ["--cellar"]) {
            cellar = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) --cellar 2>/dev/null || brew --cellar 2>/dev/null || echo /opt/homebrew/Cellar"
        ) {
            cellar = result.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
        }

        guard !cellar.isEmpty else { return nil }

        guard let result = try? await ShellExecutor.run("/usr/bin/du", args: ["-sh", cellar]) else {
            return nil
        }

        let size = result.stdout
            .split(separator: "\t").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        return size.isEmpty ? nil : String(size)
    }
}
