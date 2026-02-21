import SwiftUI

// MARK: - New Item Context

struct NewItemContext: Identifiable {
    let id = UUID()
    let parentURL: URL
    let startAsDirectory: Bool
    /// Human-readable location label shown in the sheet ("/" for root, folder name otherwise).
    let locationLabel: String
}

// MARK: - FileTreeView

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

    @State private var favorites: [String] = []

    // New item: parentURL is baked into context, no timing issues
    @State private var newItemContext: NewItemContext? = nil

    // Rename
    @State private var showRenameAlert = false
    @State private var renameNode: FileNode? = nil
    @State private var renameURL: URL? = nil
    @State private var newName = ""

    // Delete
    @State private var showDeleteConfirm = false
    @State private var deleteNode: FileNode? = nil
    @State private var deleteURL: URL? = nil

    var body: some View {
        List {
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

            if !favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favorites, id: \.self) { path in
                        if let node = findNode(path: path, in: fileTree) {
                            // Directory favorite: render as full expandable FileNodeRow
                            FileNodeRow(
                                node: node,
                                repoPath: repo.localPath,
                                onSelect: { p, ft in openFile(path: p, fileType: ft) },
                                onAction: { action in handleFileAction(action) },
                                isFavorite: true
                            )
                        } else {
                            // File favorite (or node not yet loaded): simple button
                            let name = (path as NSString).lastPathComponent
                            let fileType = FileTypeDetector.detect(filename: name)
                            Button {
                                openFile(path: path, fileType: fileType)
                            } label: {
                                Label(name, systemImage: fileType.iconName)
                                    .foregroundStyle(.primary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    toggleFavorite(path: path)
                                } label: {
                                    Label("Remove", systemImage: "star.slash")
                                }
                            }
                        }
                    }
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
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if fileTree.isEmpty {
                    Text("No files found").foregroundStyle(.secondary)
                } else {
                    ForEach(fileTree) { node in
                        FileNodeRow(
                            node: node,
                            repoPath: repo.localPath,
                            onSelect: { path, fileType in openFile(path: path, fileType: fileType) },
                            onAction: { action in handleFileAction(action) },
                            isFavorite: favorites.contains(node.path)
                        )
                    }
                }
            }
        }
        .navigationTitle(repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Menu {
                    Button {
                        newItemContext = makeContext(parentURL: repo.localPath, isDirectory: false)
                    } label: {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    Button {
                        newItemContext = makeContext(parentURL: repo.localPath, isDirectory: true)
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("New", systemImage: "plus")
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
                                .font(.caption2).fontWeight(.bold)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.orange).foregroundStyle(.white)
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
            loadFavorites()
            await loadSyncState(changes: changes)
        }
        .sheet(item: $newItemContext) { context in
            NewItemSheet(context: context) { isDir, name, url in
                createNewItem(name: name, isDirectory: isDir, in: url)
            }
        }
        .alert("Rename", isPresented: $showRenameAlert) {
            TextField("New name", text: $newName).autocorrectionDisabled()
            Button("Rename") { performRename() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for \"\(renameNode?.name ?? "")\"")
        }
        .confirmationDialog(
            "Delete \"\(deleteNode?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if deleteNode?.isDirectory == true {
                Text("This will permanently delete the folder and all its contents.")
            } else {
                Text("This will permanently delete this file.")
            }
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

    // MARK: - Context Factory

    private func makeContext(parentURL: URL, isDirectory: Bool) -> NewItemContext {
        let label = parentURL == repo.localPath
            ? "/"
            : String(parentURL.path.dropFirst(repo.localPath.path.count + 1))
        return NewItemContext(parentURL: parentURL, startAsDirectory: isDirectory, locationLabel: label)
    }

    // MARK: - File Action Handling

    private func handleFileAction(_ action: FileAction) {
        switch action {
        case .createFile(let dir):
            newItemContext = makeContext(parentURL: dir, isDirectory: false)
        case .createDirectory(let dir):
            newItemContext = makeContext(parentURL: dir, isDirectory: true)
        case .rename(let node, let url):
            renameNode = node
            renameURL = url
            newName = node.name
            showRenameAlert = true
        case .delete(let node, let url):
            deleteNode = node
            deleteURL = url
            showDeleteConfirm = true
        case .move(let sourcePath, let dir):
            moveItem(from: sourcePath, toDirectory: dir)
        case .toggleFavorite(let path):
            toggleFavorite(path: path)
        }
    }

    private func createNewItem(name: String, isDirectory: Bool, in parentURL: URL) {
        do {
            if isDirectory {
                _ = try FileManagerService.shared.createDirectory(named: name, in: parentURL)
                refreshTree()
            } else {
                let fileURL = try FileManagerService.shared.createFile(named: name, in: parentURL)
                refreshTree()
                let fileType = FileTypeDetector.detect(filename: name)
                let relativePath = String(fileURL.path.dropFirst(repo.localPath.path.count + 1))
                if fileType == .markdown || fileType == .text {
                    openFile(path: relativePath, fileType: fileType)
                }
            }
        } catch {}
    }

    private func moveItem(from sourcePath: String, toDirectory destinationURL: URL) {
        let sourceURL = repo.localPath.appendingPathComponent(sourcePath)
        let destURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        // Prevent moving to same location or into itself
        guard sourceURL.standardizedFileURL != destURL.standardizedFileURL,
              !destinationURL.path.hasPrefix(sourceURL.path + "/") else { return }
        do {
            try FileManagerService.shared.move(from: sourceURL, to: destURL)
            refreshTree()
        } catch {}
    }

    private func performRename() {
        guard let url = renameURL,
              !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            _ = try FileManagerService.shared.rename(at: url, to: newName.trimmingCharacters(in: .whitespaces))
            refreshTree()
        } catch {}
    }

    private func performDelete() {
        guard let url = deleteURL else { return }
        do {
            try FileManagerService.shared.delete(at: url)
            // Remove deleted item (and any children) from recent files
            let relativePath = String(url.path.dropFirst(repo.localPath.path.count + 1))
            recentFiles.removeAll { $0 == relativePath || $0.hasPrefix(relativePath + "/") }
            UserDefaults.standard.set(recentFiles, forKey: "recentFiles-\(repo.fullName)")
            refreshTree()
        } catch {}
    }

    private func refreshTree() {
        let changes = GitService.shared.status(at: repo.localPath)
        loadFileTree(changes: changes)
    }

    // MARK: - Helpers

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

    private func findNode(path: String, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.path == path { return node }
            if node.isDirectory, let children = node.children {
                if let found = findNode(path: path, in: children) { return found }
            }
        }
        return nil
    }

    private func loadFavorites() {
        let key = "favorites-\(repo.fullName)"
        favorites = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private func toggleFavorite(path: String) {
        let key = "favorites-\(repo.fullName)"
        if favorites.contains(path) {
            favorites.removeAll { $0 == path }
        } else {
            favorites.append(path)
        }
        UserDefaults.standard.set(favorites, forKey: key)
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
        var recents = recentFiles
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        if recents.count > 5 { recents = Array(recents.prefix(5)) }
        recentFiles = recents
        UserDefaults.standard.set(recents, forKey: "recentFiles-\(repo.fullName)")
        appState.saveLastEditedFile("\(repo.fullName)/\(path)")
        selectedFile = FileSelection(path: path, fileType: fileType)
    }
}

