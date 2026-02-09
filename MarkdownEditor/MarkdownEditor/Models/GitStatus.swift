import Foundation

struct GitFileChange: Identifiable {
    let id = UUID()
    let path: String
    let status: ChangeType
    var isSelected: Bool = true

    enum ChangeType: String {
        case added = "A"
        case modified = "M"
        case deleted = "D"

        var label: String {
            switch self {
            case .added: return "Added"
            case .modified: return "Modified"
            case .deleted: return "Deleted"
            }
        }

        var color: String {
            switch self {
            case .added: return "green"
            case .modified: return "orange"
            case .deleted: return "red"
            }
        }
    }
}

enum SyncStatus {
    case upToDate
    case localChanges(count: Int)
    case needsPull
    case conflict
    case unknown

    var label: String {
        switch self {
        case .upToDate: return "Up to date"
        case .localChanges(let count): return "\(count) changes"
        case .needsPull: return "Needs pull"
        case .conflict: return "Conflict"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .upToDate: return "checkmark.circle.fill"
        case .localChanges: return "exclamationmark.circle.fill"
        case .needsPull: return "arrow.down.circle.fill"
        case .conflict: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .upToDate: return "green"
        case .localChanges: return "orange"
        case .needsPull: return "blue"
        case .conflict: return "red"
        case .unknown: return "secondary"
        }
    }
}
