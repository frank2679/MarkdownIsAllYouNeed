import XCTest
@testable import MarkdownEditor

/// Tests verifying v0.4.0 storage optimization:
/// - status() works correctly without a .originals directory
/// - diff() returns nil gracefully when .originals is absent
/// - saveSnapshot() does not create .originals as a side effect
final class GitServiceStorageTests: XCTestCase {

    var tempDir: URL!
    let sut = GitService.shared

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitServiceStorageTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeFile(_ content: String, path: String) throws {
        let url = tempDir.appendingPathComponent(path)
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func makeSnapshot(files: [String: TrackedFile]) throws {
        let snapshot = RepoSnapshot(
            fullName: "owner/repo",
            cloneURL: "https://github.com/owner/repo.git",
            defaultBranch: "main",
            lastSyncedAt: "2026-01-01T00:00:00Z",
            headCommitSHA: "abc123",
            treeSHA: "def456",
            files: files
        )
        try sut.saveSnapshot(snapshot, for: tempDir)
    }

    private var originalsDir: URL {
        tempDir.appendingPathComponent(".originals")
    }

    // MARK: - status() without .originals

    func testStatus_detectsModifiedFile_withoutOriginalsDirectory() throws {
        let currentContent = "# Modified heading"
        try writeFile(currentContent, path: "notes.md")

        // Snapshot records a different hash (different original content)
        let originalHash = ContentHasher.sha256("# Original heading")
        try makeSnapshot(files: [
            "notes.md": TrackedFile(sha: "sha1", originalContentHash: originalHash)
        ])

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path),
                       ".originals must not exist for this test to be meaningful")

