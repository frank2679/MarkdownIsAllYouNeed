import SwiftUI

private struct LinkedFile: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
}

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
    @State private var linkedFile: LinkedFile?

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
                    // setMode("preview") is now chained in loadFileContent() after the
                    // bridge is ready, so this call is intentionally left as a no-op.
                },
                onModeChangeRequested: { mode in
                    switchMode(to: mode)
                },
                onInternalLinkClicked: { relativePath in
                    let resolved = fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(relativePath)
                        .standardized
                    if FileManager.default.fileExists(atPath: resolved.path) {
                        linkedFile = LinkedFile(url: resolved)
                    }
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
        .sheet(item: $linkedFile) { file in
            NavigationStack {
                MarkdownEditorScreen(fileURL: file.url, fileName: file.name)
                    .environmentObject(appState)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { linkedFile = nil }
                        }
                    }
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
