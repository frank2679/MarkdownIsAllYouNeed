import SwiftUI

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
}
