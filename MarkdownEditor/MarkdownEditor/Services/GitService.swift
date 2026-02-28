import Foundation

/// Git operations using GitHub REST API.
/// Commits are inherently remote (API-based). Diffs and status are computed locally.
final class GitService {
    static let shared = GitService()
    private init() {}

    private let fileManager = FileManager.default
    private let originalsDir = ".originals"

    // MARK: - Clone

    /// Clone a repository via GitHub Tree API, building a full RepoSnapshot.
    func cloneViaAPI(_ repo: Repository, token: String, progress: @escaping (String) -> Void) async throws {
        let localPath = repo.localPath
        let provider = GitHubProvider(token: token)
        let components = repo.fullName.split(separator: "/")
        let owner = String(components[0])
        let repoName = String(components[1])

        let parentDir = localPath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }

        try fileManager.createDirectory(at: localPath, withIntermediateDirectories: true)

        progress("Fetching file tree...")

        // Get HEAD commit SHA and tree SHA
        let ref = try await provider.getRef(owner: owner, repo: repoName, branch: repo.defaultBranch)
        let headCommitSHA = ref.object.sha

        let commitDetail = try await provider.getCommit(owner: owner, repo: repoName, sha: headCommitSHA)
        let treeSHA = commitDetail.tree.sha

        // Get the full tree recursively
        let tree = try await provider.getTree(owner: owner, repo: repoName, treeSHA: treeSHA, recursive: true)

        // Create directories first
        let dirs = tree.tree.filter { $0.type == "tree" }.sorted { $0.path < $1.path }
        for dir in dirs {
            let dirURL = localPath.appendingPathComponent(dir.path)
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        // Download blobs (files) concurrently
        let blobs = tree.tree.filter { $0.type == "blob" }
        let total = blobs.count
        let maxConcurrency = 8
        var trackedFiles: [String: TrackedFile] = [:]

        let results = try await withThrowingTaskGroup(of: (String, String, String)?.self) { group in
            var inFlight = 0
            var completed = 0
            var collected: [(String, String, String)] = []

            for blob in blobs {
                let blobPath = blob.path
                let capturedSHA = blob.sha
                group.addTask {
                    let fileURL = localPath.appendingPathComponent(blobPath)
                    let fileDir = fileURL.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: fileDir.path) {
                        try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)
                    }

                    guard let encodedPath = blobPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
                    let contentURL = URL(string: "\(AppConstants.githubAPIBase)/repos/\(repo.fullName)/contents/\(encodedPath)?ref=\(repo.defaultBranch)")!
                    var contentRequest = URLRequest(url: contentURL)
                    contentRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    contentRequest.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")

                    do {
                        let (fileData, fileResponse) = try await URLSession.shared.data(for: contentRequest)
                        guard let httpResp = fileResponse as? HTTPURLResponse,
                              (200...299).contains(httpResp.statusCode) else { return nil }
                        try fileData.write(to: fileURL)

                        // Compute content hash for tracking
                        let contentHash = ContentHasher.sha256(data: fileData)

                        return (blobPath, capturedSHA, contentHash)
                    } catch {
                        print("Skipped \(blobPath): \(error)")
                        return nil
                    }
                }
                inFlight += 1

                // When we hit the concurrency limit, wait for one to finish
                if inFlight >= maxConcurrency {
                    if let result = try await group.next() {
                        completed += 1
                        inFlight -= 1
                        progress("Downloading \(completed)/\(total)...")
                        if let r = result { collected.append(r) }
                    }
                }
            }

            // Wait for remaining tasks
            for try await result in group {
                completed += 1
                progress("Downloading \(completed)/\(total)...")
                if let r = result { collected.append(r) }
            }

