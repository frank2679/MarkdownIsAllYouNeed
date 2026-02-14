import SwiftUI

struct MarkdownEditorScreen: View {
    let fileURL: URL
    let fileName: String

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var isDirty = false
    @State private var currentMarkdown = ""
    @State private var isSaving = false
    @State private var showSavedToast = false
    @State private var coordinatorRef: MarkdownEditorView.Coordinator?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            EditorToolbar { format in
                coordinatorRef?.applyFormat(format)
            }

            // WYSIWYG Editor
            MarkdownEditorView(
                fileURL: fileURL,
                fileName: fileName,
                isDirty: $isDirty,
                onContentChanged: { markdown in
                    currentMarkdown = markdown
                },
                onCoordinatorReady: { coordinator in
                    coordinatorRef = coordinator
                }
            )
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveFile()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .foregroundStyle(isDirty ? .blue : .secondary)
                    }
                }
                .disabled(!isDirty || isSaving)
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
    }

    private func saveFile() {
        guard !currentMarkdown.isEmpty else { return }
        isSaving = true

        do {
            try FileManagerService.shared.writeFileContent(currentMarkdown, to: fileURL)
            isDirty = false
            appState.saveLastEditedFile(fileURL.path)

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
