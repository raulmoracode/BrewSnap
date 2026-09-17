// GitHubService.swift
// BrewSnap — GitHub API v3 client for creating repos and syncing snapshots.

import Foundation

// MARK: - Error

/// GitHubService errors.
enum GitHubError: LocalizedError {
    case invalidToken
    case repoExists
    case network(String)
    case api(String, Int)
    case encodingFailed
    case incompleteSnapshot([String])

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid GitHub token or insufficient permissions"
        case .repoExists:
            return "Repository already exists"
        case .network(let message):
            return "Network error: \(message)"
        case .api(let message, let code):
            return "GitHub API error (\(code)): \(message)"
        case .encodingFailed:
            return "Failed to encode request"
        case .incompleteSnapshot(let warnings):
            return "Snapshot is incomplete and was not uploaded: \(warnings.joined(separator: "; "))"
        }
    }
}

// MARK: - Model

private struct CreateRepoRequest: Codable {
    let name: String
    let isPrivate: Bool
    let description: String
    let autoInit: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isPrivate = "private"
        case description
        case autoInit = "auto_init"
    }
}

private struct PutFileRequest: Codable {
    let message: String
    let content: String
    let sha: String?
}

// MARK: - Service

/// Cliente para GitHub API v3 (URLSession directo, sin Octokit).
final class GitHubService: Sendable {

    // MARK: - Properties

    private let token: String
    private let baseURL: URL = {
        guard let url = URL(string: "https://api.github.com") else {
            fatalError("Invalid GitHub base URL")
        }
        return url
    }()

    // MARK: - Initialization

    init(token: String) {
        self.token = token
    }

    // MARK: - Private Helpers

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    // MARK: - Public API

    /// Valida el token y devuelve el login del usuario.
    func validateToken() async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: makeRequest(path: "/user"))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.network("No HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            throw GitHubError.api(String(data: data, encoding: .utf8) ?? "", httpResponse.statusCode)
        }
        struct User: Decodable { let login: String }
        let user = try JSONDecoder().decode(User.self, from: data)
        return user.login
    }

    /// Elimina un repositorio.
    func deleteRepo(owner: String, repo: String) async throws {
        let (responseData, response) = try await URLSession.shared.data(for: makeRequest(path: "/repos/\(owner)/\(repo)", method: "DELETE"))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.network("No HTTP response")
        }
        guard (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 204 else {
            throw GitHubError.api(String(data: responseData, encoding: .utf8) ?? "", httpResponse.statusCode)
        }
    }

    /// Crea un repositorio privado.
    func createPrivateRepo(name: String = "brewsnap", description: String = "BrewSnap - Homebrew snapshot backups") async throws {
        let payload = CreateRepoRequest(name: name, isPrivate: true, description: description, autoInit: true)
        let data = try JSONEncoder().encode(payload)
        let (responseData, response) = try await URLSession.shared.data(for: makeRequest(path: "/user/repos", method: "POST", body: data))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.network("No HTTP response")
        }
        if httpResponse.statusCode == 422 { throw GitHubError.repoExists }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.api(String(data: responseData, encoding: .utf8) ?? "", httpResponse.statusCode)
        }
    }

    /// Devuelve los nombres de los repositorios que el usuario posee.
    func listRepos() async throws -> [String] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/user/repos"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "100"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "affiliation", value: "owner"),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.network("No HTTP response") }
        guard http.statusCode == 200 else {
            throw GitHubError.api(String(data: data, encoding: .utf8) ?? "", http.statusCode)
        }
        struct RepoNet: Decodable { let name: String }
        return try JSONDecoder().decode([RepoNet].self, from: data).map(\.name)
    }

    /// Obtiene un archivo del repo (devuelve SHA y contenido decodificado).
    func fetchFile(owner: String, repo: String, path: String) async throws -> (sha: String, content: String) {
        let (data, response) = try await URLSession.shared.data(for: makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)"))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.network("No HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            throw GitHubError.api(String(data: data, encoding: .utf8) ?? "", httpResponse.statusCode)
        }
        struct Content: Decodable { let sha: String; let content: String; let encoding: String }
        let decoded = try JSONDecoder().decode(Content.self, from: data)
        let clean = decoded.content.replacingOccurrences(of: "\n", with: "")
        guard let decodedData = Data(base64Encoded: clean),
              let string = String(data: decodedData, encoding: .utf8) else {
            throw GitHubError.encodingFailed
        }
        return (decoded.sha, string)
    }

    /// Creates or updates a file via PUT /contents.
    @discardableResult
    func putFile(owner: String, repo: String, path: String, content: String, message: String, sha: String? = nil) async throws -> String {
        let base64 = Data(content.utf8).base64EncodedString()
        let payload = PutFileRequest(message: message, content: base64, sha: sha)
        let data = try JSONEncoder().encode(payload)
        let (responseData, response) = try await URLSession.shared.data(for: makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)", method: "PUT", body: data))
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GitHubError.api(String(data: responseData, encoding: .utf8) ?? "", code)
        }
        struct PutResponse: Decodable { struct Content: Decodable { let sha: String }; let content: Content? }
        if let decoded = try? JSONDecoder().decode(PutResponse.self, from: responseData),
           let newSHA = decoded.content?.sha {
            return newSHA
        }
        return ""
    }

    /// Sube un snapshot como `{profile}.json` si hay cambios.
    func commitSnapshot(owner: String, repo: String, snapshot: BrewSnapshot, profile: String = "brewsnap") async throws {
        guard snapshot.isComplete else {
            throw GitHubError.incompleteSnapshot(snapshot.warnings)
        }
        let json = try snapshot.toPrettyJSON()
        let path = "\(profile).json"
        var existingSHA: String?

        if let existing = try? await fetchFile(owner: owner, repo: repo, path: path) {
            existingSHA = existing.sha
            guard existing.content != json else { return } // Already up to date
        }

        let message = "snapshot: \(snapshot.formulaeCount) formulae, \(snapshot.casksCount) casks - \(ISO8601DateFormatter().string(from: snapshot.createdAt))"
        try await putFile(owner: owner, repo: repo, path: path, content: json, message: message, sha: existingSHA)
    }
}
