# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-02-20

### Added
- Unit test target `MarkdownEditorTests` with 47 test cases covering `DiffEngine`, `FileTypeDetector`, and `FileManagerService`.
- New File / New Folder: tap the `+` menu in the file browser toolbar to create a file or folder at the repository root. Files without an extension automatically get `.md`.
- Subdirectory creation: long-press any folder in the file tree to open a context menu with "New File" and "New Folder" options scoped to that directory.
- Rename: long-press any file or folder → "Rename" → enter the new name in an alert.
- Delete: long-press any file or folder → "Delete" → confirm in a dialog.
- Newly created Markdown or text files are immediately opened in the editor.

### Fixed
- New file/folder creation now correctly targets the selected subdirectory. Previously, all items were created in the repository root due to a SwiftUI state-capture timing issue with `.sheet(isPresented:)`. Switched to `.sheet(item:)` with an `Identifiable` context struct so the target directory is immutably baked into the sheet at trigger time.

## [0.2.0] - 2026-02-15

### Added
- Markdown table rendering and alignment support in the editor.
- Support for viewing and tracking hidden files (like `.gitignore`).
- Custom Markdown-themed app icon.

### Fixed
- Robust local file status detection using standardized paths, fixing false "deleted" status on iOS.
- Excessive line spacing in code blocks and tables by improving paragraph wrapping logic.
- Safe Markdown content transfer to WebView using JSON encoding.

## [0.1.0] - 2026-02-14

MVP-0 release: end-to-end workflow from GitHub login to editing and pushing Markdown files.

### Added
- GitHub OAuth login via ASWebAuthenticationSession
- Token persistence in iOS Keychain
- User profile display
- Repository listing (user repos from GitHub API)
- Repository cloning to local sandbox (via GitHub API file download)
- Parallel file downloads for faster cloning
- File tree browsing with type detection (Markdown, text, image, binary)
- Milkdown-based WYSIWYG Markdown editor in WKWebView
- Native ↔ JS bridge with versioned JSON protocol
- Native editor toolbar (headings, bold, italic, lists, code, quote, links)
- Keyboard-aware toolbar positioning
- File saving to local storage
- Git status display
- Commit (select files + write message)
- Push to remote
- Pull (detect remote changes)

### Fixed
- File loading from local repository
- Editor toolbar visibility and interaction
- Simulator login flow issues

### Changed
- Parallelized repo file downloads for improved clone performance

### Documentation
- Product Requirements Document (PRD)
- Technical Design Document (DESIGN.md)
- AI Chat feature specification and UI wireframes

[Unreleased]: https://github.com/nicekate/MarkdownIsAllYouNeed/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/nicekate/MarkdownIsAllYouNeed/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nicekate/MarkdownIsAllYouNeed/releases/tag/v0.1.0
