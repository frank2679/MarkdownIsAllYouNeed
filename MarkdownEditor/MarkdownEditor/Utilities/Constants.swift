import Foundation

enum AppConstants {
    // MARK: - GitHub OAuth
    // TODO: Replace with your own GitHub OAuth App credentials
    static let githubClientID = "YOUR_GITHUB_CLIENT_ID"
    static let githubClientSecret = "YOUR_GITHUB_CLIENT_SECRET"
    static let githubCallbackURL = "markdowneditor://oauth/callback"
    static let githubScopes = "repo,user"

    // MARK: - GitHub API
    static let githubAPIBase = "https://api.github.com"

    // MARK: - Keychain Keys
    static let keychainGitHubToken = "com.frank2679.markdowneditor.github-token"

    // MARK: - UserDefaults Keys
    static let lastEditedFileKey = "lastEditedFilePath"
    static let imageDirectoryKey = "imageDirectory"

    // MARK: - Defaults
    static let defaultImageDirectory = "assets"
}
