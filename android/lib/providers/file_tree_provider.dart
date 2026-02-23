import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repository.dart';
import '../models/file_node.dart';
import '../models/git_status.dart';
import '../services/file_manager_service.dart';
import '../services/git_service.dart';

class FileTreeProvider extends ChangeNotifier {
  Repository? _repo;
  String? _token;
  List<FileNode> _nodes = [];
  List<FileChange> _changes = [];
  SyncState _syncState = const SyncStateUnknown();
  bool _isLoadingSync = false;
  String? _error;

  // Favorites & recents
  Set<String> _favoritePaths = {};
  List<String> _recentPaths = [];
  static const _favKey = 'favorites';
  static const _recentKey = 'recents';
  static const _maxRecents = 10;

  Repository? get repo => _repo;
  List<FileNode> get nodes => _nodes;
  List<FileChange> get changes => _changes;
  SyncState get syncState => _syncState;
  bool get isLoadingSync => _isLoadingSync;
  String? get error => _error;
  Set<String> get favoritePaths => _favoritePaths;
  List<String> get recentPaths => _recentPaths;

  FileTreeProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _favoritePaths = Set.from(prefs.getStringList(_favKey) ?? []);
    _recentPaths = prefs.getStringList(_recentKey) ?? [];
    notifyListeners();
  }

  Future<void> open(Repository repo, String token) async {
    _repo = repo;
    _token = token;
    await refresh();
    await checkSyncState();
  }

  Future<void> refresh() async {
    final repo = _repo;
    if (repo == null) return;

    final localPath = await repo.localPath;
    final changes = GitService.shared.status(localPath);
    _changes = changes;
    _nodes = FileManagerService.shared.buildFileTreeWithChanges(localPath, changes);
    notifyListeners();
  }

  Future<void> checkSyncState() async {
    final repo = _repo;
    final token = _token;
    if (repo == null || token == null) return;

    _isLoadingSync = true;
    _syncState = const SyncStateChecking();
    notifyListeners();

    final state = await GitService.shared.checkRemoteStatus(
      repo: repo,
      token: token,
    );
    _syncState = state;
    _isLoadingSync = false;
    notifyListeners();
  }

  // MARK: - File Operations

  Future<void> createFile(String name, String dirPath) async {
    FileManagerService.shared.createFile(name, dirPath);
    await refresh();
  }

  Future<void> createDirectory(String name, String parentPath) async {
    FileManagerService.shared.createDirectory(name, parentPath);
    await refresh();
  }

  Future<void> delete(String path) async {
    FileManagerService.shared.delete(path);
    await refresh();
  }

  Future<void> rename(String path, String newName) async {
    FileManagerService.shared.rename(path, newName);
    await refresh();
  }

  Future<void> move(String sourcePath, String destPath) async {
    FileManagerService.shared.move(sourcePath, destPath);
    await refresh();
  }

  // MARK: - Favorites

  Future<void> toggleFavorite(String relativePath) async {
    if (_favoritePaths.contains(relativePath)) {
      _favoritePaths.remove(relativePath);
    } else {
      _favoritePaths.add(relativePath);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favoritePaths.toList());
    notifyListeners();
  }

  bool isFavorite(String relativePath) => _favoritePaths.contains(relativePath);

  // MARK: - Recents

  Future<void> recordRecent(String relativePath) async {
    _recentPaths.remove(relativePath);
    _recentPaths.insert(0, relativePath);
    if (_recentPaths.length > _maxRecents) {
      _recentPaths = _recentPaths.sublist(0, _maxRecents);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recentPaths);
    notifyListeners();
  }

  // MARK: - Discard

  Future<void> discardChanges(FileChange change) async {
    final repo = _repo;
    final token = _token;
    if (repo == null || token == null) return;

    await GitService.shared.discardChanges(
      change: change,
      repo: repo,
      token: token,
    );
    await refresh();
  }

  // MARK: - Pull

  Future<PullResult> pull() async {
    final repo = _repo;
    final token = _token;
    if (repo == null || token == null) throw GitError('No repo loaded');

    final result = await GitService.shared.pull(repo: repo, token: token);
    await refresh();
    await checkSyncState();
    return result;
  }
}
