import SwiftUI

struct FileNodeRow: View {
    let node: FileNode
    let repoPath: URL
    let onSelect: (String, FileType) -> Void

    @State private var isExpanded = false

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let children = node.children {
                    ForEach(children) { child in
                        FileNodeRow(node: child, repoPath: repoPath, onSelect: onSelect)
                    }
                }
            } label: {
                Label(node.name, systemImage: isExpanded ? "folder.fill" : "folder")
                    .foregroundStyle(.primary)
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

                    // Change indicator dot
                    if let changeType = node.changeType {
                        Circle()
                            .fill(changeIndicatorColor(for: changeType))
                            .frame(width: 8, height: 8)
                    }

                    // Show file size for non-text files
                    if node.fileType == .image || node.fileType == .binary {
                        let size = FileManagerService.shared.fileSize(
                            at: repoPath.appendingPathComponent(node.path)
                        )
                        Text(formatSize(size))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
