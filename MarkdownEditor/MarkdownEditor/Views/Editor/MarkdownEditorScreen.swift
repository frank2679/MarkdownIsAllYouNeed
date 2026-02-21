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
    @State private var isEditMode = false

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !fileExists {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("File not found. Try re-cloning the repository.")
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.orange)
            }

            // Toolbar — only visible in edit mode
            if isEditMode {
                EditorToolbar { format in
                    coordinatorRef?.applyFormat(format)
                }
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
                    // Start in preview mode
                    coordinator.setMode("preview")
                },
                onModeChangeRequested: { mode in
                    switchMode(to: mode)
                }
            )
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    Button("Done") {
                        switchMode(to: "preview")
                    }
                    .fontWeight(.semibold)
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
        .onDisappear {
            // Auto-save when navigating away from the editor
            if isDirty {
                saveFile(showToast: false)
            }
        }
    }

    private func switchMode(to mode: String) {
        if mode == "preview" && isEditMode && isDirty {
            saveFile(showToast: true)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditMode = (mode == "edit")
        }
        coordinatorRef?.setMode(mode)
    }

    private func saveFile(showToast: Bool) {
        guard !currentMarkdown.isEmpty || isDirty else { return }
        isSaving = true

        let contentToSave = currentMarkdown.isEmpty
            ? (FileManagerService.shared.readFileContent(at: fileURL) ?? "")
            : currentMarkdown

        do {
            try FileManagerService.shared.writeFileContent(contentToSave, to: fileURL)
            isDirty = false
            appState.saveLastEditedFile(fileURL.path)

            if showToast {
                withAnimation {
                    showSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSavedToast = false
                    }
                }
            }
        } catch {
            print("Save failed: \(error)")
        }

        isSaving = false
    }
}