            return collected
        }

        // Build tracked files from results
        for (path, sha, contentHash) in results {
            trackedFiles[path] = TrackedFile(sha: sha, originalContentHash: contentHash)
        }

        // Save snapshot
        let snapshot = RepoSnapshot(
            fullName: repo.fullName,
            cloneURL: repo.cloneURL,
            defaultBranch: repo.defaultBranch,
            lastSyncedAt: ISO8601DateFormatter().string(from: Date()),
            headCommitSHA: headCommitSHA,
            treeSHA: treeSHA,
            files: trackedFiles
        )
        try saveSnapshot(snapshot, for: localPath)

        // Verify files on disk
        var existCount = 0
        for (path, _) in trackedFiles {
            let fileURL = localPath.appendingPathComponent(path)
            if fileManager.fileExists(atPath: fileURL.path) {
                existCount += 1
            }
        }
        let failed = total - results.count
        progress("Done: \(results.count)/\(total) downloaded, \(existCount) on disk, \(failed) failed")
    }

    // MARK: - Snapshot Persistence

    /// Load RepoSnapshot from .repo-metadata.json, with backward compat for old RepoMetadata.
    func loadSnapshot(for repoPath: URL) -> RepoSnapshot? {
        let metadataURL = repoPath.appendingPathComponent(".repo-metadata.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }

        // Try new format first
        if let snapshot = try? JSONDecoder().decode(RepoSnapshot.self, from: data) {
            return snapshot
        }

        // Fallback to legacy RepoMetadata
        if let legacy = try? JSONDecoder().decode(RepoMetadata.self, from: data) {
            return RepoSnapshot(from: legacy)
        }

        return nil
    }

    /// Save RepoSnapshot to .repo-metadata.json.
    func saveSnapshot(_ snapshot: RepoSnapshot, for repoPath: URL) throws {
        let metadataURL = repoPath.appendingPathComponent(".repo-metadata.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(snapshot)
        try data.write(to: metadataURL)
    }

    // MARK: - Status (Local Change Detection)

    /// Detect local changes by comparing current file content hashes against the snapshot.
    func status(at repoPath: URL) -> [FileChange] {
        guard let snapshot = loadSnapshot(for: repoPath) else { return [] }

        var changes: [FileChange] = []
        var visitedPaths = Set<String>()

        // Walk local files
        walkFiles(at: repoPath, relativeTo: repoPath) { relativePath in
            visitedPaths.insert(relativePath)

            let fileURL = repoPath.appendingPathComponent(relativePath)
            guard let fileData = try? Data(contentsOf: fileURL) else { return }
            let currentHash = ContentHasher.sha256(data: fileData)

            if let tracked = snapshot.files[relativePath] {
                // File exists in snapshot - check if modified
                if tracked.originalContentHash != currentHash {
                    changes.append(FileChange(path: relativePath, changeType: .modified))
                }
            } else {
                // File not in snapshot - it's added
                changes.append(FileChange(path: relativePath, changeType: .added))
            }
        }

        // Check for deleted files
        for (path, _) in snapshot.files {
            if !visitedPaths.contains(path) {
                changes.append(FileChange(path: path, changeType: .deleted))
            }
        }

        return changes.sorted { $0.path < $1.path }
    }

    /// Walk all non-hidden, non-metadata files recursively.
    private func walkFiles(at directory: URL, relativeTo root: URL, handler: (String) -> Void) {
        let rootPath = root.standardizedFileURL.path
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for url in contents {
            let standardizedURL = url.standardizedFileURL
            let name = standardizedURL.lastPathComponent
            if name == ".repo-metadata.json" || name == originalsDir { continue }

            let isDir = (try? standardizedURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                walkFiles(at: standardizedURL, relativeTo: root, handler: handler)
            } else {
                let filePath = standardizedURL.path
                if filePath.hasPrefix(rootPath) {
                    var relativePath = String(filePath.dropFirst(rootPath.count))
                    // Remove leading slash if present
                    if relativePath.hasPrefix("/") {
                        relativePath.removeFirst()
                    }
                    handler(relativePath)
                }
            }
        }
    }

    // MARK: - Diff

    /// Compute a diff for a single file by comparing against .originals copy.
    /// Returns nil if the original is not cached locally (use diffAsync to fetch on-demand).
    func diff(at repoPath: URL, for filePath: String) -> FileDiff? {
        let currentURL = repoPath.appendingPathComponent(filePath)
        let originalURL = repoPath.appendingPathComponent(originalsDir).appendingPathComponent(filePath)

        // Original not cached locally — cannot compute diff synchronously.
        guard fileManager.fileExists(atPath: originalURL.path) else { return nil }

        let original = (try? String(contentsOf: originalURL, encoding: .utf8)) ?? ""
        let modified = (try? String(contentsOf: currentURL, encoding: .utf8)) ?? ""

        if original == modified { return nil }

        return DiffEngine.diff(original: original, modified: modified, path: filePath)
    }

    /// Async variant: fetches the original content from GitHub if not cached locally,
    /// caches it in .originals, then returns the diff. Returns nil if unfetchable.
    func diffAsync(path: String, repo: Repository, token: String) async -> FileDiff? {
        let repoPath = repo.localPath
        let originalURL = repoPath.appendingPathComponent(originalsDir).appendingPathComponent(path)

        // Fast path: original already cached
        if fileManager.fileExists(atPath: originalURL.path) {
            return diff(at: repoPath, for: path)
        }

        // Slow path: fetch original from GitHub at the commit SHA recorded at clone time
        guard let snapshot = loadSnapshot(for: repoPath),
              snapshot.files[path] != nil else { return nil }

        let parts = repo.fullName.split(separator: "/")
        guard parts.count == 2 else { return nil }
        let owner = String(parts[0])
        let repoName = String(parts[1])

        let provider = GitHubProvider(token: token)
        do {
            let originalData = try await provider.getFileContent(
                owner: owner, repo: repoName,
                path: path, ref: snapshot.headCommitSHA
            )

            // Cache in .originals for subsequent calls
            let originalsBase = repoPath.appendingPathComponent(originalsDir)
            if !fileManager.fileExists(atPath: originalsBase.path) {
                try fileManager.createDirectory(at: originalsBase, withIntermediateDirectories: true)
            }
            let originalDir = originalURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: originalDir.path) {
                try fileManager.createDirectory(at: originalDir, withIntermediateDirectories: true)
            }
            try originalData.write(to: originalURL)

            return diff(at: repoPath, for: path)
        } catch {
            print("[GitService] Failed to fetch original for diff (\(path)): \(error)")
            return nil
        }
    }

    // MARK: - Commit & Push

    /// Create a commit with selected changes and push to remote via GitHub API.
    func commitAndPush(repo: Repository, changes: [FileChange], message: String, token: String, force: Bool = false) async throws {
        guard !changes.isEmpty else { throw GitError.noChanges }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitError.commitFailed("Commit message cannot be empty")
        }

        let localPath = repo.localPath
        guard var snapshot = loadSnapshot(for: localPath) else {
            throw GitError.snapshotCorrupted
        }

        let provider = GitHubProvider(token: token)
        let components = repo.fullName.split(separator: "/")
        let owner = String(components[0])
        let repoName = String(components[1])

        // Check for conflicts: compare remote HEAD vs local headCommitSHA
        let remoteRef = try await provider.getRef(owner: owner, repo: repoName, branch: repo.defaultBranch)
        if !force && remoteRef.object.sha != snapshot.headCommitSHA && !snapshot.headCommitSHA.isEmpty {
            throw GitError.conflictDetected("Remote has new commits. Pull first.")
        }

        // Create blobs for each changed file
        var treeEntries: [CreateTreeEntry] = []

        for change in changes {
            switch change.changeType {
            case .modified, .added:
                let fileURL = localPath.appendingPathComponent(change.path)
                guard let fileData = try? Data(contentsOf: fileURL) else { continue }
                let base64Content = fileData.base64EncodedString()

                let blobResponse = try await provider.createBlob(
                    owner: owner, repo: repoName,
                    content: base64Content, encoding: "base64"
                )

                treeEntries.append(CreateTreeEntry(
                    path: change.path,
                    mode: "100644",
                    type: "blob",
                    sha: blobResponse.sha
                ))

            case .deleted:
                // Setting sha to nil with the file path removes it from the tree
                treeEntries.append(CreateTreeEntry(
                    path: change.path,
                    mode: "100644",
                    type: "blob",
                    sha: nil
                ))
            }
        }

        // Create new tree
        let newTree = try await provider.createTree(
            owner: owner, repo: repoName,
            baseTree: snapshot.treeSHA,
            entries: treeEntries
        )

        // Create commit
        let newCommit = try await provider.createCommit(
            owner: owner, repo: repoName,
            message: message,
            tree: newTree.sha,
            parents: [snapshot.headCommitSHA]
        )

        // Update branch ref
        _ = try await provider.updateRef(
            owner: owner, repo: repoName,
            branch: repo.defaultBranch,
            sha: newCommit.sha,
            force: force
        )

        // Update local snapshot
        snapshot.headCommitSHA = newCommit.sha
        snapshot.treeSHA = newTree.sha
        snapshot.lastSyncedAt = ISO8601DateFormatter().string(from: Date())

        // Update tracked files; evict .originals cache entries for committed files
        let originalsPath = localPath.appendingPathComponent(originalsDir)

        for change in changes {
            switch change.changeType {
            case .modified, .added:
                let fileURL = localPath.appendingPathComponent(change.path)
                if let fileData = try? Data(contentsOf: fileURL) {
                    let contentHash = ContentHasher.sha256(data: fileData)
                    let blobSHA = treeEntries.first(where: { $0.path == change.path })?.sha ?? ""
                    snapshot.files[change.path] = TrackedFile(sha: blobSHA, originalContentHash: contentHash)

                    // Evict .originals cache — committed content becomes the new baseline,
                    // so the next diff will fetch fresh from GitHub.
                    let originalURL = originalsPath.appendingPathComponent(change.path)
                    try? fileManager.removeItem(at: originalURL)
                }

            case .deleted:
                snapshot.files.removeValue(forKey: change.path)
                let originalURL = originalsPath.appendingPathComponent(change.path)
                try? fileManager.removeItem(at: originalURL)
            }
        }

        try saveSnapshot(snapshot, for: localPath)
    }

    // MARK: - Pull

    /// Pull remote changes into local repo.
    func pull(repo: Repository, token: String) async throws -> PullResult {
        let localPath = repo.localPath
        guard var snapshot = loadSnapshot(for: localPath) else {
            throw GitError.snapshotCorrupted
        }

        let provider = GitHubProvider(token: token)
        let components = repo.fullName.split(separator: "/")
        let owner = String(components[0])
        let repoName = String(components[1])

        // Fetch remote HEAD
        let remoteRef = try await provider.getRef(owner: owner, repo: repoName, branch: repo.defaultBranch)
        let remoteHeadSHA = remoteRef.object.sha

        // If same, nothing to do
        if remoteHeadSHA == snapshot.headCommitSHA {
            return .upToDate
        }

        // Get remote commit and tree
        let remoteCommit = try await provider.getCommit(owner: owner, repo: repoName, sha: remoteHeadSHA)
        let remoteTreeSHA = remoteCommit.tree.sha
        let remoteTree = try await provider.getTree(owner: owner, repo: repoName, treeSHA: remoteTreeSHA, recursive: true)

        // Build map of remote files
        let remoteBlobs = remoteTree.tree.filter { $0.type == "blob" }
        var remoteFileMap: [String: String] = [:] // path -> sha
        for blob in remoteBlobs {
            remoteFileMap[blob.path] = blob.sha
        }

        // Check for conflicts: files changed both locally and remotely
        let localChanges = status(at: localPath)
        let localChangedPaths = Set(localChanges.map { $0.path })
        var conflictFiles: [String] = []

        for change in localChanges {
            let remoteChanged = remoteFileMap[change.path] != snapshot.files[change.path]?.sha
            if remoteChanged {
                conflictFiles.append(change.path)
            }
        }

        if !conflictFiles.isEmpty {
            return .conflicts(files: conflictFiles)
        }

        // Download changed files
        var filesChanged = 0
        let originalsPath = localPath.appendingPathComponent(originalsDir)
        var updatedFiles = snapshot.files

        for blob in remoteBlobs {
            let localSHA = snapshot.files[blob.path]?.sha
            if localSHA != blob.sha {
                // File changed on remote - download it
                // Skip if locally modified (already checked for conflicts above)
                if localChangedPaths.contains(blob.path) { continue }

                do {
                    let fileData = try await provider.getFileContent(
                        owner: owner, repo: repoName,
                        path: blob.path, ref: repo.defaultBranch
                    )

                    let fileURL = localPath.appendingPathComponent(blob.path)
                    let fileDir = fileURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: fileDir.path) {
                        try fileManager.createDirectory(at: fileDir, withIntermediateDirectories: true)
                    }
                    try fileData.write(to: fileURL)

                    // Evict stale .originals cache so next diff fetch is fresh
                    let originalURL = originalsPath.appendingPathComponent(blob.path)
                    try? fileManager.removeItem(at: originalURL)

                    let contentHash = ContentHasher.sha256(data: fileData)
                    updatedFiles[blob.path] = TrackedFile(sha: blob.sha, originalContentHash: contentHash)
                    filesChanged += 1
                } catch {
                    print("Failed to pull \(blob.path): \(error)")
                }
            }
        }

        // Remove files deleted on remote
        for (path, _) in snapshot.files {
            if remoteFileMap[path] == nil && !localChangedPaths.contains(path) {
                let fileURL = localPath.appendingPathComponent(path)
                try? fileManager.removeItem(at: fileURL)
                let originalURL = originalsPath.appendingPathComponent(path)
                try? fileManager.removeItem(at: originalURL)
                updatedFiles.removeValue(forKey: path)
                filesChanged += 1
            }
        }

        // Update snapshot
        snapshot.headCommitSHA = remoteHeadSHA
        snapshot.treeSHA = remoteTreeSHA
        snapshot.files = updatedFiles
        snapshot.lastSyncedAt = ISO8601DateFormatter().string(from: Date())
        try saveSnapshot(snapshot, for: localPath)

        return .updated(filesChanged: filesChanged)
    }

    // MARK: - Remote Status Check

    /// Quick check: local changes count + remote HEAD comparison.
    func checkRemoteStatus(repo: Repository, token: String) async -> SyncState {
        let localPath = repo.localPath
        guard let snapshot = loadSnapshot(for: localPath) else {
            return .error("No snapshot found")
        }

        let localChanges = status(at: localPath)

        // Check remote HEAD
        let provider = GitHubProvider(token: token)
        let components = repo.fullName.split(separator: "/")
        guard components.count == 2 else { return .error("Invalid repo name") }
        let owner = String(components[0])
        let repoName = String(components[1])

        do {
            let remoteRef = try await provider.getRef(owner: owner, repo: repoName, branch: repo.defaultBranch)
            let remoteHeadSHA = remoteRef.object.sha

            let hasLocalChanges = !localChanges.isEmpty
            let hasRemoteChanges = remoteHeadSHA != snapshot.headCommitSHA && !snapshot.headCommitSHA.isEmpty

            if hasLocalChanges && hasRemoteChanges {
                return .conflict
            } else if hasLocalChanges {
                return .localChanges(count: localChanges.count)
            } else if hasRemoteChanges {
                return .remoteChanges
            } else {
                return .upToDate
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Discard

    /// Discard local changes for a single file, restoring it to its original state.
    /// - For `added` files: deletes the local file (it never existed in the remote).
    /// - For `modified`/`deleted` files: restores from `.originals/` cache or fetches from GitHub.
    func discardChanges(change: FileChange, repo: Repository, token: String) async throws {
        let localPath = repo.localPath
        let fileURL = localPath.appendingPathComponent(change.path)
        let originalURL = localPath.appendingPathComponent(originalsDir).appendingPathComponent(change.path)

        switch change.changeType {
        case .added:
            // New file — just delete it
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }

        case .modified, .deleted:
            // If original is cached locally, restore directly
            if fileManager.fileExists(atPath: originalURL.path) {
                let originalDir = fileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: originalDir.path) {
                    try fileManager.createDirectory(at: originalDir, withIntermediateDirectories: true)
                }
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
                try fileManager.copyItem(at: originalURL, to: fileURL)
                return
            }

            // Otherwise fetch from GitHub at the snapshot commit SHA
            guard let snapshot = loadSnapshot(for: localPath),
                  snapshot.files[change.path] != nil else {
                throw GitError.snapshotCorrupted
            }

            let parts = repo.fullName.split(separator: "/")
            guard parts.count == 2 else { throw GitError.commitFailed("Invalid repo name") }
            let owner = String(parts[0])
            let repoName = String(parts[1])

            let provider = GitHubProvider(token: token)
            // Fall back to default branch if headCommitSHA is empty (e.g. repos migrated from old format)
            let ref = snapshot.headCommitSHA.isEmpty ? repo.defaultBranch : snapshot.headCommitSHA
            let originalData = try await provider.getFileContent(
                owner: owner, repo: repoName,
                path: change.path, ref: ref
            )

            // Restore the file
            let originalDir = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: originalDir.path) {
                try fileManager.createDirectory(at: originalDir, withIntermediateDirectories: true)
            }
            try originalData.write(to: fileURL)

            // Also cache in .originals for future diffs
            let originalsBase = localPath.appendingPathComponent(originalsDir)
            if !fileManager.fileExists(atPath: originalsBase.path) {
                try fileManager.createDirectory(at: originalsBase, withIntermediateDirectories: true)
            }
            let originalCacheDir = originalURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: originalCacheDir.path) {
                try fileManager.createDirectory(at: originalCacheDir, withIntermediateDirectories: true)
            }
            try originalData.write(to: originalURL)
        }
    }

    // MARK: - Existing Operations

    /// Delete a cloned repo from local storage
    func deleteLocalRepo(at path: URL) throws {
        try fileManager.removeItem(at: path)
    }

    /// Check if repo exists locally
    func isCloned(_ repo: Repository) -> Bool {
        fileManager.fileExists(atPath: repo.localPath.path)
    }
}

// MARK: - Models (kept for backward compatibility)

struct RepoMetadata: Codable {
    let fullName: String
    let cloneURL: String
    let defaultBranch: String
    let lastSyncedAt: String
}

struct GitTree: Codable {
    let sha: String
    let tree: [GitTreeEntry]
}

struct GitTreeEntry: Codable {
    let path: String
    let type: String       // "blob" or "tree"
    let sha: String?
    let size: Int?
}

enum GitError: LocalizedError {
    case cloneFailed(String)
    case pushFailed(String)
    case pullFailed(String)
    case commitFailed(String)
    case conflictDetected(String)
    case noChanges
    case snapshotCorrupted

    var errorDescription: String? {
        switch self {
        case .cloneFailed(let msg): return "Clone failed: \(msg)"
        case .pushFailed(let msg): return "Push failed: \(msg)"
        case .pullFailed(let msg): return "Pull failed: \(msg)"
        case .commitFailed(let msg): return "Commit failed: \(msg)"
        case .conflictDetected(let msg): return "Conflict: \(msg)"
        case .noChanges: return "No changes to commit"
        case .snapshotCorrupted: return "Repository snapshot is corrupted. Try re-cloning."
        }
    }
}
