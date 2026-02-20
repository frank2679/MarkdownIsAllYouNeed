import XCTest
@testable import MarkdownEditor

final class DiffEngineTests: XCTestCase {

    // MARK: - No Changes

    func testDiff_emptyFiles_producesNoDiff() {
        let diff = DiffEngine.diff(original: "", modified: "", path: "test.md")
        XCTAssertTrue(diff.hunks.isEmpty)
        XCTAssertEqual(diff.additions, 0)
        XCTAssertEqual(diff.deletions, 0)
    }

    func testDiff_sameContent_producesNoDiff() {
        let content = "# Hello\n\nSome paragraph.\n\n- item 1\n- item 2"
        let diff = DiffEngine.diff(original: content, modified: content, path: "test.md")
        XCTAssertTrue(diff.hunks.isEmpty)
        XCTAssertEqual(diff.additions, 0)
        XCTAssertEqual(diff.deletions, 0)
    }

    // MARK: - Additions

    func testDiff_addedLineAtEnd_detectsAddition() {
        let original = "line1\nline2"
        let modified  = "line1\nline2\nline3"
        let diff = DiffEngine.diff(original: original, modified: modified, path: "test.md")

        XCTAssertFalse(diff.hunks.isEmpty)
        XCTAssertEqual(diff.additions, 1)
        XCTAssertEqual(diff.deletions, 0)

        let addedLines = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }
        XCTAssertTrue(addedLines.contains { $0.content == "line3" })
    }

    func testDiff_oldEmptyNewHasContent_allLinesAdded() {
        // Note: "".components(separatedBy:"\n") = [""], so DiffEngine sees 1 old empty line.
        // The result contains additions for each content line.
        let modified = "line1\nline2"
        let diff = DiffEngine.diff(original: "", modified: modified, path: "test.md")

        let addedLines = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }
        XCTAssertTrue(addedLines.contains { $0.content == "line1" })
        XCTAssertTrue(addedLines.contains { $0.content == "line2" })
        XCTAssertEqual(diff.additions, 2)
    }

    // MARK: - Deletions

    func testDiff_removedLine_detectsDeletion() {
        let original = "line1\nline2\nline3"
        let modified  = "line1\nline3"
        let diff = DiffEngine.diff(original: original, modified: modified, path: "test.md")

        XCTAssertFalse(diff.hunks.isEmpty)
        XCTAssertEqual(diff.additions, 0)
        XCTAssertEqual(diff.deletions, 1)

        let removedLines = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }
        XCTAssertTrue(removedLines.contains { $0.content == "line2" })
    }

    func testDiff_newEmptyOldHasContent_allLinesRemoved() {
        // Note: "".components(separatedBy:"\n") = [""], so DiffEngine sees 1 new empty line.
        // The result contains deletions for each original content line.
        let original = "line1\nline2"
        let diff = DiffEngine.diff(original: original, modified: "", path: "test.md")

        let removedLines = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }
        XCTAssertTrue(removedLines.contains { $0.content == "line1" })
        XCTAssertTrue(removedLines.contains { $0.content == "line2" })
        XCTAssertEqual(diff.deletions, 2)
    }

    // MARK: - Modifications

    func testDiff_modifiedLine_detectsBothAddAndRemove() {
        let original = "Hello world"
        let modified  = "Hello Swift"
        let diff = DiffEngine.diff(original: original, modified: modified, path: "test.md")

        XCTAssertFalse(diff.hunks.isEmpty)
        XCTAssertGreaterThan(diff.additions, 0)
        XCTAssertGreaterThan(diff.deletions, 0)
    }

    // MARK: - Metadata

    func testDiff_filePath_storedInResult() {
        let diff = DiffEngine.diff(original: "a", modified: "b", path: "notes/test.md")
        XCTAssertEqual(diff.originalPath, "notes/test.md")
        XCTAssertEqual(diff.modifiedPath, "notes/test.md")
    }

    func testDiff_contextLines_appearsAroundChanges() {
        let original = "ctx1\nctx2\nchange\nctx3\nctx4"
        let modified  = "ctx1\nctx2\nnewline\nctx3\nctx4"
        let diff = DiffEngine.diff(original: original, modified: modified, path: "test.md", contextLines: 1)

        let contextLines = diff.hunks.flatMap(\.lines).filter { $0.type == .context }
        XCTAssertFalse(contextLines.isEmpty)
    }
}