        let changes = sut.status(at: tempDir)

        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].path, "notes.md")
        XCTAssertEqual(changes[0].changeType, .modified)
    }

    func testStatus_detectsAddedFile_withoutOriginalsDirectory() throws {
        try writeFile("# New file", path: "added.md")

        // Snapshot has no tracked files
        try makeSnapshot(files: [:])

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path))

        let changes = sut.status(at: tempDir)
        let added = changes.filter { $0.changeType == .added }

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added[0].path, "added.md")
    }

    func testStatus_detectsDeletedFile_withoutOriginalsDirectory() throws {
        // Snapshot tracks a file that doesn't exist on disk
        try makeSnapshot(files: [
            "deleted.md": TrackedFile(sha: "sha1", originalContentHash: "somehash")
        ])

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path))

        let changes = sut.status(at: tempDir)
        let deleted = changes.filter { $0.changeType == .deleted }

        XCTAssertEqual(deleted.count, 1)
        XCTAssertEqual(deleted[0].path, "deleted.md")
    }

    func testStatus_noChanges_whenFileMatchesSnapshotHash() throws {
        let content = "# Hello, world!\n\nNo changes here."
        try writeFile(content, path: "readme.md")

        let hash = ContentHasher.sha256(data: Data(content.utf8))
        try makeSnapshot(files: [
            "readme.md": TrackedFile(sha: "sha1", originalContentHash: hash)
        ])

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path))

        let changes = sut.status(at: tempDir)
        XCTAssertTrue(changes.isEmpty)
    }

    func testStatus_multipleFiles_correctlyClassifiesEach() throws {
        // unchanged: hash matches
        let unchangedContent = "# Unchanged"
        try writeFile(unchangedContent, path: "unchanged.md")
        let unchangedHash = ContentHasher.sha256(data: Data(unchangedContent.utf8))

        // modified: different hash
        try writeFile("# Modified now", path: "modified.md")
        let originalHash = ContentHasher.sha256("# Original")

        // added: not in snapshot
        try writeFile("# Added", path: "added.md")

        // deleted: in snapshot but not on disk
        try makeSnapshot(files: [
            "unchanged.md": TrackedFile(sha: "sha1", originalContentHash: unchangedHash),
            "modified.md":  TrackedFile(sha: "sha2", originalContentHash: originalHash),
            "deleted.md":   TrackedFile(sha: "sha3", originalContentHash: "somehash")
        ])

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path))

        let changes = sut.status(at: tempDir)
        XCTAssertEqual(changes.count, 3)
        XCTAssertTrue(changes.contains { $0.path == "modified.md" && $0.changeType == .modified })
        XCTAssertTrue(changes.contains { $0.path == "added.md"    && $0.changeType == .added })
        XCTAssertTrue(changes.contains { $0.path == "deleted.md"  && $0.changeType == .deleted })
    }

    // MARK: - diff() without .originals

    func testDiff_returnsNil_whenOriginalsDirectoryAbsent() throws {
        try writeFile("# Modified", path: "notes.md")

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path))

        let diff = sut.diff(at: tempDir, for: "notes.md")
        XCTAssertNil(diff, "diff() must return nil when .originals does not exist")
    }

    func testDiff_returnsNil_whenSpecificFileAbsentFromOriginals() throws {
        try writeFile("# Modified", path: "notes.md")

        // .originals directory exists but doesn't contain this file
        try FileManager.default.createDirectory(at: originalsDir, withIntermediateDirectories: true)
        // Leave .originals/notes.md absent

        let diff = sut.diff(at: tempDir, for: "notes.md")
        XCTAssertNil(diff, "diff() must return nil when .originals/{file} does not exist")
    }

    func testDiff_computesDiff_whenOriginalsPresent() throws {
        let current = "# Modified\n\nNew paragraph added."
        try writeFile(current, path: "notes.md")

        // Write original to .originals
        try FileManager.default.createDirectory(at: originalsDir, withIntermediateDirectories: true)
        let original = "# Original"
        try original.write(to: originalsDir.appendingPathComponent("notes.md"),
                           atomically: true, encoding: .utf8)

        let diff = sut.diff(at: tempDir, for: "notes.md")
        XCTAssertNotNil(diff)
        XCTAssertGreaterThan(diff!.additions, 0)
    }

    func testDiff_returnsNil_whenCurrentAndOriginalIdentical() throws {
        let content = "# Same content"
        try writeFile(content, path: "same.md")

        try FileManager.default.createDirectory(at: originalsDir, withIntermediateDirectories: true)
        try content.write(to: originalsDir.appendingPathComponent("same.md"),
                          atomically: true, encoding: .utf8)

        let diff = sut.diff(at: tempDir, for: "same.md")
        XCTAssertNil(diff, "diff() returns nil when content is identical")
    }

    // MARK: - saveSnapshot() side effects

    func testSaveSnapshot_doesNotCreateOriginalsDirectory() throws {
        let snapshot = RepoSnapshot(
            fullName: "owner/repo",
            cloneURL: "https://github.com/owner/repo.git",
            defaultBranch: "main",
            lastSyncedAt: "2026-01-01T00:00:00Z",
            headCommitSHA: "abc",
            treeSHA: "def",
            files: [:]
        )

        try sut.saveSnapshot(snapshot, for: tempDir)

        XCTAssertFalse(FileManager.default.fileExists(atPath: originalsDir.path),
                       "saveSnapshot() must not create .originals as a side effect")
    }

    func testSaveAndLoadSnapshot_roundtrip() throws {
        let files: [String: TrackedFile] = [
            "README.md": TrackedFile(sha: "blobsha1", originalContentHash: "hash1"),
            "docs/guide.md": TrackedFile(sha: "blobsha2", originalContentHash: "hash2")
        ]
        let snapshot = RepoSnapshot(
            fullName: "owner/repo",
            cloneURL: "https://github.com/owner/repo.git",
            defaultBranch: "main",
            lastSyncedAt: "2026-01-01T00:00:00Z",
            headCommitSHA: "headsha",
            treeSHA: "treesha",
            files: files
        )

        try sut.saveSnapshot(snapshot, for: tempDir)
        let loaded = sut.loadSnapshot(for: tempDir)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded!.headCommitSHA, "headsha")
        XCTAssertEqual(loaded!.files.count, 2)
        XCTAssertEqual(loaded!.files["README.md"]?.sha, "blobsha1")
        XCTAssertEqual(loaded!.files["docs/guide.md"]?.originalContentHash, "hash2")
    }
}
