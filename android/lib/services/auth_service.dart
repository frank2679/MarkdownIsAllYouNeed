import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  Future<void> login() async {
    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': AppConstants.githubClientID,
      'redirect_uri': AppConstants.githubCallbackURL,
      'scope': AppConstants.githubScopes,
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: AppConstants.githubCallbackScheme,
    );

    final uri = Uri.parse(result);
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw AuthException('No authorization code received');
    }

    final token = await _exchangeCodeForToken(code);
    await saveToken(token);
  }

  Future<void> loginWithPAT(String token) async {
    await saveToken(token);
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.keychainGitHubToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.keychainGitHubToken);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(
      key: AppConstants.keychainGitHubToken,
      value: token,
    );
  }

  Future<String> _exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'client_id': AppConstants.githubClientID,
        'client_secret': AppConstants.githubClientSecret,
        'code': code,
      }),
    );

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw AuthException('Token exchange failed: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('No access token in response');
    }
    return token;
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
