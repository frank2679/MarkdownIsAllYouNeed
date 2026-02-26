import SwiftUI
import UIKit

// MARK: - Font Size

enum MarkdownFontSize: Int, CaseIterable {
    case xs = 12
    case s  = 14
    case m  = 16
    case l  = 18
    case xl = 20

    var label: String {
        switch self {
        case .xs: return "XS"
        case .s:  return "S"
        case .m:  return "M"
        case .l:  return "L"
        case .xl: return "XL"
        }
    }
}

// MARK: - LinkedFile

private struct LinkedFile: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
}

// MARK: - MarkdownEditorScreen

struct MarkdownEditorScreen: View {
    let fileURL: URL
    let fileName: String
    var repo: Repository? = nil
    var onFileMoved: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var isDirty = false
    @State private var currentMarkdown = ""
    @State private var isSaving = false
    @State private var showSavedToast = false
    @State private var coordinatorRef: MarkdownEditorView.Coordinator?
    @State private var isEditMode = false
    @State private var linkedFile: LinkedFile?

    // Favorite
    @State private var isFavorite = false

    // Move To
    @State private var moveToContext: MoveToContext? = nil
    @State private var fileTreeForMove: [FileNode] = []

    // Share
    @State private var isCreatingGist = false
    @State private var gistError: String? = nil
    @State private var showGistError = false

    // Font Size — global preference, persisted via AppStorage
    @AppStorage("markdownFontSize") private var fontSizeRaw: Int = MarkdownFontSize.m.rawValue

    private var fontSize: MarkdownFontSize {
        MarkdownFontSize(rawValue: fontSizeRaw) ?? .m
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    private var relativePath: String? {
        guard let repo else { return nil }
        let repoPath = repo.localPath.path
        let filePath = fileURL.path
        guard filePath.hasPrefix(repoPath + "/") else { return nil }
        return String(filePath.dropFirst(repoPath.count + 1))
    }

    private var githubBlobURL: URL? {
        guard let repo, let path = relativePath else { return nil }
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "https://github.com/\(repo.fullName)/blob/\(repo.defaultBranch)/\(encodedPath)")
    }

