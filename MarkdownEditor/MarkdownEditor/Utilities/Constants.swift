import Foundation

enum AppConstants {
    // MARK: - GitHub OAuth (loaded from xcconfig via Info.plist)
    static let githubClientID: String = {
        Bundle.main.infoDictionary?["GitHubClientID"] as? String ?? ""
    }()
    static let githubClientSecret: String = {
        Bundle.main.infoDictionary?["GitHubClientSecret"] as? String ?? ""
    }()
    static let githubCallbackURL = "markdowneditor://oauth/callback"
    static let githubScopes = "repo,user,gist"

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
