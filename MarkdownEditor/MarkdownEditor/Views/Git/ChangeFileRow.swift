import SwiftUI

/// Row displaying a changed file with checkbox, path, change type badge, and diff stats.
struct ChangeFileRow: View {
    @Binding var change: FileChange
    let onTapDiff: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Selection checkbox
            Button {
                change.isSelected.toggle()
            } label: {
                Image(systemName: change.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(change.isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            // File path + change type
            Button {
                onTapDiff()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((change.path as NSString).lastPathComponent)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if change.path.contains("/") {
                            Text((change.path as NSString).deletingLastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Diff stats
                    if change.additions > 0 || change.deletions > 0 {
                        HStack(spacing: 4) {
                            if change.additions > 0 {
                                Text("+\(change.additions)")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            if change.deletions > 0 {
                                Text("-\(change.deletions)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    // Change type badge
                    Text(change.changeType.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.15))
                        .foregroundStyle(badgeColor)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private var badgeColor: Color {
        switch change.changeType {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        }
    }
}
