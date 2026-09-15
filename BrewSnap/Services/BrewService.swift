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

    // MARK: - Brew binary

    private func brew() -> String { ShellExecutor.brewExecutable() }

    // MARK: - Formulae

    private func fetchFormulae() async throws -> [(name: String, version: String)] {
        let brew = brew()
        // Intenta directo con binario absoluto, fallback a shell si falla
        var result: ShellResult
        do {
            result = try await ShellExecutor.run(brew, args: ["list", "--formula", "--versions"])
        } catch {
            result = try await ShellExecutor.runShell("\(brew) list --formula --versions")
        }
        if !result.isSuccess && !result.stderr.isEmpty {
            // Log para diagnóstico en Console.app
            print("[BrewSnap] fetchFormulae stderr: \(result.stderr) (brew=\(brew))")
        }
        guard !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Fallback shell con PATH completo
            let fallback = try? await ShellExecutor.runShell("brew list --formula --versions 2>&1; echo __EXIT:$?")
            if let fb = fallback, fb.stdout.contains("__EXIT:0") {
                return VersionHelper.parseBrewVersions(output: fb.stdout)
            }
            return []
        }
        return VersionHelper.parseBrewVersions(output: result.stdout)
    }

    private func fetchCasks() async throws -> [(name: String, version: String)] {
        let brew = brew()
        // casks usa --cask en brew 4.x, compat con --casks
        let argsList = [["list", "--cask", "--versions"], ["list", "--casks", "--versions"]]
        for args in argsList {
            if let r = try? await ShellExecutor.run(brew, args: args), r.isSuccess && !r.stdout.isEmpty {
                return VersionHelper.parseBrewVersions(output: r.stdout)
            }
        }
        let result = try? await ShellExecutor.runShell("\(brew) list --cask --versions 2>/dev/null || \(brew) list --casks --versions 2>/dev/null || brew list --cask --versions 2>/dev/null || true")
        return VersionHelper.parseBrewVersions(output: result?.stdout ?? "")
    }

    private func fetchTaps() async throws -> [BrewTap] {
        let brew = brew()
        var names: [String] = []
        if let r = try? await ShellExecutor.run(brew, args: ["tap"]), r.isSuccess {
            names = r.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else if let r2 = try? await ShellExecutor.runShell("\(brew) tap 2>/dev/null || brew tap 2>/dev/null || true") {
            names = r2.stdout.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        if names.isEmpty {
            print("[BrewSnap] fetchTaps: 0 taps (brew=\(brew))")
            return []
        }
        var detailed: [BrewTap] = []
        for name in names {
            var remote: String? = nil
            if let r = try? await ShellExecutor.run(brew, args: ["tap-info", "--json", name]),
               let data = r.stdout.data(using: .utf8),
               let arr = try? JSONDecoder().decode([[String: AnyCodable]].self, from: data),
               let v = arr.first?["remote"]?.value as? String {
                remote = v
            } else if let r2 = try? await ShellExecutor.runShell("\(brew) tap-info --json \(name) 2>/dev/null"),
                      let data = r2.stdout.data(using: .utf8),
                      let arr = try? JSONDecoder().decode([[String: AnyCodable]].self, from: data) {
                remote = arr.first?["remote"]?.value as? String
            }
            detailed.append(BrewTap(name: name, remote: remote, trusted: true))
        }
        return detailed
    }

    private func fetchServices() async throws -> [BrewService] {
        let brew = brew()
        var stdout: String? = nil
        if let r = try? await ShellExecutor.run(brew, args: ["services", "list", "--json"]) { stdout = r.stdout }
        else if let r2 = try? await ShellExecutor.runShell("\(brew) services list --json 2>/dev/null || brew services list --json 2>/dev/null || true") { stdout = r2.stdout }
        guard let s = stdout, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return VersionHelper.parseBrewServices(jsonString: s)
    }

    private func fetchPinned() async throws -> Set<String> {
        let brew = brew()
        var out = ""
        if let r = try? await ShellExecutor.run(brew, args: ["pin"]) { out = r.stdout }
        else if let r2 = try? await ShellExecutor.runShell("\(brew) pin 2>/dev/null || brew pin 2>/dev/null || true") { out = r2.stdout }
        let pins = out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Set(pins)
    }

    private func fetchDiskUsage() async throws -> String? {
        let brew = brew()
        // Obtiene cellar path vía brew --cellar y mide
        var cellar = ""
        if let r = try? await ShellExecutor.run(brew, args: ["--cellar"]) { cellar = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
        else if let r2 = try? await ShellExecutor.runShell("\(brew) --cellar 2>/dev/null || brew --cellar 2>/dev/null || echo /opt/homebrew/Cellar") { cellar = r2.stdout.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n").first ?? "" }
        guard !cellar.isEmpty else { return nil }
        let du = try? await ShellExecutor.run("/usr/bin/du", args: ["-sh", cellar])
        let size = du?.stdout.split(separator: "\t").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? du?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return size.isEmpty ? nil : String(size)
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