    var body: some View {
        VStack(spacing: 0) {
            if !fileExists {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("File not found. Try re-cloning the repository.")
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.orange)
            }

            // WYSIWYG Editor (EditorToolbar is now inputAccessoryView above keyboard)
            MarkdownEditorView(
                fileURL: fileURL,
                fileName: fileName,
                isDirty: $isDirty,
                onContentChanged: { markdown in
                    currentMarkdown = markdown
                },
                onCoordinatorReady: { coordinator in
                    coordinatorRef = coordinator
                },
                onModeChangeRequested: { mode in
                    switchMode(to: mode)
                },
                onInternalLinkClicked: { relativePath in
                    let resolved = fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(relativePath)
                        .standardized
                    if FileManager.default.fileExists(atPath: resolved.path) {
                        linkedFile = LinkedFile(url: resolved)
                    }
                },
                fontSize: fontSizeRaw
            )
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Favorite / Move To — only when repo context is available
                    if let repo, let path = relativePath {
                        Button {
                            toggleFavorite(path: path, repoFullName: repo.fullName)
                        } label: {
                            Label(
                                isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: isFavorite ? "star.slash" : "star"
                            )
                        }

                        Button {
                            showMoveTo(repo: repo)
                        } label: {
                            Label("Move To...", systemImage: "folder")
                        }

                        Divider()
                    }

                    // Share
                    if let url = githubBlobURL {
                        Button {
                            presentShareSheet(items: [url])
                        } label: {
                            Label("Share Link", systemImage: "link")
                        }
                    }

                    Button {
                        shareAsGist()
                    } label: {
                        if isCreatingGist {
                            Label("Creating Gist…", systemImage: "hourglass")
                        } else {
                            Label("Share as Gist", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                    .disabled(isCreatingGist)

                    Button {
                        exportHTML()
                    } label: {
                        Label("Export HTML", systemImage: "safari")
                    }

                    Divider()

                    // Font Size submenu
                    Menu {
                        ForEach(MarkdownFontSize.allCases, id: \.rawValue) { size in
                            Button {
                                fontSizeRaw = size.rawValue
                                coordinatorRef?.setFontSize(size.rawValue)
                            } label: {
                                if fontSize == size {
                                    Label(size.label, systemImage: "checkmark")
                                } else {
                                    Text(size.label)
                                }
                            }
                        }
                    } label: {
                        Label("Font Size", systemImage: "textformat.size")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text("Saved")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if let repo, let path = relativePath {
                loadFavoriteState(path: path, repoFullName: repo.fullName)
            }
        }
        .onDisappear {
            if isDirty {
                saveFile(showToast: false)
            }
        }
        // Keyboard dismiss = Done: auto-save + switch to preview
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in
            if isEditMode {
                switchMode(to: "preview")
            }
        }
        // Reload content if WebView was killed by iOS after long backgrounding
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        )) { _ in
            coordinatorRef?.reloadContentIfEmpty(fallbackMarkdown: currentMarkdown, fontSize: fontSizeRaw)
        }
        .alert("Gist Error", isPresented: $showGistError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(gistError ?? "Failed to create Gist")
        }
        .sheet(item: $linkedFile) { file in
            NavigationStack {
                MarkdownEditorScreen(fileURL: file.url, fileName: file.name)
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { linkedFile = nil }
                        }
                    }
            }
        }
        .sheet(item: $moveToContext) { context in
            MoveToSheet(
                context: context,
                repoPath: repo!.localPath,
                fileTree: fileTreeForMove
            ) { destination in
                performMove(to: destination)
            }
        }
    }

    // MARK: - Mode

    private func switchMode(to mode: String) {
        if mode == "preview" && isEditMode && isDirty {
            saveFile(showToast: true)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditMode = (mode == "edit")
        }
        coordinatorRef?.setMode(mode)
    }

    // MARK: - Save

    private func saveFile(showToast: Bool) {
        guard !currentMarkdown.isEmpty || isDirty else { return }
        isSaving = true

        let contentToSave = currentMarkdown.isEmpty
            ? (FileManagerService.shared.readFileContent(at: fileURL) ?? "")
            : currentMarkdown

        do {
            try FileManagerService.shared.writeFileContent(contentToSave, to: fileURL)
            isDirty = false
            appState.saveLastEditedFile(fileURL.path)

            if showToast {
                withAnimation {
                    showSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSavedToast = false
                    }
                }
            }
        } catch {
            print("Save failed: \(error)")
        }

        isSaving = false
    }

    // MARK: - Favorite

    private func loadFavoriteState(path: String, repoFullName: String) {
        let key = "favorites-\(repoFullName)"
        let favorites = UserDefaults.standard.stringArray(forKey: key) ?? []
        isFavorite = favorites.contains(path)
    }

    private func toggleFavorite(path: String, repoFullName: String) {
        let key = "favorites-\(repoFullName)"
        var favorites = UserDefaults.standard.stringArray(forKey: key) ?? []
        if isFavorite {
            favorites.removeAll { $0 == path }
        } else {
            favorites.append(path)
        }
        UserDefaults.standard.set(favorites, forKey: key)
        isFavorite.toggle()
    }

    // MARK: - Move To

    private func showMoveTo(repo: Repository) {
        guard let path = relativePath else { return }
        if isDirty { saveFile(showToast: false) }
        fileTreeForMove = FileManagerService.shared.buildFileTree(at: repo.localPath)
        let node = FileNode(
            name: fileName,
            path: path,
            isDirectory: false,
            fileType: .markdown
        )
        moveToContext = MoveToContext(node: node)
    }

    private func performMove(to destination: URL) {
        let destURL = destination.appendingPathComponent(fileURL.lastPathComponent)
        guard fileURL.standardizedFileURL != destURL.standardizedFileURL,
              !destination.path.hasPrefix(fileURL.path + "/") else { return }
        do {
            try FileManagerService.shared.move(from: fileURL, to: destURL)
            onFileMoved?()
            dismiss()
        } catch {
            print("Move failed: \(error)")
        }
    }

    // MARK: - Share

    private func presentShareSheet(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        topVC.present(activityVC, animated: true)
    }

    private func shareAsGist() {
        guard let token = appState.authService.getAccessToken() else { return }
        isCreatingGist = true
        let content = currentMarkdown.isEmpty
            ? (FileManagerService.shared.readFileContent(at: fileURL) ?? "")
            : currentMarkdown
        Task {
            do {
                let url = try await GitHubProvider(token: token).createGist(fileName: fileName, content: content)
                await MainActor.run {
                    isCreatingGist = false
                    presentShareSheet(items: [url])
                }
            } catch {
                await MainActor.run {
                    isCreatingGist = false
                    gistError = error.localizedDescription
                    showGistError = true
                }
            }
        }
    }

    private func exportHTML() {
        coordinatorRef?.getRenderedHTML { [self] innerHTML in
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(fileName)</title>
            <style>
            body { font-family: -apple-system, sans-serif; font-size: 16px; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 0 20px; color: #1a1a1a; }
            h1, h2, h3 { font-weight: 600; margin: 1.2em 0 0.6em; }
            p { margin: 0.8em 0; }
            code { font-family: "SF Mono", Menlo, monospace; font-size: 0.9em; background: #f5f5f5; padding: 2px 6px; border-radius: 4px; }
            pre { background: #f5f5f5; padding: 12px 16px; border-radius: 8px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            blockquote { border-left: 3px solid #d0d0d0; padding-left: 16px; margin: 1em 0; color: #666; }
            img { max-width: 100%; height: auto; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #e0e0e0; padding: 8px 12px; text-align: left; }
            th { background: #f5f5f5; font-weight: 600; }
            a { color: #0066cc; }
            </style>
            </head>
            <body>
            \(innerHTML ?? "")
            </body>
            </html>
            """
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName.replacingOccurrences(of: ".md", with: ""))
                .appendingPathExtension("html")
            do {
                try html.write(to: tempURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.presentShareSheet(items: [tempURL])
                }
            } catch {
                print("Export HTML failed: \(error)")
            }
        }
    }
}
