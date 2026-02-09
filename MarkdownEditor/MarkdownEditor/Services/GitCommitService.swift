import Foundation

/// Handles git commit and push operations via GitHub API.
/// MVP-0: uses GitHub Contents API for commit/push since we don't have SwiftGit2 yet.
/// Each commit creates/updates files via the API, which internally creates a git commit.
final class GitCommitService {
    static let shared = GitCommitService()
    private init() {}

    /// Detect local changes by comparing file content hashes with stored snapshot
    func detectChanges(repo: Repository) -> [GitFileChange] {
        let localPath = repo.localPath
        let snapshotURL = localPath.appendingPathComponent(".file-snapshot.json")

        // Load previous snapshot
        let previousSnapshot: [String: String] = {
            guard let data = try? Data(contentsOf: snapshotURL),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return dict
        }()

        // Build current snapshot
        var currentSnapshot: [String: String] = [:]
        var changes: [GitFileChange] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: localPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: localPath.path + "/", with: "")

            // Skip metadata files
            if relativePath.hasPrefix(".") { continue }
            if relativePath == ".repo-metadata.json" || relativePath == ".file-snapshot.json" { continue }

            guard let data = try? Data(contentsOf: fileURL) else { continue }
            let hash = data.hashValue.description // Simple hash for change detection

            currentSnapshot[relativePath] = hash

            if let previousHash = previousSnapshot[relativePath] {
                if previousHash != hash {
                    changes.append(GitFileChange(path: relativePath, status: .modified))
                }
            } else {
                changes.append(GitFileChange(path: relativePath, status: .added))
            }
        }

        // Check for deleted files
        for path in previousSnapshot.keys {
            if currentSnapshot[path] == nil {
                changes.append(GitFileChange(path: path, status: .deleted))
            }
        }

        return changes
    }

    /// Save the current file state as a snapshot for future change detection
    func saveSnapshot(repo: Repository) {
        let localPath = repo.localPath
        let snapshotURL = localPath.appendingPathComponent(".file-snapshot.json")

        var snapshot: [String: String] = [:]
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: localPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: localPath.path + "/", with: "")
            if relativePath.hasPrefix(".") { continue }

            guard let data = try? Data(contentsOf: fileURL) else { continue }
            snapshot[relativePath] = data.hashValue.description
        }

        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: snapshotURL)
        }
    }

    /// Commit and push selected files to GitHub via the Contents API
    func commitAndPush(
        repo: Repository,
        changes: [GitFileChange],
        message: String,
        token: String,
        progress: @escaping (String) -> Void
    ) async throws {
        let selectedChanges = changes.filter { $0.isSelected }
        guard !selectedChanges.isEmpty else {
            throw GitError.pushFailed("No files selected")
        }

        // Get the current branch's latest commit SHA
        progress("Getting latest commit...")
        let refData = try await githubAPI(
            path: "/repos/\(repo.fullName)/git/ref/heads/\(repo.defaultBranch)",
            token: token
        )
        guard let refObj = try JSONSerialization.jsonObject(with: refData) as? [String: Any],
              let object = refObj["object"] as? [String: Any],
              let latestCommitSHA = object["sha"] as? String else {
            throw GitError.pushFailed("Cannot get latest commit")
        }

        // Get the tree SHA of the latest commit
        let commitData = try await githubAPI(
            path: "/repos/\(repo.fullName)/git/commits/\(latestCommitSHA)",
            token: token
        )
        guard let commitObj = try JSONSerialization.jsonObject(with: commitData) as? [String: Any],
              let tree = commitObj["tree"] as? [String: Any],
              let baseTreeSHA = tree["sha"] as? String else {
            throw GitError.pushFailed("Cannot get tree SHA")
        }

        // Create blobs for each changed file
        progress("Uploading files...")
        var treeEntries: [[String: Any]] = []

        for (index, change) in selectedChanges.enumerated() {
            progress("Uploading \(index + 1)/\(selectedChanges.count)...")

            if change.status == .deleted {
                // For deleted files, we set sha to null (omit from tree)
                treeEntries.append([
                    "path": change.path,
                    "mode": "100644",
                    "type": "blob",
                    "sha": NSNull(),
                ])
                continue
            }

            let fileURL = repo.localPath.appendingPathComponent(change.path)
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }

            // Create blob
            let blobBody: [String: Any] = [
                "content": fileData.base64EncodedString(),
                "encoding": "base64",
            ]
            let blobData = try await githubAPI(
                path: "/repos/\(repo.fullName)/git/blobs",
                method: "POST",
                body: blobBody,
                token: token
            )
            guard let blobObj = try JSONSerialization.jsonObject(with: blobData) as? [String: Any],
                  let blobSHA = blobObj["sha"] as? String else { continue }

            treeEntries.append([
                "path": change.path,
                "mode": "100644",
                "type": "blob",
                "sha": blobSHA,
            ])
        }

        // Create new tree
        progress("Creating commit...")
        let treeBody: [String: Any] = [
            "base_tree": baseTreeSHA,
            "tree": treeEntries,
        ]
        let newTreeData = try await githubAPI(
            path: "/repos/\(repo.fullName)/git/trees",
            method: "POST",
            body: treeBody,
            token: token
        )
        guard let newTreeObj = try JSONSerialization.jsonObject(with: newTreeData) as? [String: Any],
              let newTreeSHA = newTreeObj["sha"] as? String else {
            throw GitError.pushFailed("Cannot create tree")
        }

        // Create commit
        let commitBody: [String: Any] = [
            "message": message,
            "tree": newTreeSHA,
            "parents": [latestCommitSHA],
        ]
        let newCommitData = try await githubAPI(
            path: "/repos/\(repo.fullName)/git/commits",
            method: "POST",
            body: commitBody,
            token: token
        )
        guard let newCommitObj = try JSONSerialization.jsonObject(with: newCommitData) as? [String: Any],
              let newCommitSHA = newCommitObj["sha"] as? String else {
            throw GitError.pushFailed("Cannot create commit")
        }

        // Update branch reference
        progress("Pushing...")
        let refBody: [String: Any] = [
            "sha": newCommitSHA,
            "force": false,
        ]
        let _ = try await githubAPI(
            path: "/repos/\(repo.fullName)/git/refs/heads/\(repo.defaultBranch)",
            method: "PATCH",
            body: refBody,
            token: token
        )

        // Update local snapshot
        progress("Updating snapshot...")
        saveSnapshot(repo: repo)

        progress("Done")
    }

    // MARK: - GitHub API helper

    private func githubAPI(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        token: String
    ) async throws -> Data {
        let url = URL(string: "\(AppConstants.githubAPIBase)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitError.pushFailed("Invalid response")
        }

        // 409 means conflict (remote has newer commits)
        if httpResponse.statusCode == 409 {
            throw GitError.pushFailed("CONFLICT")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitError.pushFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        return data
    }
}
