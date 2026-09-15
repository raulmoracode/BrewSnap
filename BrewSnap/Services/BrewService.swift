import Foundation

enum BrewServiceError: LocalizedError {
    case brewNotFound
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .brewNotFound: return "Homebrew no está instalado o no está en el PATH"
        case .commandFailed(let msg): return msg
        }
    }
}

final class HomebrewService: Sendable {
    // MARK: - Scan

    func scan() async throws -> BrewSnapshot {
        async let formulaeTask = fetchFormulae()
        async let casksTask = fetchCasks()
        async let tapsTask = fetchTaps()
        async let servicesTask = fetchServices()
        async let pinnedTask = fetchPinned()
        async let diskUsageTask = fetchDiskUsage()
        async let sysInfoTask = VersionHelper.systemInfo()

        let (formulaeRaw, casksRaw, taps, services, pinned, diskUsage, sysInfo) = await (
            (try? formulaeTask) ?? [],
            (try? casksTask) ?? [],
            (try? tapsTask) ?? [],
            (try? servicesTask) ?? [],
            (try? pinnedTask) ?? Set<String>(),
            (try? diskUsageTask) ?? nil,
            sysInfoTask
        )

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
            hostname: sysInfo.hostname,
            macOS: sysInfo.macOS,
            arch: sysInfo.arch,
            homebrew: sysInfo.homebrew,
            formulae: formulae.sorted { $0.name < $1.name },
            casks: casks.sorted { $0.name < $1.name },
            taps: taps.sorted { $0.name < $1.name },
            services: services,
            totalDiskUsage: diskUsage
        )
    }

    // MARK: - Formulae

    private func fetchFormulae() async throws -> [(name: String, version: String)] {
        let result = try await ShellExecutor.runShell("brew list --formula --versions")
        guard result.isSuccess else { throw BrewServiceError.commandFailed(result.stderr) }
        return VersionHelper.parseBrewVersions(output: result.stdout)
    }

    private func fetchCasks() async throws -> [(name: String, version: String)] {
        let result = try await ShellExecutor.runShell("brew list --cask --versions 2>/dev/null || brew list --casks --versions 2>/dev/null || true")
        return VersionHelper.parseBrewVersions(output: result.stdout)
    }

    private func fetchTaps() async throws -> [BrewTap] {
        // Prefer JSON for remote info
        if let jsonData = (try? await ShellExecutor.runShell("brew tap-info --json").stdout.data(using: .utf8)),
           let taps = try? JSONDecoder().decode([[String: String]].self, from: jsonData) {
            // fallback handled below
            _ = taps
        }
        // Simple text fallback
        let result = try await ShellExecutor.runShell("brew tap")
        let names = result.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Try json details per tap
        var detailed: [BrewTap] = []
        for name in names {
            let infoResult = try? await ShellExecutor.runShell("brew tap-info --json \(name) 2>/dev/null")
            if let data = infoResult?.stdout.data(using: .utf8),
               let arr = try? JSONDecoder().decode([[String: AnyCodable]].self, from: data),
               let first = arr.first,
               let remote = first["remote"]?.value as? String {
                detailed.append(BrewTap(name: name, remote: remote, trusted: true))
            } else {
                detailed.append(BrewTap(name: name, remote: nil, trusted: true))
            }
        }
        return detailed
    }

    private func fetchServices() async throws -> [BrewService] {
        let result = try? await ShellExecutor.runShell("brew services list --json 2>/dev/null")
        guard let stdout = result?.stdout, !stdout.isEmpty else { return [] }
        return VersionHelper.parseBrewServices(jsonString: stdout)
    }

    private func fetchPinned() async throws -> Set<String> {
        let result = try? await ShellExecutor.runShell("brew pin 2>/dev/null || true")
        let pins = result?.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } ?? []
        return Set(pins)
    }

    private func fetchDiskUsage() async throws -> String? {
        let result = try? await ShellExecutor.runShell("du -sh $(brew --cellar 2>/dev/null) 2>/dev/null | cut -f1 || echo ''")
        let trimmed = result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

// Helper to decode heterogeneous tap-info JSON
private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = d }
        else { value = "" }
    }
}
