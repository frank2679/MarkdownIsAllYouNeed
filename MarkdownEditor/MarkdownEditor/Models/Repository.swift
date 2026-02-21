import Foundation

struct Repository: Codable, Identifiable, Hashable {
    static func == (lhs: Repository, rhs: Repository) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let isPrivate: Bool
    let description: String?
    let cloneURL: String
    let defaultBranch: String
    let stargazersCount: Int
    let updatedAt: String
    let fork: Bool
    /// Overrides `localPath` for testing; not persisted (not in CodingKeys).
    var customLocalPath: URL? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, fork
        case fullName = "full_name"
        case isPrivate = "private"
        case cloneURL = "clone_url"
        case defaultBranch = "default_branch"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
    }

    struct Owner: Codable {
        let login: String
        let avatarURL: String

        enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    var isClonedLocally: Bool {
        FileManager.default.fileExists(atPath: localPath.path)
    }

    var localPath: URL {
        if let customPath = customLocalPath { return customPath }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("repos/\(fullName)")
    }
}
