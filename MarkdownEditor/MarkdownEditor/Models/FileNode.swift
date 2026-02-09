import Foundation

struct FileNode: Identifiable, Comparable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let fileType: FileType
    var children: [FileNode]?
    var isExpanded: Bool = false

    static func < (lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

enum FileType {
    case markdown
    case text
    case image
    case binary

    var iconName: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .text: return "doc.text"
        case .image: return "photo"
        case .binary: return "doc"
        }
    }

    var iconColor: String {
        switch self {
        case .markdown: return "blue"
        case .text: return "primary"
        case .image: return "green"
        case .binary: return "secondary"
        }
    }
}
