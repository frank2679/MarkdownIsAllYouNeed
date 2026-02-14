import SwiftUI

/// Placeholder text editor for MVP-0. Will be replaced by Milkdown WYSIWYG in Phase 3.
struct TextFileView: View {
    let fileURL: URL
    let fileName: String
    let isMarkdown: Bool

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var isSaving = false
    @State private var showSavedToast = false

    var isDirty: Bool { content != originalContent }

    var body: some View {
        VStack(spacing: 0) {
            if isMarkdown {
                // Phase 3 will replace this with WKWebView + Milkdown
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isMarkdown {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(isDirty ? .blue : .secondary)
                        }
                    }
                    .disabled(!isDirty || isSaving)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showSavedToast {
                Text("Saved")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            loadContent()
        }
    }

    private func loadContent() {
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        print("[TextFile] Loading: \(fileURL.path)")
        print("[TextFile] File exists: \(fileExists)")
        content = FileManagerService.shared.readFileContent(at: fileURL) ?? ""
        print("[TextFile] Content length: \(content.count)")
        originalContent = content
    }

    private func save() {
        isSaving = true
        do {
            try FileManagerService.shared.writeFileContent(content, to: fileURL)
            originalContent = content
            withAnimation {
                showSavedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showSavedToast = false
                }
            }
        } catch {
            print("Save failed: \(error)")
        }
        isSaving = false
    }
}
