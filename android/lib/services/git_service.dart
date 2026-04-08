import 'dart:convert';
import 'dart:io';
import '../models/git_status.dart';
import '../models/git_api_models.dart';
import '../models/repository.dart';
import 'github_provider.dart';
import 'diff_engine.dart';

class GitService {
  static final GitService shared = GitService._();
  GitService._();

  static const _originalsDir = '.originals';
  static const _metadataFile = '.repo-metadata.json';

  // MARK: - Clone

  Future<void> cloneViaAPI(
    Repository repo,
    String token,
    void Function(String) progress,
  ) async {
    final localPath = await repo.localPath;
    final provider = GitHubProvider(token: token);
    final parts = repo.fullName.split('/');
    final owner = parts[0];
    final repoName = parts[1];

    final parentDir = Directory(localPath).parent;
    if (!parentDir.existsSync()) {
      parentDir.createSync(recursive: true);
    }

    final repoDir = Directory(localPath);
    if (repoDir.existsSync()) {
      repoDir.deleteSync(recursive: true);
    }
    repoDir.createSync(recursive: true);

    progress('Fetching file tree...');

    final ref = await provider.getRef(
      owner: owner,
      repo: repoName,
      branch: repo.defaultBranch,
    );
    final headCommitSha = ref.object.sha;

    final commitDetail = await provider.getCommit(
      owner: owner,
      repo: repoName,
      sha: headCommitSha,
    );
    final treeSha = commitDetail.tree.sha;

    final tree = await provider.getTree(
      owner: owner,
      repo: repoName,
      treeSha: treeSha,
      recursive: true,
    );

    // Create directories
    final dirs = tree.tree.where((e) => e.type == 'tree').toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final dir in dirs) {
      Directory('$localPath/${dir.path}').createSync(recursive: true);
    }

    // Download blobs concurrently (max 8 per batch)
    final blobs = tree.tree.where((e) => e.type == 'blob').toList();
    final total = blobs.length;
    final trackedFiles = <String, TrackedFile>{};
    var completed = 0;