// MARK: - New Item Sheet

struct NewItemSheet: View {
    let context: NewItemContext
    let onCreate: (Bool, String, URL) -> Void

    @State private var name = ""
    @State private var isDirectory: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool

    init(context: NewItemContext, onCreate: @escaping (Bool, String, URL) -> Void) {
        self.context = context
        self.onCreate = onCreate
        self._isDirectory = State(initialValue: context.startAsDirectory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isDirectory) {
                        Label("File", systemImage: "doc").tag(false)
                        Label("Folder", systemImage: "folder").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField(
                        isDirectory ? "Folder name" : "Filename (e.g. note.md)",
                        text: $name
                    )
                    .focused($nameFieldFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                }

                Section {
                    HStack {
                        Text("Location")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(context.locationLabel)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if !isDirectory && !name.trimmingCharacters(in: .whitespaces).isEmpty
                    && (name as NSString).pathExtension.isEmpty {
                    Section {
                        Text("Will be created as \"\(name.trimmingCharacters(in: .whitespaces)).md\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isDirectory ? "New Folder" : "New File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let finalName = resolvedName
                        let parentURL = context.parentURL
                        dismiss()
                        onCreate(isDirectory, finalName, parentURL)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
    }

    private var resolvedName: String {
        var n = name.trimmingCharacters(in: .whitespaces)
        if !isDirectory && !n.isEmpty && (n as NSString).pathExtension.isEmpty {
            n += ".md"
        }
        return n
    }
}

// MARK: - FileSelection

struct FileSelection: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let fileType: FileType

    func hash(into hasher: inout Hasher) { hasher.combine(path) }
    static func == (lhs: FileSelection, rhs: FileSelection) -> Bool { lhs.path == rhs.path }
}
