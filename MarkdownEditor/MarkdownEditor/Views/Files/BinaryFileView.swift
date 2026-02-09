import SwiftUI

struct BinaryFileView: View {
    let fileURL: URL
    let fileName: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(fileName)
                .font(.headline)

            let size = FileManagerService.shared.fileSize(at: fileURL)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Binary file - preview not available")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
