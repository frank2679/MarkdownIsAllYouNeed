import SwiftUI

/// Scrollable diff viewer with hunk headers, line numbers, and colored +/- lines.
struct DiffView: View {
    let fileDiff: FileDiff
    let fileName: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // File header
                HStack {
                    Text(fileName)
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("+\(fileDiff.additions)")
                            .foregroundStyle(.green)
                        Text("-\(fileDiff.deletions)")
                            .foregroundStyle(.red)
                    }
                    .font(.subheadline.monospaced())
                }
                .padding()
                .background(Color(.systemGroupedBackground))

                ForEach(Array(fileDiff.hunks.enumerated()), id: \.offset) { _, hunk in
                    // Hunk header
                    Text(hunk.header)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))

                    // Diff lines
                    ForEach(hunk.lines) { line in
                        DiffLineView(line: line)
                    }
                }
            }
        }
        .navigationTitle("Diff")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Single diff line with line numbers and colored background.
private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Old line number
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .frame(width: 40, alignment: .trailing)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            // New line number
            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .frame(width: 40, alignment: .trailing)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            // Prefix
            Text(prefix)
                .frame(width: 16, alignment: .center)
                .font(.caption.monospaced())
                .foregroundStyle(prefixColor)

            // Content
            Text(line.content)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    private var prefix: String {
        switch line.type {
        case .context: return " "
        case .addition: return "+"
        case .deletion: return "-"
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .context: return .secondary
        case .addition: return .green
        case .deletion: return .red
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .context: return .clear
        case .addition: return .green.opacity(0.1)
        case .deletion: return .red.opacity(0.1)
        }
    }
}
