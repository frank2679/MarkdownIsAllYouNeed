import Foundation

protocol RemoteProvider {
    var name: String { get }
    func fetchUserProfile() async throws -> UserProfile
    func fetchRepos(page: Int) async throws -> [Repository]
}
