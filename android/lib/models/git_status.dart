import 'dart:convert';
import 'package:crypto/crypto.dart';

// MARK: - Repository Snapshot

class RepoSnapshot {
  final String fullName;
  final String cloneUrl;
  final String defaultBranch;
  String lastSyncedAt;
  String headCommitSha;
  String treeSha;
  Map<String, TrackedFile> files;

  RepoSnapshot({
    required this.fullName,
    required this.cloneUrl,
    required this.defaultBranch,
    required this.lastSyncedAt,
    required this.headCommitSha,
    required this.treeSha,
    required this.files,
  });

  factory RepoSnapshot.fromJson(Map<String, dynamic> json) => RepoSnapshot(
        fullName: json['fullName'] as String,
        cloneUrl: json['cloneURL'] as String,
        defaultBranch: json['defaultBranch'] as String,
        lastSyncedAt: json['lastSyncedAt'] as String,
        headCommitSha: json['headCommitSHA'] as String? ?? '',
        treeSha: json['treeSHA'] as String? ?? '',
        files: (json['files'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, TrackedFile.fromJson(v as Map<String, dynamic>)),
        ),
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'cloneURL': cloneUrl,
        'defaultBranch': defaultBranch,
        'lastSyncedAt': lastSyncedAt,
        'headCommitSHA': headCommitSha,
        'treeSHA': treeSha,
        'files': files.map((k, v) => MapEntry(k, v.toJson())),
      };
}

// MARK: - Tracked File

class TrackedFile {
  final String sha;
  final String originalContentHash;

  const TrackedFile({required this.sha, required this.originalContentHash});

  factory TrackedFile.fromJson(Map<String, dynamic> json) => TrackedFile(
        sha: json['sha'] as String,
        originalContentHash: json['originalContentHash'] as String,
      );

  Map<String, dynamic> toJson() => {
        'sha': sha,
        'originalContentHash': originalContentHash,
      };
}

// MARK: - File Change

enum FileChangeType { modified, added, deleted }

class FileChange {
  final String path;
  final FileChangeType changeType;
  bool isSelected;
  int additions;
  int deletions;

  FileChange({
    required this.path,
    required this.changeType,
    this.isSelected = true,
    this.additions = 0,
    this.deletions = 0,
  });
}

// MARK: - Sync State

sealed class SyncState {
  const SyncState();
}

class SyncStateUnknown extends SyncState {
  const SyncStateUnknown();
}

class SyncStateChecking extends SyncState {
  const SyncStateChecking();
}

class SyncStateUpToDate extends SyncState {
  const SyncStateUpToDate();
}

class SyncStateLocalChanges extends SyncState {
  final int count;
  const SyncStateLocalChanges(this.count);
}

class SyncStateRemoteChanges extends SyncState {
  const SyncStateRemoteChanges();
}

class SyncStateConflict extends SyncState {
  const SyncStateConflict();
}

class SyncStateError extends SyncState {
  final String message;
  const SyncStateError(this.message);
}

// MARK: - Diff Models

class FileDiff {
  final String originalPath;
  final String modifiedPath;
  final List<DiffHunk> hunks;
  final int additions;
  final int deletions;

  const FileDiff({
    required this.originalPath,
    required this.modifiedPath,
    required this.hunks,
    required this.additions,
    required this.deletions,
  });
}

class DiffHunk {
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;

  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  String get header => '@@ -$oldStart,$oldCount +$newStart,$newCount @@';
}

enum DiffLineType { context, addition, deletion }

class DiffLine {
  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

// MARK: - Pull Result

sealed class PullResult {
  const PullResult();
}

class PullResultUpToDate extends PullResult {
  const PullResultUpToDate();
}

class PullResultUpdated extends PullResult {
  final int filesChanged;
  const PullResultUpdated(this.filesChanged);
}

class PullResultConflicts extends PullResult {
  final List<String> files;
  const PullResultConflicts(this.files);
}

// MARK: - Content Hasher

class ContentHasher {
  static String sha256String(String text) {
    final bytes = utf8.encode(text);
    return sha256.convert(bytes).toString();
  }

  static String sha256Bytes(List<int> data) {
    return sha256.convert(data).toString();
  }
}
