import SwiftUI

/// Scrollable diff viewer with hunk headers, line numbers, and colored +/- lines.
struct DiffView: View {
    let fileDiff: FileDiff
    let fileName: String
    @State private var wrapLines = false

    var body: some View {
        diffContent
            .navigationTitle("Diff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        wrapLines.toggle()
                    } label: {
                        Image(systemName: wrapLines ? "arrow.left.and.right" : "text.justify.left")
                    }
                }
            }
    }

    @ViewBuilder
    private var diffContent: some View {
        if wrapLines {
            ScrollView(.vertical) { lineStack }
        } else {
            ScrollView([.horizontal, .vertical]) { lineStack }
        }
    }

    private var lineStack: some View {
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
                    DiffLineView(line: line, wrapLines: wrapLines)
                }
            }
        }
    }
}

/// Single diff line with line numbers and colored background.
private struct DiffLineView: View {
    let line: DiffLine
    let wrapLines: Bool

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
                .lineLimit(wrapLines ? nil : 1)
                .fixedSize(horizontal: !wrapLines, vertical: false)

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
