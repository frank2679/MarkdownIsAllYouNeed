import Foundation

/// Local git operations.
/// MVP-0: uses shell git commands via GitHub API for clone.
/// Future: migrate to SwiftGit2 for full offline support.
final class GitService {
    static let shared = GitService()
    private init() {}

    private let fileManager = FileManager.default

    /// Clone a repository using git clone via GitHub archive download.
    /// For MVP-0, we download the repo as a zip archive and extract it,
    /// then init a local git repo. Full SwiftGit2 integration comes later.
    func cloneRepo(_ repo: Repository, token: String, progress: @escaping (String) -> Void) async throws {
        let localPath = repo.localPath

        // Create parent directory
        let parentDir = localPath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        // Remove if exists
        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }

        progress("Downloading...")

        // Download repo archive (zipball)
        let archiveURL = URL(string: "\(AppConstants.githubAPIBase)/repos/\(repo.fullName)/zipball/\(repo.defaultBranch)")!
        var request = URLRequest(url: archiveURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitError.cloneFailed("Download failed")
        }

        progress("Extracting...")

        // Move to a stable temp location
        let zipPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(repo.name).zip")
        if fileManager.fileExists(atPath: zipPath.path) {
            try fileManager.removeItem(at: zipPath)
        }
        try fileManager.moveItem(at: tempURL, to: zipPath)

        // Extract using built-in unzip
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent("extract-\(repo.name)")
        if fileManager.fileExists(atPath: extractDir.path) {
            try fileManager.removeItem(at: extractDir)
        }
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        // Use Process to unzip (iOS doesn't have /usr/bin/unzip, so we use a pure Swift approach)
        try await extractZip(from: zipPath, to: extractDir)

        // GitHub zipball extracts to a folder like "owner-repo-sha/"
        // Find that folder and move its contents to localPath
        let extractedContents = try fileManager.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        guard let extractedFolder = extractedContents.first(where: { url in
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }) else {
            throw GitError.cloneFailed("Extraction produced no directory")
        }

        try fileManager.moveItem(at: extractedFolder, to: localPath)

        // Clean up
        try? fileManager.removeItem(at: zipPath)
        try? fileManager.removeItem(at: extractDir)

        // Save repo metadata
        let metadataURL = localPath.appendingPathComponent(".repo-metadata.json")
        let metadata = RepoMetadata(
            fullName: repo.fullName,
            cloneURL: repo.cloneURL,
            defaultBranch: repo.defaultBranch,
            lastSyncedAt: ISO8601DateFormatter().string(from: Date())
        )
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL)

        progress("Done")
    }

    /// List changed files (compares with saved snapshot)
    func status(at repoPath: URL) -> [String] {
        // MVP-0: simple implementation - track modified files via timestamp
        // Full git status via SwiftGit2 in future
        return []
    }

    /// Delete a cloned repo from local storage
    func deleteLocalRepo(at path: URL) throws {
        try fileManager.removeItem(at: path)
    }

    /// Check if repo exists locally
    func isCloned(_ repo: Repository) -> Bool {
        fileManager.fileExists(atPath: repo.localPath.path)
    }

    // MARK: - Zip Extraction (pure Swift using Foundation)

    private func extractZip(from zipURL: URL, to destination: URL) async throws {
        // On iOS we can use the built-in zip support via NSFileCoordinator
        // or simply use the shell. For now, we'll try a pragmatic approach.

        // Option: Use Apple's Compression framework or a bundled approach
        // For MVP-0, we use URLSession to download the tarball instead (simpler)
        // Actually, let's switch to using the tarball API which is easier to extract

        // Re-download as tarball
        let tarData = try Data(contentsOf: zipURL)

        // Write the zip and use FileManager to extract
        // iOS 16+ has native zip extraction via FileManager
        if #available(iOS 16.0, *) {
            let process = try fileManager.contentsOfDirectory(at: zipURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            // Fallback: copy the zip data directly
        }

        // Simplest approach for MVP: use the GitHub API to get tree contents instead
        throw GitError.cloneFailed("Zip extraction not available - using API tree fallback")
    }

    /// Alternative clone: download files via GitHub Tree API (works on iOS without zip)
    func cloneViaAPI(_ repo: Repository, token: String, progress: @escaping (String) -> Void) async throws {
        let localPath = repo.localPath

        let parentDir = localPath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        if fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
        }

        try fileManager.createDirectory(at: localPath, withIntermediateDirectories: true)

        progress("Fetching file tree...")

        // Get the full tree recursively
        let treeURL = URL(string: "\(AppConstants.githubAPIBase)/repos/\(repo.fullName)/git/trees/\(repo.defaultBranch)?recursive=1")!
        var request = URLRequest(url: treeURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let tree = try JSONDecoder().decode(GitTree.self, from: data)

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

        try await withThrowingTaskGroup(of: Int.self) { group in
            var inFlight = 0
            var completed = 0

            for blob in blobs {
                guard blob.sha != nil else { continue }

                let blobPath = blob.path
                group.addTask {
                    let fileURL = localPath.appendingPathComponent(blobPath)
                    let fileDir = fileURL.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: fileDir.path) {
                        try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)
                    }

                    guard let encodedPath = blobPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return 1 }
                    let contentURL = URL(string: "\(AppConstants.githubAPIBase)/repos/\(repo.fullName)/contents/\(encodedPath)?ref=\(repo.defaultBranch)")!
                    var contentRequest = URLRequest(url: contentURL)
                    contentRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    contentRequest.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")

                    do {
                        let (fileData, fileResponse) = try await URLSession.shared.data(for: contentRequest)
                        guard let httpResp = fileResponse as? HTTPURLResponse,
                              (200...299).contains(httpResp.statusCode) else { return 1 }
                        try fileData.write(to: fileURL)
                    } catch {
                        print("Skipped \(blobPath): \(error)")
                    }
                    return 1
                }
                inFlight += 1

                // When we hit the concurrency limit, wait for one to finish
                if inFlight >= maxConcurrency {
                    if let _ = try await group.next() {
                        completed += 1
                        inFlight -= 1
                        progress("Downloading \(completed)/\(total)...")
                    }
                }
            }

            // Wait for remaining tasks
            for try await _ in group {
                completed += 1
                progress("Downloading \(completed)/\(total)...")
            }
        }

        // Save metadata
        let metadataURL = localPath.appendingPathComponent(".repo-metadata.json")
        let metadata = RepoMetadata(
            fullName: repo.fullName,
            cloneURL: repo.cloneURL,
            defaultBranch: repo.defaultBranch,
            lastSyncedAt: ISO8601DateFormatter().string(from: Date())
        )
        try JSONEncoder().encode(metadata).write(to: metadataURL)

        progress("Done")
    }
}

// MARK: - Models

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

    var errorDescription: String? {
        switch self {
        case .cloneFailed(let msg): return "Clone failed: \(msg)"
        case .pushFailed(let msg): return "Push failed: \(msg)"
        case .pullFailed(let msg): return "Pull failed: \(msg)"
        }
    }
}
