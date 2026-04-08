import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/github_provider.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = AuthService();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  UserProfile? _userProfile;
  String? _error;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  UserProfile? get userProfile => _userProfile;
  String? get error => _error;

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
      await _fetchProfile(token);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login() async {
    _error = null;
    notifyListeners();
    try {
      await _auth.login();
      final token = await _auth.getAccessToken();
      if (token != null) {
        _isLoggedIn = true;
        await _fetchProfile(token);
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> loginWithPAT(String token) async {
    _error = null;
    notifyListeners();
    try {
      await _auth.loginWithPAT(token);
      _isLoggedIn = true;
      await _fetchProfile(token);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _isLoggedIn = false;
    _userProfile = null;
    notifyListeners();
  }

  Future<String?> get token => _auth.getAccessToken();

  Future<void> _fetchProfile(String token) async {
    try {
      final provider = GitHubProvider(token: token);
      _userProfile = await provider.fetchUserProfile();
    } catch (_) {}
  }
}
