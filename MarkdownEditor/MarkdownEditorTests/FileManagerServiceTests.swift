import XCTest
@testable import MarkdownEditor

final class FileManagerServiceTests: XCTestCase {

    var tempDir: URL!
    let sut = FileManagerService.shared

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownEditorTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - createFile

    func testCreateFile_createsFileAtCorrectPath() throws {
        let url = try sut.createFile(named: "test.md", in: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testCreateFile_returnsURLWithCorrectName() throws {
        let url = try sut.createFile(named: "note.md", in: tempDir)
        XCTAssertEqual(url.lastPathComponent, "note.md")
    }

    func testCreateFile_createsEmptyFile() throws {
        let url = try sut.createFile(named: "empty.md", in: tempDir)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "")
    }

    func testCreateFile_fileAppearsInBuildFileTree() throws {
        _ = try sut.createFile(named: "appear.md", in: tempDir)
        let tree = sut.buildFileTree(at: tempDir)
        XCTAssertTrue(tree.contains { $0.name == "appear.md" })
    }

    // MARK: - createDirectory

    func testCreateDirectory_createsDirectoryAtCorrectPath() throws {
        let url = try sut.createDirectory(named: "notes", in: tempDir)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists)
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testCreateDirectory_returnsURLWithCorrectName() throws {
        let url = try sut.createDirectory(named: "subfolder", in: tempDir)
        XCTAssertEqual(url.lastPathComponent, "subfolder")
    }

    func testCreateDirectory_appearsInBuildFileTree() throws {
        _ = try sut.createDirectory(named: "mydir", in: tempDir)
        let tree = sut.buildFileTree(at: tempDir)
        XCTAssertTrue(tree.contains { $0.name == "mydir" && $0.isDirectory })
    }

    // MARK: - delete

    func testDelete_removesFile() throws {
        let url = try sut.createFile(named: "to-delete.md", in: tempDir)
        try sut.delete(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDelete_removesDirectory() throws {
        let url = try sut.createDirectory(named: "to-delete-dir", in: tempDir)
        try sut.delete(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDelete_removesDirectoryWithContents() throws {
        let dirURL = try sut.createDirectory(named: "parent", in: tempDir)
        _ = try sut.createFile(named: "child.md", in: dirURL)
        try sut.delete(at: dirURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirURL.path))
    }

    func testDelete_fileDisappearsFromBuildFileTree() throws {
        let url = try sut.createFile(named: "vanish.md", in: tempDir)
        try sut.delete(at: url)
        let tree = sut.buildFileTree(at: tempDir)
        XCTAssertFalse(tree.contains { $0.name == "vanish.md" })
    }

    // MARK: - rename

    func testRename_renamesFile() throws {
        let url = try sut.createFile(named: "old.md", in: tempDir)
        let newURL = try sut.rename(at: url, to: "new.md")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
        XCTAssertEqual(newURL.lastPathComponent, "new.md")
    }

    func testRename_preservesFileContent() throws {
        let url = try sut.createFile(named: "original.md", in: tempDir)
        try sut.writeFileContent("# Hello", to: url)
        let newURL = try sut.rename(at: url, to: "renamed.md")
        let content = sut.readFileContent(at: newURL)
        XCTAssertEqual(content, "# Hello")
    }

    func testRename_renamesDirectory() throws {
        let url = try sut.createDirectory(named: "old-folder", in: tempDir)
        let newURL = try sut.rename(at: url, to: "new-folder")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func testRename_reflectedInBuildFileTree() throws {
        let url = try sut.createFile(named: "before.md", in: tempDir)
        _ = try sut.rename(at: url, to: "after.md")
        let tree = sut.buildFileTree(at: tempDir)
        XCTAssertFalse(tree.contains { $0.name == "before.md" })
        XCTAssertTrue(tree.contains { $0.name == "after.md" })
    }

    // MARK: - readFileContent / writeFileContent

    func testWriteAndReadFileContent_roundtrip() throws {
        let url = try sut.createFile(named: "content.md", in: tempDir)
        let text = "# Hello\n\nThis is a test.\n\n- item 1\n- item 2"
        try sut.writeFileContent(text, to: url)
        let result = sut.readFileContent(at: url)
        XCTAssertEqual(result, text)
    }

    func testReadFileContent_returnsNilForNonExistentFile() {
        let url = tempDir.appendingPathComponent("nonexistent.md")
        XCTAssertNil(sut.readFileContent(at: url))
    }

    func testWriteFileContent_overwritesExistingContent() throws {
        let url = try sut.createFile(named: "overwrite.md", in: tempDir)
        try sut.writeFileContent("first", to: url)
        try sut.writeFileContent("second", to: url)
        XCTAssertEqual(sut.readFileContent(at: url), "second")
    }

    // MARK: - move

    func testMove_movesFileToDestination() throws {
        let subDir = try sut.createDirectory(named: "dest", in: tempDir)
        let sourceURL = try sut.createFile(named: "source.md", in: tempDir)
        let destURL = subDir.appendingPathComponent("source.md")

        try sut.move(from: sourceURL, to: destURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
    }

    func testMove_preservesFileContent() throws {
        let subDir = try sut.createDirectory(named: "dest", in: tempDir)
        let sourceURL = try sut.createFile(named: "doc.md", in: tempDir)
        try sut.writeFileContent("# Hello", to: sourceURL)
        let destURL = subDir.appendingPathComponent("doc.md")

        try sut.move(from: sourceURL, to: destURL)

        XCTAssertEqual(sut.readFileContent(at: destURL), "# Hello")
    }

    func testMove_movesDirectoryWithContents() throws {
        let sourceDir = try sut.createDirectory(named: "mydir", in: tempDir)
        _ = try sut.createFile(named: "child.md", in: sourceDir)
        let destDir = try sut.createDirectory(named: "archive", in: tempDir)
        let destURL = destDir.appendingPathComponent("mydir")

        try sut.move(from: sourceDir, to: destURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.appendingPathComponent("child.md").path))
    }

    func testMove_reflectedInBuildFileTree() throws {
        let subDir = try sut.createDirectory(named: "sub", in: tempDir)
        let sourceURL = try sut.createFile(named: "travel.md", in: tempDir)
        let destURL = subDir.appendingPathComponent("travel.md")

        try sut.move(from: sourceURL, to: destURL)

        let tree = sut.buildFileTree(at: tempDir)
        // File should no longer appear at root level
        XCTAssertFalse(tree.contains { $0.name == "travel.md" && !$0.isDirectory })
        // File should appear inside sub/
        let subNode = tree.first { $0.name == "sub" }
        XCTAssertTrue(subNode?.children?.contains { $0.name == "travel.md" } ?? false)
    }
}
