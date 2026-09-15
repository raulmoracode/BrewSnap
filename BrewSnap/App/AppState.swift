import Foundation
import Observation

@Observable
final class AppState {
    var snapshot: BrewSnapshot?
    var isScanning = false
    var lastError: String?
    var syncStatus: SyncStatus = .idle
    var selectedProfile: BrewProfile = .default
    var profiles: [BrewProfile] = [.default, .work, .personal]

    // Settings (persisted via UserDefaults)
    var githubToken: String {
        get { (try? KeychainService.load()) ?? "" }
        set { try? KeychainService.save(token: newValue) }
    }
    var repoName: String {
        get { UserDefaults.standard.string(forKey: "repoName") ?? "brewsnap" }
        set { UserDefaults.standard.set(newValue, forKey: "repoName") }
    }
    var repoOwner: String {
        get { UserDefaults.standard.string(forKey: "repoOwner") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "repoOwner") }
    }

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case outOfSync
        case error(String)
    }

    func scan() async {
        isScanning = true
        defer { isScanning = false }
        do {
            // Timeout global de 30s para no quedar en "Escaneando…" infinito
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
