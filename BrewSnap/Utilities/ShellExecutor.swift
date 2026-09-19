// ShellExecutor.swift
// BrewSnap — Wrapper for Process (safely runs brew/git).

import Foundation

enum ShellError: LocalizedError, Sendable {
    case launchFailed(String)
    case nonZeroExit(command: String, exitCode: Int32, stderr: String)
    case outputDecodingFailed

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "Failed to launch process: \(msg)"
        case .nonZeroExit(let cmd, let code, let stderr): return "`\(cmd)` exited with \(code): \(stderr)"
        case .outputDecodingFailed: return "Failed to decode process output"
        }
    }
}

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    var isSuccess: Bool { exitCode == 0 }
}

/// Lightweight wrapper around Foundation.Process for running brew/git commands.
enum ShellExecutor {
    /// Returns whether a usable Git executable is available on this Mac.
    static func isGitInstalled() async -> Bool {
        guard let result = try? await run("/usr/bin/which", args: ["git"]) else {
            return false
        }
        return result.isSuccess && !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Resolves the brew binary without depending on PATH (critical with sandbox)
    static func brewExecutable() -> String {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew",
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
        return "brew" // fallback (will depend on PATH via zsh -l)
    }
    @discardableResult
    static func run(
        _ executable: String,
        args: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil
    ) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args
                if let env = environment {
                    process.environment = env
                }
                if let wd = workingDirectory {
                    process.currentDirectoryURL = wd
                }

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: ShellError.launchFailed(error.localizedDescription))
                    return
                }

                // Avoid pipe deadlock for large output (e.g. `brew info --json=v2 --installed` ~300KB):
                // read stdout/stderr concurrently while the process runs,
                // then wait for exit. Waiting before reading deadlocks when the pipe buffer fills.
                final class Box: @unchecked Sendable { var data = Data() }
                let outBox = Box()
                let errBox = Box()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    errBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.wait()
                process.waitUntilExit()

                let stdout = String(data: outBox.data, encoding: .utf8) ?? ""
                let stderr = String(data: errBox.data, encoding: .utf8) ?? ""
                let result = ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                continuation.resume(returning: result)
            }
        }
    }

    /// Convenience: run via /bin/zsh -c "command" (respects PATH, brew shims)
    @discardableResult
    static func runShell(_ command: String, workingDirectory: URL? = nil) async throws -> ShellResult {
        try await run("/bin/zsh", args: ["-l", "-c", command], workingDirectory: workingDirectory)
    }

    /// Run and throw if exitCode != 0
    @discardableResult
    static func runOrThrow(_ executable: String, args: [String] = [], workingDirectory: URL? = nil) async throws -> String {
        let result = try await run(executable, args: args, workingDirectory: workingDirectory)
        guard result.isSuccess else {
            throw ShellError.nonZeroExit(command: ([executable] + args).joined(separator: " "), exitCode: result.exitCode, stderr: result.stderr)
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
