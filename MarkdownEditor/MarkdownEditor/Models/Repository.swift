import Foundation

struct Repository: Codable, Identifiable {
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
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("repos/\(fullName)")
    }
}
