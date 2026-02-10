import AuthenticationServices
import Foundation

final class AuthService: NSObject {
    private var webAuthSession: ASWebAuthenticationSession?

    func login() async throws {
        let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let urlString = "https://github.com/login/oauth/authorize"
                + "?client_id=\(AppConstants.githubClientID)"
                + "&redirect_uri=\(AppConstants.githubCallbackURL)"
                + "&scope=\(AppConstants.githubScopes)"

            guard let url = URL(string: urlString) else {
                continuation.resume(throwing: AuthError.invalidURL)
                return
            }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "markdowneditor"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }

                Task {
                    do {
                        let token = try await self.exchangeCodeForToken(code: code)
                        continuation.resume(returning: token)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            DispatchQueue.main.async {
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
            self.webAuthSession = session
        }

        KeychainHelper.save(key: AppConstants.keychainGitHubToken, value: token)
    }

    func loginWithPAT(_ token: String) {
        KeychainHelper.save(key: AppConstants.keychainGitHubToken, value: token)
    }

    func logout() {
        KeychainHelper.delete(key: AppConstants.keychainGitHubToken)
    }

    func getAccessToken() -> String? {
        KeychainHelper.read(key: AppConstants.keychainGitHubToken)
    }

    private func exchangeCodeForToken(code: String) async throws -> String {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: String] = [
            "client_id": AppConstants.githubClientID,
            "client_secret": AppConstants.githubClientSecret,
            "code": code,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        guard let token = response.accessToken else {
            throw AuthError.tokenExchangeFailed
        }
        return token
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

private struct TokenResponse: Codable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }
}

enum AuthError: LocalizedError {
    case invalidURL
    case noCode
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid OAuth URL"
        case .noCode: return "No authorization code received"
        case .tokenExchangeFailed: return "Failed to exchange code for token"
        }
    }
}
