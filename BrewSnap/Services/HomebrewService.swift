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

    private struct ScanValue<Value: Sendable>: Sendable {
        let value: Value
        let warning: String?
    }

    private struct FormulaMetadata: Sendable {
        let tap: String?
        let kegOnly: Bool
        let installedOnRequest: Bool
        let pinned: Bool
        let homepage: String?
    }

    private struct CaskMetadata: Sendable {
        let tap: String?
        let autoUpdate: Bool
        let homepage: String?
    }

    // MARK: - Public API

    func restore(_ snapshot: BrewSnapshot, dryRun: Bool = false, onProgress: @Sendable (String) -> Void = { _ in }) async throws {
        guard snapshot.isComplete else {
            throw BrewServiceError.commandFailed("Cannot restore an incomplete snapshot")
        }

        let brew = brewExecutable()
        for tap in snapshot.taps {
            try await runRestoreCommand(brew, args: ["tap", tap.name], description: "Tap \(tap.name)", dryRun: dryRun, onProgress: onProgress)
        }
        for formula in snapshot.formulae {
            try await runRestoreCommand(brew, args: ["install", formula.name], description: "Formula \(formula.name)", dryRun: dryRun, onProgress: onProgress)
        }
        for cask in snapshot.casks {
            try await runRestoreCommand(brew, args: ["install", "--cask", cask.name], description: "Cask \(cask.name)", dryRun: dryRun, onProgress: onProgress)
        }
        for service in snapshot.services where service.status == .started {
            try await runRestoreCommand(brew, args: ["services", "start", service.name], description: "Service \(service.name)", dryRun: dryRun, onProgress: onProgress)
        }
    }

    /// Generates a complete snapshot of the Homebrew environment.
    func scan() async throws -> BrewSnapshot {
        print("[BrewSnap] scan start")
        let startedAt = Date()

        let systemInfoResult = await withTimeout(
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
        var warnings = systemInfoResult.warning.map { [$0] } ?? []
        let systemInfo = systemInfoResult.value

        let formulaeResult: ScanValue<[(name: String, version: String)]> = await withTimeout(
            "formulae",
            seconds: 12,
            { try await self.fetchFormulae() },
            fallback: []
        )
        warnings.append(contentsOf: formulaeResult.warning.map { [$0] } ?? [])
        let formulaeRaw = formulaeResult.value
        print("[BrewSnap] formulae \(formulaeRaw.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let casksResult: ScanValue<[(name: String, version: String)]> = await withTimeout(
            "casks",
            seconds: 12,
            { try await self.fetchCasks() },
            fallback: []
        )
        warnings.append(contentsOf: casksResult.warning.map { [$0] } ?? [])
        let casksRaw = casksResult.value
        print("[BrewSnap] casks \(casksRaw.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let tapsResult = await withTimeout(
            "taps",
            seconds: 15,
            { try await self.fetchTaps() },
            fallback: []
        )
        warnings.append(contentsOf: tapsResult.warning.map { [$0] } ?? [])
        let taps = tapsResult.value
        print("[BrewSnap] taps \(taps.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let servicesResult = await withTimeout(
            "services",
            seconds: 8,
            { try await self.fetchServices() },
            fallback: []
        )
        warnings.append(contentsOf: servicesResult.warning.map { [$0] } ?? [])
        let services = servicesResult.value
        print("[BrewSnap] services \(services.count) en \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let pinnedResult = await withTimeout(
            "pinned",
            seconds: 5,
            { try await self.fetchPinned() },
            fallback: []
        )
        warnings.append(contentsOf: pinnedResult.warning.map { [$0] } ?? [])
        let pinned = pinnedResult.value

        let metadataResult: ScanValue<(formulae: [String: FormulaMetadata], casks: [String: CaskMetadata])> = await withTimeout(
            "homepages",
            seconds: 8,
            { try await self.fetchHomepages() },
            fallback: ([:], [:])
        )
        warnings.append(contentsOf: metadataResult.warning.map { [$0] } ?? [])
        let metadata = metadataResult.value

        let diskUsageResult = await withTimeout(
            "diskUsage",
            seconds: 5,
            { try await self.fetchDiskUsage() },
            fallback: nil
        )
        warnings.append(contentsOf: diskUsageResult.warning.map { [$0] } ?? [])
        let diskUsage = diskUsageResult.value

        print("[BrewSnap] scan done \(String(format: "%.1f", Date().timeIntervalSince(startedAt)))s")

        let formulae: [BrewFormula] = formulaeRaw.map { item in
            BrewFormula(
                name: item.name,
                version: item.version,
                tap: metadata.formulae[item.name]?.tap,
                pinned: metadata.formulae[item.name]?.pinned ?? pinned.contains(item.name),
                kegOnly: metadata.formulae[item.name]?.kegOnly ?? false,
                installedOnRequest: metadata.formulae[item.name]?.installedOnRequest ?? true,
                homepage: metadata.formulae[item.name]?.homepage
            )
        }

        let casks: [BrewCask] = casksRaw.map { item in
            BrewCask(
                name: item.name,
                version: item.version,
                tap: metadata.casks[item.name]?.tap,
                autoUpdate: metadata.casks[item.name]?.autoUpdate ?? false,
                homepage: metadata.casks[item.name]?.homepage
            )
        }

        return BrewSnapshot(
            hostname: systemInfo.hostname,
            macOS: systemInfo.macOS,
            arch: systemInfo.arch,
            homebrew: systemInfo.homebrew,
            isComplete: warnings.isEmpty,
            warnings: warnings,
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

    private func runRestoreCommand(
        _ brew: String,
        args: [String],
        description: String,
        dryRun: Bool,
        onProgress: @Sendable (String) -> Void
    ) async throws {
        onProgress("\(dryRun ? "Would install" : "Installing"): \(description)")
        guard !dryRun else { return }
        let result = try await ShellExecutor.run(brew, args: args)
        guard result.isSuccess else {
            throw BrewServiceError.commandFailed("\(description) failed: \(result.stderr)")
        }
    }

    /// Runs a job with timeout and returns fallback on expiry.
    private func withTimeout<T: Sendable>(
        _ label: String,
        seconds: Double,
        _ work: @escaping @Sendable () async throws -> T,
        fallback: T
    ) async -> ScanValue<T> {
        do {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await work() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw CancellationError()
                }
                guard let first = try await group.next() else {
                    return ScanValue(value: fallback, warning: "\(label) returned no result")
                }
                group.cancelAll()
                return ScanValue(value: first, warning: nil)
            }
        } catch {
            print("[BrewSnap] timeout/error in \(label): \(error)")
            return ScanValue(value: fallback, warning: "\(label) failed: \(error.localizedDescription)")
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

        guard result.isSuccess else {
            throw BrewServiceError.commandFailed(result.stderr.isEmpty ? "brew list --formula failed" : result.stderr)
        }

        guard !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let fallback = try? await ShellExecutor.runShell("brew list --formula --versions 2>&1; echo __EXIT:$?"),
               fallback.stdout.contains("__EXIT:0") {
                return VersionHelper.parseBrewVersions(output: fallback.stdout)
            }
            throw BrewServiceError.commandFailed("brew list --formula returned no usable output")
        }

        return VersionHelper.parseBrewVersions(output: result.stdout)
    }

    private func fetchCasks() async throws -> [(name: String, version: String)] {
        let brew = brewExecutable()
        let candidates = [
            ["list", "--cask", "--versions"],
            ["list", "--casks", "--versions"],
        ]

        var lastError = "brew list --cask failed"
        for args in candidates {
            if let result = try? await ShellExecutor.run(brew, args: args) {
                if result.isSuccess {
                    return VersionHelper.parseBrewVersions(output: result.stdout)
                }
                lastError = result.stderr
            }
        }

        if let result = try? await ShellExecutor.runShell(
            "\(brew) list --cask --versions 2>/dev/null || \(brew) list --casks --versions 2>/dev/null"
        ), result.isSuccess {
                return VersionHelper.parseBrewVersions(output: result.stdout)
        }

        throw BrewServiceError.commandFailed(lastError.isEmpty ? "brew list --cask failed" : lastError)
    }

    private func fetchTaps() async throws -> [BrewTap] {
        let brew = brewExecutable()
        let names: [String]

        if let result = try? await ShellExecutor.run(brew, args: ["tap"]), result.isSuccess {
            names = result.stdout
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else if let result = try? await ShellExecutor.runShell("\(brew) tap 2>/dev/null || brew tap 2>/dev/null"), result.isSuccess {
            names = result.stdout
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            throw BrewServiceError.commandFailed("brew tap failed")
        }

        // Fast path sin per-tap tap-info para no bloquear scan.
        return names.map { BrewTap(name: $0, remote: nil, trusted: true) }
    }

    private func fetchServices() async throws -> [BrewService] {
        let brew = brewExecutable()
        var stdout: String?

        if let result = try? await ShellExecutor.run(brew, args: ["services", "list", "--json"]), result.isSuccess {
            stdout = result.stdout
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) services list --json 2>/dev/null || brew services list --json 2>/dev/null"
        ), result.isSuccess {
            stdout = result.stdout
        }

        guard let output = stdout, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrewServiceError.commandFailed("brew services list failed")
        }

        let services = VersionHelper.parseBrewServices(jsonString: output)
        guard let data = output.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw BrewServiceError.commandFailed("brew services returned invalid JSON")
        }
        return services
    }

    private func fetchPinned() async throws -> Set<String> {
        let brew = brewExecutable()
        var output = ""

        if let result = try? await ShellExecutor.run(brew, args: ["list", "--pinned"]), result.isSuccess {
            output = result.stdout
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) list --pinned 2>/dev/null || brew list --pinned 2>/dev/null"
        ), result.isSuccess {
            output = result.stdout
        } else {
            throw BrewServiceError.commandFailed("brew list --pinned failed")
        }

        let pins = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Set(pins)
    }

    private func fetchHomepages() async throws -> (formulae: [String: FormulaMetadata], casks: [String: CaskMetadata]) {
        let brew = brewExecutable()

        struct InfoResponse: Decodable {
            struct InstalledInfo: Decodable { let installed_on_request: Bool? }
            struct FormulaInfo: Decodable {
                let name: String
                let homepage: String?
                let tap: String?
                let keg_only: Bool?
                let pinned: Bool?
                let installed: [InstalledInfo]?
            }
            struct CaskInfo: Decodable {
                let token: String
                let homepage: String?
                let tap: String?
                let auto_updates: Bool?
            }
            let formulae: [FormulaInfo]
            let casks: [CaskInfo]
        }

        func parse(_ stdout: String) -> (formulae: [String: FormulaMetadata], casks: [String: CaskMetadata])? {
            guard let data = stdout.data(using: .utf8),
                  let info = try? JSONDecoder().decode(InfoResponse.self, from: data) else { return nil }
            var f: [String: FormulaMetadata] = [:]
            var c: [String: CaskMetadata] = [:]
            for item in info.formulae {
                f[item.name] = FormulaMetadata(
                    tap: item.tap,
                    kegOnly: item.keg_only ?? false,
                    installedOnRequest: item.installed?.first?.installed_on_request ?? true,
                    pinned: item.pinned ?? false,
                    homepage: item.homepage
                )
            }
            for item in info.casks {
                c[item.token] = CaskMetadata(
                    tap: item.tap,
                    autoUpdate: item.auto_updates ?? false,
                    homepage: item.homepage
                )
            }
            return (f, c)
        }

        if let result = try? await ShellExecutor.run(brew, args: ["info", "--json=v2", "--installed"]),
           let parsed = parse(result.stdout) {
            return parsed
        }
        if let result = try? await ShellExecutor.runShell("\(brew) info --json=v2 --installed 2>/dev/null || brew info --json=v2 --installed 2>/dev/null || true"),
           let parsed = parse(result.stdout) {
            return parsed
        }
        throw BrewServiceError.commandFailed("brew info --json=v2 --installed failed")
    }

    private func fetchDiskUsage() async throws -> String? {
        let brew = brewExecutable()
        var cellar = ""

        if let result = try? await ShellExecutor.run(brew, args: ["--cellar"]), result.isSuccess {
            cellar = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let result = try? await ShellExecutor.runShell(
            "\(brew) --cellar 2>/dev/null || brew --cellar 2>/dev/null"
        ), result.isSuccess {
            cellar = result.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
        }

        guard !cellar.isEmpty else { throw BrewServiceError.commandFailed("brew --cellar returned no path") }

        guard let result = try? await ShellExecutor.run("/usr/bin/du", args: ["-sh", cellar]), result.isSuccess else {
            throw BrewServiceError.commandFailed("Could not calculate Homebrew disk usage")
        }

        let size = result.stdout
            .split(separator: "\t").first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !size.isEmpty else { throw BrewServiceError.commandFailed("Homebrew disk usage was empty") }
        return String(size)
    }
}
