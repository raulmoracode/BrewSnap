// AppState.swift
// BrewSnap — Global observable state (snapshot, profiles, settings).

import Foundation
import Observation
import AppKit

@Observable
final class AppState {

    // MARK: - Properties

    var snapshot: BrewSnapshot?
    var isScanning = false
    var lastError: String?
    var syncStatus: SyncStatus = .idle
    var selectedProfile: BrewProfile = .default
    var profiles: [BrewProfile] = [.default, .work, .personal]

    /// Tab requested from the menu bar (rawValue). Consumed by MainView.
    var requestedTab: String? = nil

    /// Weak reference to the main window, registered by MainView via WindowAccessor.
    weak var mainWindow: NSWindow? = nil

    private let userDefaults: UserDefaults
    private let keychain: KeychainService.Type
    private var cachedToken: String?

    // MARK: - Initialization

    /// - Parameters:
    ///   - userDefaults: Almacenamiento para repoName/repoOwner (inyectado para testabilidad).
    ///   - keychain: Servicio Keychain (inyectado).
    init(userDefaults: UserDefaults = .standard, keychain: KeychainService.Type = KeychainService.self) {
        self.userDefaults = userDefaults
        self.keychain = keychain
    }

    // MARK: - Settings (persisted)

    /// Token GitHub guardado en Keychain. Se lee una sola vez por lanzamiento
    /// (caché en memoria) para evitar que el sistema pregunte por cada uso.
    var githubToken: String {
        get {
            if let cachedToken { return cachedToken }
            let loaded = (try? keychain.load()) ?? ""
            if !loaded.isEmpty { cachedToken = loaded }
            return loaded
        }
        set {
            try? keychain.save(token: newValue)
            cachedToken = newValue
        }
    }

    /// Borra el token del Keychain y la caché en memoria.
    func clearGithubToken() {
        try? keychain.delete()
        cachedToken = nil
    }

    var repoName: String {
        get { userDefaults.string(forKey: "repoName") ?? "brewsnap" }
        set { userDefaults.set(newValue, forKey: "repoName") }
    }

    var repoOwner: String {
        get { userDefaults.string(forKey: "repoOwner") ?? "" }
        set { userDefaults.set(newValue, forKey: "repoOwner") }
    }

    /// Flag sin acceso a Keychain: evita el prompt del sistema al pintar vistas.
    var hasGithubToken: Bool {
        get { userDefaults.bool(forKey: "hasGithubToken") }
        set { userDefaults.set(newValue, forKey: "hasGithubToken") }
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
            if !snap.isComplete {
                lastError = "Snapshot incomplete. Nothing will be uploaded until Homebrew can be scanned completely."
            } else if snap.formulae.isEmpty && snap.casks.isEmpty {
                lastError = "Empty snapshot - check that brew works (brew list --formula --versions)"
            }
        } catch is CancellationError {
            lastError = "Timeout scanning Homebrew (>30s) - try again"
        } catch {
            lastError = error.localizedDescription
        }
    }
}
