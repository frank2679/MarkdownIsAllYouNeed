class AppConstants {
  // GitHub OAuth
  static const githubClientID = 'YOUR_GITHUB_CLIENT_ID';
  static const githubClientSecret = 'YOUR_GITHUB_CLIENT_SECRET';
  static const githubCallbackURL = 'markdowneditor://oauth/callback';
  static const githubCallbackScheme = 'markdowneditor';
  static const githubScopes = 'repo,user';

  // GitHub API
  static const githubAPIBase = 'https://api.github.com';

  // Secure storage keys
  static const keychainGitHubToken = 'com.frank2679.markdowneditor.github-token';

  // SharedPreferences keys
  static const lastEditedFileKey = 'lastEditedFilePath';
}
