import Foundation
import CryptoKit

// MARK: - Repository Snapshot

/// Complete snapshot of a repo's state, replacing RepoMetadata.
struct RepoSnapshot: Codable {
    let fullName: String
    let cloneURL: String
    let defaultBranch: String
    var lastSyncedAt: String
    var headCommitSHA: String
    var treeSHA: String
    var files: [String: TrackedFile]

    /// Create from legacy RepoMetadata (backward compat)
    init(from metadata: RepoMetadata) {
        self.fullName = metadata.fullName
        self.cloneURL = metadata.cloneURL
        self.defaultBranch = metadata.defaultBranch
        self.lastSyncedAt = metadata.lastSyncedAt
        self.headCommitSHA = ""
        self.treeSHA = ""
        self.files = [:]
    }

    init(fullName: String, cloneURL: String, defaultBranch: String,
         lastSyncedAt: String, headCommitSHA: String, treeSHA: String,
         files: [String: TrackedFile]) {
        self.fullName = fullName
        self.cloneURL = cloneURL
        self.defaultBranch = defaultBranch
        self.lastSyncedAt = lastSyncedAt
        self.headCommitSHA = headCommitSHA
        self.treeSHA = treeSHA
        self.files = files
    }
}

// MARK: - Tracked File

/// Per-file tracking info stored in the snapshot.
struct TrackedFile: Codable {
    let sha: String               // GitHub blob SHA
    let originalContentHash: String // SHA-256 of content at clone/pull time
}

// MARK: - File Change

/// Represents a local change detected by status().
struct FileChange: Identifiable {
    let id = UUID()
    let path: String
    let changeType: FileChangeType
    var isSelected: Bool = true
    var additions: Int = 0
    var deletions: Int = 0
}

enum FileChangeType: String, Codable {
    case modified = "Modified"
    case added = "Added"
    case deleted = "Deleted"
}

// MARK: - Sync State

enum SyncState: Equatable {
    case unknown
    case checking
    case upToDate
    case localChanges(count: Int)
    case remoteChanges
    case conflict
    case error(String)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.checking, .checking),
             (.upToDate, .upToDate), (.remoteChanges, .remoteChanges),
             (.conflict, .conflict):
            return true
        case (.localChanges(let a), .localChanges(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Diff Models

struct FileDiff {
    let originalPath: String
    let modifiedPath: String
    let hunks: [DiffHunk]
    let additions: Int
    let deletions: Int
}

struct DiffHunk {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]

    var header: String {
        "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@"
    }
}

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum DiffLineType {
    case context
    case addition
    case deletion
}

// MARK: - Pull Result

enum PullResult {
    case upToDate
    case updated(filesChanged: Int)
    case conflicts(files: [String])
}

// MARK: - Utility

enum ContentHasher {
    static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func sha256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
