import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let fileURL: URL
    let fileName: String

    var body: some View {
        PDFKitView(url: fileURL)
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - UIViewRepresentable wrapper

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
