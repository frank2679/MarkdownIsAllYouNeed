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

    private func request(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: AppConstants.githubAPIBase + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

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
