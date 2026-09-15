import Foundation

enum GitHubError: LocalizedError {
    case invalidToken
    case repoExists
    case network(String)
    case api(String, Int)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "Token de GitHub inválido o sin permisos"
        case .repoExists: return "El repositorio ya existe"
        case .network(let msg): return "Error de red: \(msg)"
        case .api(let msg, let code): return "GitHub API error (\(code)): \(msg)"
        case .encodingFailed: return "Failed to encode request"
        }
    }
}

final class GitHubService: Sendable {
    private let token: String
    private let baseURL = URL(string: "https://api.github.com")!

    init(token: String) {
        self.token = token
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return req
    }

    func validateToken() async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request(path: "/user"))
        guard let http = response as? HTTPURLResponse else { throw GitHubError.network("No HTTP response") }
        guard http.statusCode == 200 else { throw GitHubError.api(String(data: data, encoding: .utf8) ?? "", http.statusCode) }
        struct User: Decodable { let login: String }
        let user = try JSONDecoder().decode(User.self, from: data)
        return user.login
    }

    func createPrivateRepo(name: String = "brewsnap", description: String = "BrewSnap — Homebrew snapshot backups") async throws {
        let body: [String: Any] = ["name": name, "private": true, "description": description, "auto_init": true]
        let data = try JSONSerialization.data(withJSONObject: body)
        let (respData, response) = try await URLSession.shared.data(for: request(path: "/user/repos", method: "POST", body: data))
        guard let http = response as? HTTPURLResponse else { throw GitHubError.network("No HTTP response") }
        if http.statusCode == 422 { throw GitHubError.repoExists }
        guard (200...299).contains(http.statusCode) else {
            throw GitHubError.api(String(data: respData, encoding: .utf8) ?? "", http.statusCode)
        }
    }

    /// Fetch file content via GET /repos/{owner}/{repo}/contents/{path}
    func fetchFile(owner: String, repo: String, path: String) async throws -> (sha: String, content: String) {
        let (data, response) = try await URLSession.shared.data(for: request(path: "/repos/\(owner)/\(repo)/contents/\(path)"))
        guard let http = response as? HTTPURLResponse else { throw GitHubError.network("No HTTP response") }
        guard http.statusCode == 200 else { throw GitHubError.api(String(data: data, encoding: .utf8) ?? "", http.statusCode) }
        struct Content: Decodable { let sha: String; let content: String; let encoding: String }
        let decoded = try JSONDecoder().decode(Content.self, from: data)
        let clean = decoded.content.replacingOccurrences(of: "\n", with: "")
        guard let decodedData = Data(base64Encoded: clean), let str = String(data: decodedData, encoding: .utf8) else {
            throw GitHubError.encodingFailed
        }
        return (decoded.sha, str)
    }

    /// PUT /repos/{owner}/{repo}/contents/{path}
    @discardableResult
    func putFile(owner: String, repo: String, path: String, content: String, message: String, sha: String? = nil) async throws -> String {
        let base64 = Data(content.utf8).base64EncodedString()
        var body: [String: Any] = ["message": message, "content": base64]
        if let sha { body["sha"] = sha }
        let data = try JSONSerialization.data(withJSONObject: body)
        let (respData, response) = try await URLSession.shared.data(for: request(path: "/repos/\(owner)/\(repo)/contents/\(path)", method: "PUT", body: data))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GitHubError.api(String(data: respData, encoding: .utf8) ?? "", code)
        }
        struct PutResponse: Decodable { struct Content: Decodable { let sha: String }; let content: Content? }
        if let decoded = try? JSONDecoder().decode(PutResponse.self, from: respData), let sha = decoded.content?.sha {
            return sha
        }
        return ""
    }

    func commitSnapshot(owner: String, repo: String, snapshot: BrewSnapshot, profile: String = "brewsnap") async throws {
        let json = try snapshot.toPrettyJSON()
        let path = "\(profile).json"
        var existingSHA: String? = nil
        if let existing = try? await fetchFile(owner: owner, repo: repo, path: path) {
            existingSHA = existing.sha
            if existing.content == json {
                // No changes
                return
            }
        }
        let message = "snapshot: \(snapshot.formulaeCount) formulae, \(snapshot.casksCount) casks — \(ISO8601DateFormatter().string(from: snapshot.createdAt))"
        try await putFile(owner: owner, repo: repo, path: path, content: json, message: message, sha: existingSHA)
    }
}
