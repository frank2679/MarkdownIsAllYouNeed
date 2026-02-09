import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: UserProfile?
    @Published var lastEditedFilePath: String?

    let authService = AuthService()

    init() {
        if let token = authService.getAccessToken() {
            isAuthenticated = true
            Task { await loadUserProfile(token: token) }
        }
        lastEditedFilePath = UserDefaults.standard.string(forKey: "lastEditedFilePath")
    }

    func login() async {
        do {
            try await authService.login()
            isAuthenticated = true
            if let token = authService.getAccessToken() {
                await loadUserProfile(token: token)
            }
        } catch {
            print("Login failed: \(error)")
        }
    }

    func logout() {
        authService.logout()
        isAuthenticated = false
        currentUser = nil
    }

    func saveLastEditedFile(_ path: String) {
        lastEditedFilePath = path
        UserDefaults.standard.set(path, forKey: "lastEditedFilePath")
    }

    private func loadUserProfile(token: String) async {
        let provider = GitHubProvider(token: token)
        do {
            currentUser = try await provider.fetchUserProfile()
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}
