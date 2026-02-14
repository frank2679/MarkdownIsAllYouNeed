import SwiftUI

struct FileTreeView: View {
    let repo: Repository
    @EnvironmentObject var appState: AppState
    @State private var fileTree: [FileNode] = []
    @State private var recentFiles: [String] = []
    @State private var isLoading = true
    @State private var selectedFile: FileSelection?
    @State private var syncState: SyncState = .unknown
    @State private var changeCount = 0
    @State private var showGitPanel = false

    var body: some View {
        List {
            // Sync state header
            Section {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.secondary)
                    Text(repo.defaultBranch)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    SyncStateIndicator(state: syncState)
                }
            }

            if !recentFiles.isEmpty {
                Section("Recent") {
                    ForEach(recentFiles, id: \.self) { path in
                        let name = (path as NSString).lastPathComponent
                        let fileType = FileTypeDetector.detect(filename: name)
                        Button {
                            openFile(path: path, fileType: fileType)
                        } label: {
                            Label(name, systemImage: fileType.iconName)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Section("Files") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if fileTree.isEmpty {
                    Text("No files found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(fileTree) { node in
                        FileNodeRow(node: node, repoPath: repo.localPath) { path, fileType in
                            openFile(path: path, fileType: fileType)
                        }
                    }
                }
            }
        }
        .navigationTitle(repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    // New file placeholder
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                }

                Spacer()

                Button {
                    showGitPanel = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Git")
                        if changeCount > 0 {
                            Text("\(changeCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .task {
            let changes = GitService.shared.status(at: repo.localPath)
            loadFileTree(changes: changes)
            loadRecentFiles()
            await loadSyncState(changes: changes)
        }
        .navigationDestination(item: $selectedFile) { selection in
            switch selection.fileType {
            case .markdown:
                MarkdownEditorScreen(
                    fileURL: repo.localPath.appendingPathComponent(selection.path),
                    fileName: (selection.path as NSString).lastPathComponent
                )
            case .text:
                TextFileView(
                    fileURL: repo.localPath.appendingPathComponent(selection.path),
                    fileName: (selection.path as NSString).lastPathComponent,
                    isMarkdown: false
                )
            case .image:
                ImagePreviewView(
                    fileURL: repo.localPath.appendingPathComponent(selection.path),
                    fileName: (selection.path as NSString).lastPathComponent
                )
            case .binary:
                BinaryFileView(
                    fileURL: repo.localPath.appendingPathComponent(selection.path),
                    fileName: (selection.path as NSString).lastPathComponent
                )
            }
        }
        .navigationDestination(isPresented: $showGitPanel) {
            GitPanelView(repo: repo)
        }
    }

    private func loadFileTree(changes: [FileChange]) {
        if changes.isEmpty {
            fileTree = FileManagerService.shared.buildFileTree(at: repo.localPath)
        } else {
            fileTree = FileManagerService.shared.buildFileTree(at: repo.localPath, changes: changes)
        }
        isLoading = false
    }

    private func loadRecentFiles() {
        let key = "recentFiles-\(repo.fullName)"
        recentFiles = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private func loadSyncState(changes: [FileChange]) async {
        syncState = .checking
        changeCount = changes.count

        if let token = appState.authService.getAccessToken() {
            syncState = await GitService.shared.checkRemoteStatus(repo: repo, token: token)
        } else if !changes.isEmpty {
            syncState = .localChanges(count: changes.count)
        } else {
            syncState = .upToDate
        }
    }

    private func openFile(path: String, fileType: FileType) {
        // Track recent files
        var recents = recentFiles
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        if recents.count > 5 { recents = Array(recents.prefix(5)) }
        recentFiles = recents
        UserDefaults.standard.set(recents, forKey: "recentFiles-\(repo.fullName)")

        // Track last edited
        appState.saveLastEditedFile("\(repo.fullName)/\(path)")

        selectedFile = FileSelection(path: path, fileType: fileType)
    }
}

struct FileSelection: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let fileType: FileType

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: FileSelection, rhs: FileSelection) -> Bool {
        lhs.path == rhs.path
    }
}
