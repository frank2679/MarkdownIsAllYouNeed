import SwiftUI

/// Reusable component showing icon + label for the current sync state.
struct SyncStateIndicator: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.caption)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .checking = state {
                ProgressView()
                    .controlSize(.mini)
            }
        }
    }

    private var iconName: String {
        switch state {
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .upToDate: return "checkmark.circle.fill"
        case .localChanges: return "pencil.circle.fill"
        case .remoteChanges: return "arrow.down.circle.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .unknown, .checking: return .secondary
        case .upToDate: return .green
        case .localChanges: return .orange
        case .remoteChanges: return .blue
        case .conflict: return .red
        case .error: return .red
        }
    }

    private var label: String {
        switch state {
        case .unknown: return "Unknown"
        case .checking: return "Checking..."
        case .upToDate: return "Up to date"
        case .localChanges(let count): return "\(count) change\(count == 1 ? "" : "s")"
        case .remoteChanges: return "Remote changes"
        case .conflict: return "Conflict"
        case .error(let msg): return msg
        }
    }
}
