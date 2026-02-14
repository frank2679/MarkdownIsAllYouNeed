import Foundation

final class GitHubProvider: RemoteProvider {
    let name = "GitHub"
    private let token: String

    init(token: String) {
        self.token = token
    }

    func fetchUserProfile() async throws -> UserProfile {
        let data = try await request(path: "/user")
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func fetchRepos(page: Int = 1) async throws -> [Repository] {
        let data = try await request(
            path: "/user/repos",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "30"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
            ]
        )
        return try JSONDecoder().decode([Repository].self, from: data)
    }

    // MARK: - Git Data API

    /// GET /repos/{owner}/{repo}/git/ref/heads/{branch}
    func getRef(owner: String, repo: String, branch: String) async throws -> GitRefResponse {
        let data = try await request(path: "/repos/\(owner)/\(repo)/git/ref/heads/\(branch)")
        return try JSONDecoder().decode(GitRefResponse.self, from: data)
    }

    /// GET /repos/{owner}/{repo}/git/commits/{sha}
    func getCommit(owner: String, repo: String, sha: String) async throws -> GitCommitDetail {
        let data = try await request(path: "/repos/\(owner)/\(repo)/git/commits/\(sha)")
        return try JSONDecoder().decode(GitCommitDetail.self, from: data)
    }

    /// GET /repos/{owner}/{repo}/git/trees/{sha}?recursive=1
    func getTree(owner: String, repo: String, treeSHA: String, recursive: Bool = true) async throws -> GitTreeResponse {
        var queryItems: [URLQueryItem] = []
        if recursive {
            queryItems.append(URLQueryItem(name: "recursive", value: "1"))
        }
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/git/trees/\(treeSHA)",
            queryItems: queryItems
        )
        return try JSONDecoder().decode(GitTreeResponse.self, from: data)
    }

    /// GET /repos/{owner}/{repo}/contents/{path}?ref={ref} (raw content)
    func getFileContent(owner: String, repo: String, path: String, ref: String) async throws -> Data {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/contents/\(encodedPath)",
            queryItems: [URLQueryItem(name: "ref", value: ref)],
            accept: "application/vnd.github.raw+json"
        )
        return data
    }

    /// POST /repos/{owner}/{repo}/git/blobs
    func createBlob(owner: String, repo: String, content: String, encoding: String = "base64") async throws -> GitBlobResponse {
        let body = CreateBlobRequest(content: content, encoding: encoding)
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/git/blobs",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
        return try JSONDecoder().decode(GitBlobResponse.self, from: data)
    }

    /// POST /repos/{owner}/{repo}/git/trees
    func createTree(owner: String, repo: String, baseTree: String, entries: [CreateTreeEntry]) async throws -> GitTreeResponse {
        let body = CreateTreeRequest(baseTree: baseTree, tree: entries)
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/git/trees",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
        return try JSONDecoder().decode(GitTreeResponse.self, from: data)
    }

    /// POST /repos/{owner}/{repo}/git/commits
    func createCommit(owner: String, repo: String, message: String, tree: String, parents: [String]) async throws -> GitCommitResponse {
        let body = CreateCommitRequest(message: message, tree: tree, parents: parents)
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/git/commits",
            method: "POST",
            body: try JSONEncoder().encode(body)
        )
        return try JSONDecoder().decode(GitCommitResponse.self, from: data)
    }

    /// PATCH /repos/{owner}/{repo}/git/refs/heads/{branch}
    func updateRef(owner: String, repo: String, branch: String, sha: String, force: Bool = false) async throws -> GitRefResponse {
        let body = UpdateRefRequest(sha: sha, force: force)
        let data = try await request(
            path: "/repos/\(owner)/\(repo)/git/refs/heads/\(branch)",
            method: "PATCH",
            body: try JSONEncoder().encode(body)
        )
        return try JSONDecoder().decode(GitRefResponse.self, from: data)
    }

    // MARK: - HTTP Request

    private func request(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        accept: String = "application/vnd.github+json"
    ) async throws -> Data {
        var components = URLComponents(string: AppConstants.githubAPIBase + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

enum GitHubError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from GitHub"
        case .httpError(let code): return "GitHub API error (HTTP \(code))"
        }
    }
}
