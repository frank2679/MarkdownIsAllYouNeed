# MarkdownIsAllYouNeed

> 使用 Markdown 作为你的工作语言，随时随地在 iPhone 上编辑 GitHub 仓库中的 Markdown 文件。

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **GitHub Integration** — OAuth login, repository listing, clone, pull, commit, push
- **WYSIWYG Editor** — Milkdown-based Markdown editor with live preview
- **Native Toolbar** — Headings, bold, italic, lists, code blocks, links, and more
- **File Browser** — Tree view with Markdown / text / image / binary detection
- **Offline Editing** — Edit locally, sync when ready
- **Git Workflow** — Status, diff, commit, push, pull — all from your phone

## Screenshots

*Coming soon*

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 5.9+
- A GitHub account (for repository access)

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/nicekate/MarkdownIsAllYouNeed.git
   ```

2. Configure GitHub OAuth credentials:
   ```bash
   cp Config/Debug.xcconfig.example Config/Debug.xcconfig
   # Edit Config/Debug.xcconfig and fill in your GitHub OAuth App credentials
   ```

3. Open `MarkdownEditor/MarkdownEditor.xcodeproj` in Xcode.

4. Build and run on a simulator or device (iOS 17+).

## Roadmap

| Version | Milestone | Description |
|---------|-----------|-------------|
| **0.1.0** | **MVP-0 (Phase 1–4)** | **End-to-end workflow — current release** |
| 0.2.0 | MVP-1 (Phase 5–6) | Editor enhancements + Git enhancements |
| 0.3.0 | MVP-1 (Phase 7) | AI Chat integration |
| 0.4.0 | MVP-1 (Phase 8) | Polish & refinements |
| 1.0.0 | App Store | First public release |
| 2.0.0 | V2 | iPad support |

See [DESIGN.md](docs/DESIGN.md) for the full technical design and phased development plan.

## Project Structure

```
MarkdownEditor/
├── App/                # App entry point & global state
├── Views/              # SwiftUI views (Auth, Repos, Files, Editor, Git, Settings)
├── Services/           # Core services (Auth, Git, GitHub API, File management)
├── Models/             # Data models (Repository, FileNode, GitStatus, etc.)
├── Utilities/          # Helpers (Keychain, FileType detection, Constants)
└── Resources/          # Assets & bundled web resources (Milkdown editor)
```

## Contributing

This project is in early development. Contributions and feedback are welcome — please open an issue first to discuss changes.

## License

MIT