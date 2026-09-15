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
            let snap = try await SnapshotService.generate()
            snapshot = snap
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