    const maxConcurrency = 8;
    for (var i = 0; i < blobs.length; i += maxConcurrency) {
      final batch = blobs.skip(i).take(maxConcurrency).toList();
      final futures = batch.map((blob) async {
        try {
          final fileData = await provider.getFileContentBytes(
            owner: owner,
            repo: repoName,
            path: blob.path,
            ref: repo.defaultBranch,
          );

          final fileUrl = '$localPath/${blob.path}';
          final fileDir = File(fileUrl).parent;
          if (!fileDir.existsSync()) {
            fileDir.createSync(recursive: true);
          }

          File(fileUrl).writeAsBytesSync(fileData);
          final contentHash = ContentHasher.sha256Bytes(fileData);
          return (blob.path, blob.sha, contentHash);
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      for (final result in results) {
        completed++;
        progress('Downloading $completed/$total...');
        if (result != null) {
          final (path, sha, hash) = result;
          trackedFiles[path] = TrackedFile(sha: sha, originalContentHash: hash);
        }
      }
    }

    final snapshot = RepoSnapshot(
      fullName: repo.fullName,
      cloneUrl: repo.cloneUrl,
      defaultBranch: repo.defaultBranch,
      lastSyncedAt: DateTime.now().toUtc().toIso8601String(),
      headCommitSha: headCommitSha,
      treeSha: treeSha,
      files: trackedFiles,
    );
    saveSnapshot(snapshot, localPath);

    final failed = total - trackedFiles.length;
    progress('Done: ${trackedFiles.length}/$total downloaded, $failed failed');
  }

  // MARK: - Snapshot

  RepoSnapshot? loadSnapshot(String repoPath) {
    final file = File('$repoPath/$_metadataFile');
    if (!file.existsSync()) return null;
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return RepoSnapshot.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void saveSnapshot(RepoSnapshot snapshot, String repoPath) {
    final file = File('$repoPath/$_metadataFile');
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(snapshot.toJson()));
  }

  // MARK: - Status

  List<FileChange> status(String repoPath) {
    final snapshot = loadSnapshot(repoPath);
    if (snapshot == null) return [];

    final changes = <FileChange>[];
    final visitedPaths = <String>{};

    _walkFiles(repoPath, repoPath, (relativePath) {
      visitedPaths.add(relativePath);

      final List<int> fileBytes;
      try {
        fileBytes = File('$repoPath/$relativePath').readAsBytesSync();
      } catch (_) {
        return;
      }
      final currentHash = ContentHasher.sha256Bytes(fileBytes);

      final tracked = snapshot.files[relativePath];
      if (tracked != null) {
        if (tracked.originalContentHash != currentHash) {
          changes.add(FileChange(
            path: relativePath,
            changeType: FileChangeType.modified,
          ));
        }
      } else {
        changes.add(FileChange(
          path: relativePath,
          changeType: FileChangeType.added,
        ));
      }
    });

    for (final path in snapshot.files.keys) {
      if (!visitedPaths.contains(path)) {
        changes.add(FileChange(path: path, changeType: FileChangeType.deleted));
      }
    }

    changes.sort((a, b) => a.path.compareTo(b.path));
    return changes;
  }

  void _walkFiles(
    String directory,
    String root,
    void Function(String) handler,
  ) {
    final dir = Directory(directory);
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync();
    } catch (_) {
      return;
    }

    for (final entry in entries) {
      final name = entry.path.split('/').last;
      if (name == _metadataFile || name == _originalsDir) continue;

      if (entry is Directory) {
        _walkFiles(entry.path, root, handler);
      } else if (entry is File) {
        var rel = entry.path;
        if (rel.startsWith(root)) rel = rel.substring(root.length);
        if (rel.startsWith('/')) rel = rel.substring(1);
        handler(rel);
      }
    }
  }

  // MARK: - Diff

  FileDiff? diff(String repoPath, String filePath) {
    final currentPath = '$repoPath/$filePath';
    final originalPath = '$repoPath/$_originalsDir/$filePath';

    if (!File(originalPath).existsSync()) return null;

    final String original;
    final String modified;
    try {
      original = File(originalPath).readAsStringSync();
      modified = File(currentPath).readAsStringSync();
    } catch (_) {
      return null;
    }

    if (original == modified) return null;

    return DiffEngine.diff(original: original, modified: modified, path: filePath);
  }

  Future<FileDiff?> diffAsync({
    required String path,
    required Repository repo,
    required String token,
  }) async {
    final repoPath = await repo.localPath;
    final originalPath = '$repoPath/$_originalsDir/$path';

    if (File(originalPath).existsSync()) {
      return diff(repoPath, path);
    }

    final snapshot = loadSnapshot(repoPath);
    if (snapshot == null || snapshot.files[path] == null) return null;

    final parts = repo.fullName.split('/');
    if (parts.length != 2) return null;

    final provider = GitHubProvider(token: token);
    try {
      final originalBytes = await provider.getFileContentBytes(
        owner: parts[0],
        repo: parts[1],
        path: path,
        ref: snapshot.headCommitSha,
      );

      final originalsBase = Directory('$repoPath/$_originalsDir');
      if (!originalsBase.existsSync()) {
        originalsBase.createSync(recursive: true);
      }
      final originalDir = File(originalPath).parent;
      if (!originalDir.existsSync()) {
        originalDir.createSync(recursive: true);
      }
      File(originalPath).writeAsBytesSync(originalBytes);

      return diff(repoPath, path);
    } catch (_) {
      return null;
    }
  }

  // MARK: - Commit & Push

  Future<void> commitAndPush({
    required Repository repo,
    required List<FileChange> changes,
    required String message,
    required String token,
    bool force = false,
  }) async {
    if (changes.isEmpty) throw GitError.noChanges();
    if (message.trim().isEmpty) {
      throw GitError('Commit message cannot be empty');
    }

    final localPath = await repo.localPath;
    final snapshot = loadSnapshot(localPath);
    if (snapshot == null) throw GitError.snapshotCorrupted();

    final provider = GitHubProvider(token: token);
    final parts = repo.fullName.split('/');
    final owner = parts[0];
    final repoName = parts[1];

    final remoteRef = await provider.getRef(
      owner: owner,
      repo: repoName,
      branch: repo.defaultBranch,
    );
    if (!force &&
        remoteRef.object.sha != snapshot.headCommitSha &&
        snapshot.headCommitSha.isNotEmpty) {
      throw GitError.conflict('Remote has new commits. Pull first.');
    }

    final treeEntries = <CreateTreeEntry>[];

    for (final change in changes) {
      if (change.changeType == FileChangeType.deleted) {
        treeEntries.add(CreateTreeEntry(path: change.path, sha: null));
      } else {
        final fileBytes =
            File('$localPath/${change.path}').readAsBytesSync();
        final base64Content = base64Encode(fileBytes);
        final blobResp = await provider.createBlob(
          owner: owner,
          repo: repoName,
          content: base64Content,
        );
        treeEntries
            .add(CreateTreeEntry(path: change.path, sha: blobResp.sha));
      }
    }

    final newTree = await provider.createTree(
      owner: owner,
      repo: repoName,
      baseTree: snapshot.treeSha,
      entries: treeEntries,
    );

    final newCommit = await provider.createCommit(
      owner: owner,
      repo: repoName,
      message: message,
      tree: newTree.sha,
      parents: [snapshot.headCommitSha],
    );

    await provider.updateRef(
      owner: owner,
      repo: repoName,
      branch: repo.defaultBranch,
      sha: newCommit.sha,
      force: force,
    );

    snapshot.headCommitSha = newCommit.sha;
    snapshot.treeSha = newTree.sha;
    snapshot.lastSyncedAt = DateTime.now().toUtc().toIso8601String();

    final originalsPath = '$localPath/$_originalsDir';

    for (final change in changes) {
      if (change.changeType == FileChangeType.deleted) {
        snapshot.files.remove(change.path);
        try {
          File('$originalsPath/${change.path}').deleteSync();
        } catch (_) {}
      } else {
        final fileBytes =
            File('$localPath/${change.path}').readAsBytesSync();
        final contentHash = ContentHasher.sha256Bytes(fileBytes);
        final entry = treeEntries.firstWhere(
          (e) => e.path == change.path,
          orElse: () => CreateTreeEntry(path: change.path),
        );
        snapshot.files[change.path] = TrackedFile(
          sha: entry.sha ?? '',
          originalContentHash: contentHash,
        );
        try {
          File('$originalsPath/${change.path}').deleteSync();
        } catch (_) {}
      }
    }

    saveSnapshot(snapshot, localPath);
  }

  // MARK: - Pull

  Future<PullResult> pull({
    required Repository repo,
    required String token,
  }) async {
    final localPath = await repo.localPath;
    final snapshot = loadSnapshot(localPath);
    if (snapshot == null) throw GitError.snapshotCorrupted();

    final provider = GitHubProvider(token: token);
    final parts = repo.fullName.split('/');
    final owner = parts[0];
    final repoName = parts[1];

    final remoteRef = await provider.getRef(
      owner: owner,
      repo: repoName,
      branch: repo.defaultBranch,
    );
    final remoteHeadSha = remoteRef.object.sha;

    if (remoteHeadSha == snapshot.headCommitSha) {
      return const PullResultUpToDate();
    }

    final remoteCommit = await provider.getCommit(
      owner: owner,
      repo: repoName,
      sha: remoteHeadSha,
    );
    final remoteTree = await provider.getTree(
      owner: owner,
      repo: repoName,
      treeSha: remoteCommit.tree.sha,
      recursive: true,
    );

    final remoteBlobs = remoteTree.tree.where((e) => e.type == 'blob').toList();
    final remoteFileMap = <String, String>{};
    for (final b in remoteBlobs) {
      remoteFileMap[b.path] = b.sha;
    }

    final localChanges = status(localPath);
    final localChangedPaths = {for (final c in localChanges) c.path};

    final conflictFiles = <String>[];
    for (final change in localChanges) {
      final remoteChanged =
          remoteFileMap[change.path] != snapshot.files[change.path]?.sha;
      if (remoteChanged) conflictFiles.add(change.path);
    }

    if (conflictFiles.isNotEmpty) return PullResultConflicts(conflictFiles);

    var filesChanged = 0;
    final originalsPath = '$localPath/$_originalsDir';
    final updatedFiles = Map<String, TrackedFile>.from(snapshot.files);

    for (final blob in remoteBlobs) {
      final localSha = snapshot.files[blob.path]?.sha;
      if (localSha != blob.sha) {
        if (localChangedPaths.contains(blob.path)) continue;
        try {
          final fileData = await provider.getFileContentBytes(
            owner: owner,
            repo: repoName,
            path: blob.path,
            ref: repo.defaultBranch,
          );

          final fileUrl = '$localPath/${blob.path}';
          final fileDir = File(fileUrl).parent;
          if (!fileDir.existsSync()) {
            fileDir.createSync(recursive: true);
          }
          File(fileUrl).writeAsBytesSync(fileData);

          try {
            File('$originalsPath/${blob.path}').deleteSync();
          } catch (_) {}

          final contentHash = ContentHasher.sha256Bytes(fileData);
          updatedFiles[blob.path] = TrackedFile(
            sha: blob.sha,
            originalContentHash: contentHash,
          );
          filesChanged++;
        } catch (_) {}
      }
    }

    for (final path in snapshot.files.keys.toList()) {
      if (!remoteFileMap.containsKey(path) &&
          !localChangedPaths.contains(path)) {
        try {
          File('$localPath/$path').deleteSync();
        } catch (_) {}
        try {
          File('$originalsPath/$path').deleteSync();
        } catch (_) {}
        updatedFiles.remove(path);
        filesChanged++;
      }
    }

    snapshot.headCommitSha = remoteHeadSha;
    snapshot.treeSha = remoteCommit.tree.sha;
    snapshot.files = updatedFiles;
    snapshot.lastSyncedAt = DateTime.now().toUtc().toIso8601String();
    saveSnapshot(snapshot, localPath);

    return PullResultUpdated(filesChanged);
  }

  // MARK: - Remote Status

  Future<SyncState> checkRemoteStatus({
    required Repository repo,
    required String token,
  }) async {
    final localPath = await repo.localPath;
    final snapshot = loadSnapshot(localPath);
    if (snapshot == null) return const SyncStateError('No snapshot found');

    final localChanges = status(localPath);
    final provider = GitHubProvider(token: token);
    final parts = repo.fullName.split('/');
    if (parts.length != 2) return const SyncStateError('Invalid repo name');

    try {
      final remoteRef = await provider.getRef(
        owner: parts[0],
        repo: parts[1],
        branch: repo.defaultBranch,
      );
      final remoteHeadSha = remoteRef.object.sha;

      final hasLocalChanges = localChanges.isNotEmpty;
      final hasRemoteChanges = remoteHeadSha != snapshot.headCommitSha &&
          snapshot.headCommitSha.isNotEmpty;

      if (hasLocalChanges && hasRemoteChanges) return const SyncStateConflict();
      if (hasLocalChanges) return SyncStateLocalChanges(localChanges.length);
      if (hasRemoteChanges) return const SyncStateRemoteChanges();
      return const SyncStateUpToDate();
    } catch (e) {
      return SyncStateError(e.toString());
    }
  }

  // MARK: - Discard

  Future<void> discardChanges({
    required FileChange change,
    required Repository repo,
    required String token,
  }) async {
    final localPath = await repo.localPath;
    final fileUrl = '$localPath/${change.path}';
    final originalUrl = '$localPath/$_originalsDir/${change.path}';

    if (change.changeType == FileChangeType.added) {
      try {
        File(fileUrl).deleteSync();
      } catch (_) {}
      return;
    }

    if (File(originalUrl).existsSync()) {
      final originalDir = File(fileUrl).parent;
      if (!originalDir.existsSync()) {
        originalDir.createSync(recursive: true);
      }
      try {
        File(fileUrl).deleteSync();
      } catch (_) {}
      File(originalUrl).copySync(fileUrl);
      return;
    }

    final snapshot = loadSnapshot(localPath);
    if (snapshot == null || snapshot.files[change.path] == null) {
      throw GitError.snapshotCorrupted();
    }

    final parts = repo.fullName.split('/');
    if (parts.length != 2) throw GitError('Invalid repo name');

    final provider = GitHubProvider(token: token);
    final originalData = await provider.getFileContentBytes(
      owner: parts[0],
      repo: parts[1],
      path: change.path,
      ref: snapshot.headCommitSha,
    );

    final originalDir = File(fileUrl).parent;
    if (!originalDir.existsSync()) {
      originalDir.createSync(recursive: true);
    }
    File(fileUrl).writeAsBytesSync(originalData);

    final originalsBase = Directory('$localPath/$_originalsDir');
    if (!originalsBase.existsSync()) {
      originalsBase.createSync(recursive: true);
    }
    final originalCacheDir = File(originalUrl).parent;
    if (!originalCacheDir.existsSync()) {
      originalCacheDir.createSync(recursive: true);
    }
    File(originalUrl).writeAsBytesSync(originalData);
  }

  // MARK: - Delete local repo

  Future<void> deleteLocalRepo(Repository repo) async {
    final localPath = await repo.localPath;
    try {
      Directory(localPath).deleteSync(recursive: true);
    } catch (_) {}
  }

  Future<bool> isCloned(Repository repo) async {
    final path = await repo.localPath;
    return Directory(path).existsSync();
  }
}

// MARK: - Errors

class GitError implements Exception {
  final String message;

  const GitError(this.message);
  const GitError.noChanges() : message = 'No changes to commit';
  const GitError.snapshotCorrupted()
      : message = 'Repository snapshot is corrupted. Try re-cloning.';
  GitError.conflict(String msg) : message = 'Conflict: $msg';

  bool get isConflict => message.startsWith('Conflict:');

  @override
  String toString() => message;
}
