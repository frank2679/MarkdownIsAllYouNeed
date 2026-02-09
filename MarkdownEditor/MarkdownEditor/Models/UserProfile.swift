import Foundation

struct UserProfile: Codable, Identifiable {
    let id: Int
    let login: String
    let avatarURL: String
    let name: String?
    let bio: String?
    let publicRepos: Int
    let privateRepos: Int

    enum CodingKeys: String, CodingKey {
        case id, login, name, bio
        case avatarURL = "avatar_url"
        case publicRepos = "public_repos"
        case privateRepos = "total_private_repos"
    }
}
