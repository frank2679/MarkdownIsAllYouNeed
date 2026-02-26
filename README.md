# MarkdownIsAllYouNeed

> 使用 Markdown 作为你的工作语言，随时随地在 iPhone 上编辑 GitHub 仓库中的 Markdown 文件。

![Version](https://img.shields.io/badge/version-0.5.3-blue)
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

| Version | Description |
|---------|-------------|
| 0.1.0 | MVP — end-to-end GitHub login → clone → edit → commit → push |
| 0.2.0 | Editor enhancements, Git diff, file operations |
| 0.3.0 | New file / folder, rename, delete, unit tests |
| 0.4.0 | Lazy `.originals/` caching — ~50% storage reduction |
| 0.5.0 | Notion-style editing UX, favorites, git discard |
| 0.5.1 | Move To, PDF preview |
| 0.5.2 | Keyboard toolbar (undo/redo, formatting), font size, share menu |
| **0.5.3** | **Toggle fix, foreground reload, Share as Gist / Export HTML — current** |
| 0.6.0 | Android |
| 1.0.0 | App Store release |

See [DESIGN.md](docs/DESIGN.md) for the full technical design.
See [User Guide](docs/user-guide.md) for login instructions and usage.

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