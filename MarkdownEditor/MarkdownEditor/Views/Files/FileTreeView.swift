import SwiftUI

struct FileTreeView: View {
    let repo: Repository
    @EnvironmentObject var appState: AppState
    @State private var fileTree: [FileNode] = []
    @State private var recentFiles: [String] = []
    @State private var isLoading = true
    @State private var selectedFile: FileSelection?

    var body: some View {
        List {
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
        .task {
            loadFileTree()
            loadRecentFiles()
        }
        .navigationDestination(item: $selectedFile) { selection in
            switch selection.fileType {
            case .markdown:
                TextFileView(
                    fileURL: repo.localPath.appendingPathComponent(selection.path),
                    fileName: (selection.path as NSString).lastPathComponent,
                    isMarkdown: true
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
    }

    private func loadFileTree() {
        fileTree = FileManagerService.shared.buildFileTree(at: repo.localPath)
        isLoading = false
    }

    private func loadRecentFiles() {
        let key = "recentFiles-\(repo.fullName)"
        recentFiles = UserDefaults.standard.stringArray(forKey: key) ?? []
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
