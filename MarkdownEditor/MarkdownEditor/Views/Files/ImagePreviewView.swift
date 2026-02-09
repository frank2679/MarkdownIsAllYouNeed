import SwiftUI

struct ImagePreviewView: View {
    let fileURL: URL
    let fileName: String

    @State private var imageSize: String = ""

    var body: some View {
        VStack(spacing: 12) {
            if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }

                Text("\(Int(uiImage.size.width)) x \(Int(uiImage.size.height))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Unable to load image")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            let size = FileManagerService.shared.fileSize(at: fileURL)
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
