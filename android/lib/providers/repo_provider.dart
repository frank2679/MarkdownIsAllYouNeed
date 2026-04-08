import 'package:flutter/foundation.dart';
import '../models/repository.dart';
import '../services/github_provider.dart';
import '../services/git_service.dart';

class RepoProvider extends ChangeNotifier {
  List<Repository> _allRepos = [];
  List<Repository> _clonedRepos = [];
  String _searchText = '';
  bool _isLoading = false;
  bool _isCloning = false;
  String _cloneProgress = '';
  String? _error;

  List<Repository> get allRepos => _filtered(_allRepos);
  List<Repository> get clonedRepos => _filtered(_clonedRepos);
  bool get isLoading => _isLoading;
  bool get isCloning => _isCloning;
  String get cloneProgress => _cloneProgress;
  String? get error => _error;
  String get searchText => _searchText;

  set searchText(String v) {
    _searchText = v;
    notifyListeners();
  }

  List<Repository> _filtered(List<Repository> repos) {
    if (_searchText.isEmpty) return repos;
    final q = _searchText.toLowerCase();
    return repos.where((r) => r.fullName.toLowerCase().contains(q)).toList();
  }

  Future<void> loadRepos(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final provider = GitHubProvider(token: token);
      final repos = await provider.fetchRepos();
      _allRepos = repos;
      await _refreshCloned(repos);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _refreshCloned(List<Repository> repos) async {
    final cloned = <Repository>[];
    for (final repo in repos) {
      if (await repo.isClonedLocally) {
        cloned.add(repo);
      }
    }
    _clonedRepos = cloned;
  }

  Future<void> clone(Repository repo, String token) async {
    _isCloning = true;
    _cloneProgress = 'Starting...';
    _error = null;
    notifyListeners();

    try {
      await GitService.shared.cloneViaAPI(repo, token, (msg) {
        _cloneProgress = msg;
        notifyListeners();
      });
      if (!_clonedRepos.any((r) => r.id == repo.id)) {
        _clonedRepos = [..._clonedRepos, repo];
      }
    } catch (e) {
      _error = e.toString();
    }

    _isCloning = false;
    notifyListeners();
  }

  Future<void> deleteLocal(Repository repo) async {
    await GitService.shared.deleteLocalRepo(repo);
    _clonedRepos = _clonedRepos.where((r) => r.id != repo.id).toList();
    notifyListeners();
  }
}
