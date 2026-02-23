import XCTest
@testable import MarkdownEditor

final class FileTypeDetectorTests: XCTestCase {

    // MARK: - Markdown

    func testDetect_mdExtension_returnsMarkdown() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "README.md"), .markdown)
    }

    func testDetect_markdownExtension_returnsMarkdown() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "notes.markdown"), .markdown)
    }

    func testDetect_uppercaseMdExtension_returnsMarkdown() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "NOTES.MD"), .markdown)
    }

    // MARK: - Text

    func testDetect_txtExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "file.txt"), .text)
    }

    func testDetect_swiftExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "code.swift"), .text)
    }

    func testDetect_shExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "script.sh"), .text)
    }

    func testDetect_jsonExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "config.json"), .text)
    }

    func testDetect_yamlExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "config.yaml"), .text)
    }

    func testDetect_cssExtension_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "style.css"), .text)
    }

    // MARK: - Image

    func testDetect_pngExtension_returnsImage() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "photo.png"), .image)
    }

    func testDetect_jpgExtension_returnsImage() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "photo.jpg"), .image)
    }

    func testDetect_jpegExtension_returnsImage() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "photo.jpeg"), .image)
    }

    func testDetect_gifExtension_returnsImage() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "anim.gif"), .image)
    }

    func testDetect_svgExtension_returnsImage() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "icon.svg"), .image)
    }

    // MARK: - PDF

    func testDetect_pdfExtension_returnsPdf() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "document.pdf"), .pdf)
    }

    func testDetect_uppercasePdfExtension_returnsPdf() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "report.PDF"), .pdf)
    }

    // MARK: - Binary

    func testDetect_zipExtension_returnsBinary() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "archive.zip"), .binary)
    }

    // MARK: - Known text filenames (no extension)

    func testDetect_gitignoreHiddenFile_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: ".gitignore"), .text)
    }

    func testDetect_envHiddenFile_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: ".env"), .text)
    }

    func testDetect_makefile_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "Makefile"), .text)
    }

    func testDetect_dockerfile_returnsText() {
        XCTAssertEqual(FileTypeDetector.detect(filename: "Dockerfile"), .text)
    }
}
