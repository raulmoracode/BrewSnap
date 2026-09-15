import Foundation

enum VersionHelper {
    /// Parse `brew list --formulae --versions` output like:
    /// "git 2.47.0\npython@3.13 3.13.7\nnode 22.0.0 20.0.0"
    /// Returns array of (name, version) taking the first version token.
    static func parseBrewVersions(output: String) -> [(name: String, version: String)] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line -> (String, String)? in
                let parts = line.split(separator: " ").map(String.init)
                guard parts.count >= 2 else { return nil }
                return (parts[0], parts[1])
            }
    }

    static func parseBrewTapInfo(jsonData: Data) -> [BrewTap] {
        // `brew tap-info --json` returns [{ "name": "...", "remote": "..." }]
        struct TapInfo: Decodable {
            let name: String
            let remote: String?
            let installed: Bool?
        }
        guard let infos = try? JSONDecoder().decode([TapInfo].self, from: jsonData) else {
            return []
        }
        return infos.map { BrewTap(name: $0.name, remote: $0.remote, trusted: true) }
    }

    static func parseBrewServices(jsonString: String) -> [BrewService] {
        struct ServiceEntry: Decodable {
            let name: String
            let status: String?
            let file: String?
        }
        guard let data = jsonString.data(using: .utf8),
              let entries = try? JSONDecoder().decode([ServiceEntry].self, from: data) else {
            return []
        }
        return entries.map { e in
            let status: BrewService.ServiceStatus
            switch e.status?.lowercased() {
            case "started": status = .started
            case "stopped": status = .stopped
            case "scheduled": status = .scheduled
            case "error": status = .error
            default: status = .unknown
            }
            return BrewService(name: e.name, status: status, restart: status == .started)
        }
    }

    static func systemInfo() async -> (hostname: String, macOS: String, arch: String, homebrew: String) {
        let hostname = (try? await ShellExecutor.runOrThrow("/bin/hostname", args: [])) ?? Host.current().localizedName ?? "unknown"
        let macOS = (try? await ShellExecutor.runOrThrow("/usr/bin/sw_vers", args: ["-productVersion"])) ?? "15.0"
        let arch = (try? await ShellExecutor.runOrThrow("/usr/bin/uname", args: ["-m"])) ?? "arm64"
        let brew = ShellExecutor.brewExecutable()
        var brewVersionRaw = ""
        if let r = try? await ShellExecutor.run(brew, args: ["--version"]) { brewVersionRaw = r.stdout }
        else if let r2 = try? await ShellExecutor.runShell("\(brew) --version 2>/dev/null || brew --version 2>/dev/null || true") { brewVersionRaw = r2.stdout }
        let homebrew = brewVersionRaw.split(separator: "\n").first?.split(separator: " ").last.map(String.init) ?? "unknown"
        return (hostname.trimmingCharacters(in: .whitespacesAndNewlines),
                macOS.trimmingCharacters(in: .whitespacesAndNewlines),
                arch.trimmingCharacters(in: .whitespacesAndNewlines),
                homebrew.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
