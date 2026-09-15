// AppState.swift
// BrewSnap — Estado global observable (snapshot, perfiles, settings).

import Foundation
import Observation

@Observable
final class AppState {

    // MARK: - Properties

    var snapshot: BrewSnapshot?
    var isScanning = false
    var lastError: String?
    var syncStatus: SyncStatus = .idle
    var selectedProfile: BrewProfile = .default
    var profiles: [BrewProfile] = [.default, .work, .personal]

    private let userDefaults: UserDefaults
    private let keychain: KeychainService.Type

    // MARK: - Initialization

    /// - Parameters:
    ///   - userDefaults: Almacenamiento para repoName/repoOwner (inyectado para testabilidad).
    ///   - keychain: Servicio Keychain (inyectado).
    init(userDefaults: UserDefaults = .standard, keychain: KeychainService.Type = KeychainService.self) {
        self.userDefaults = userDefaults
        self.keychain = keychain
    }

    // MARK: - Settings (persisted)

    /// Token GitHub guardado en Keychain (inyectado).
    var githubToken: String {
        get { (try? keychain.load()) ?? "" }
        set { try? keychain.save(token: newValue) }
    }

    var repoName: String {
        get { userDefaults.string(forKey: "repoName") ?? "brewsnap" }
        set { userDefaults.set(newValue, forKey: "repoName") }
    }

    var repoOwner: String {
        get { userDefaults.string(forKey: "repoOwner") ?? "" }
        set { userDefaults.set(newValue, forKey: "repoOwner") }
    }

    // MARK: - Types

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case outOfSync
        case error(String)
    }

    // MARK: - Public Methods

    /// Escanea Homebrew con timeout global de 30s.
    func scan() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let snap = try await withThrowingTaskGroup(of: BrewSnapshot.self) { group in
                group.addTask { try await SnapshotService.generate() }
                group.addTask {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    throw CancellationError()
                }
                guard let result = try await group.next() else { throw CancellationError() }
                group.cancelAll()
                return result
            }
            snapshot = snap
            lastError = nil
            if snap.formulae.isEmpty && snap.casks.isEmpty {
                lastError = "Snapshot vacío — verifica que brew funciona (brew list --formula --versions)"
            }
        } catch is CancellationError {
            lastError = "Timeout escaneando Homebrew (>30s) — reintenta"
        } catch {
            lastError = error.localizedDescription
        }
    }
}
