import SwiftUI

enum FileAction {
    case createFile(inDirectory: URL)
    case createDirectory(inDirectory: URL)
    case rename(node: FileNode, url: URL)
    case delete(node: FileNode, url: URL)
    case move(sourcePath: String, toDirectory: URL)
    case toggleFavorite(path: String)
}

struct FileNodeRow: View {
    let node: FileNode
    let repoPath: URL
    let onSelect: (String, FileType) -> Void
    var onAction: ((FileAction) -> Void)? = nil
    var isFavorite: Bool = false

    @State private var isExpanded = false
    @State private var isDropTargeted = false

    private var nodeURL: URL {
        repoPath.appendingPathComponent(node.path)
    }

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileNodeRow(
                            node: child,
                            repoPath: repoPath,
                            onSelect: onSelect,
                            onAction: onAction
                        )
                    }
                }
            } label: {
                // Context menu lives on the label so it targets THIS row,
                // not a parent DisclosureGroup when nested in a List.
                HStack {
                    Label(node.name, systemImage: isExpanded ? "folder.fill" : "folder")
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(
                    isDropTargeted
                        ? RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5))
                        : nil
                )
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        onAction?(.createFile(inDirectory: nodeURL))
                    } label: {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    Button {
                        onAction?(.createDirectory(inDirectory: nodeURL))
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Divider()
                    Button {
                        onAction?(.toggleFavorite(path: node.path))
                    } label: {
                        Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                              systemImage: isFavorite ? "star.slash" : "star")
                    }
                    Divider()
                    Button {
                        onAction?(.rename(node: node, url: nodeURL))
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onAction?(.delete(node: node, url: nodeURL))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .draggable(node.path)
                .dropDestination(for: String.self) { items, _ in
                    guard let sourcePath = items.first,
                          sourcePath != node.path,
                          !node.path.hasPrefix(sourcePath + "/") else { return false }
                    onAction?(.move(sourcePath: sourcePath, toDirectory: nodeURL))
                    return true
                } isTargeted: { targeted in
                    isDropTargeted = targeted
                }
            }
        } else {
            Button {
                onSelect(node.path, node.fileType)
            } label: {
                HStack {
                    Label {
                        Text(node.name)
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: node.fileType.iconName)
                            .foregroundStyle(iconColor)
                    }

                    Spacer()

                    if let changeType = node.changeType {
                        Circle()
                            .fill(changeIndicatorColor(for: changeType))
                            .frame(width: 8, height: 8)
                    }

                    if node.fileType == .image || node.fileType == .binary {
                        Text(formatSize(FileManagerService.shared.fileSize(
                            at: repoPath.appendingPathComponent(node.path)
                        )))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .contextMenu {
                Button {
                    onAction?(.toggleFavorite(path: node.path))
                } label: {
                    Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                          systemImage: isFavorite ? "star.slash" : "star")
                }
                Divider()
                Button {
                    onAction?(.rename(node: node, url: nodeURL))
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onAction?(.delete(node: node, url: nodeURL))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .draggable(node.path)
        }
    }

    private var iconColor: Color {
        switch node.fileType {
        case .markdown: return .blue
        case .text: return .primary
        case .image: return .green
        case .binary: return .secondary
        }
    }

    private func changeIndicatorColor(for type: FileChangeType) -> Color {
        switch type {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
