import SwiftUI

struct GitPanelView: View {
    let repo: Repository
    @EnvironmentObject var appState: AppState

    @State private var changes: [GitFileChange] = []
    @State private var commitMessage = ""
    @State private var isCommitting = false
    @State private var isPulling = false
    @State private var commitProgress: String?
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showConflictAlert = false

    var selectedCount: Int {
        changes.filter { $0.isSelected }.count
    }

    var body: some View {
        List {
            // Status section
            Section {
                HStack {
                    Image(systemName: changes.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(changes.isEmpty ? .green : .orange)
                    Text(repo.defaultBranch)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(changes.isEmpty ? "Up to date" : "\(changes.count) changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Pull / Refresh
            Section {
                Button {
                    Task { await pullRepo() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Pull Latest")
                        Spacer()
                        if isPulling {
                            ProgressView()
                        }
                    }
                }
                .disabled(isPulling || isCommitting)
            }

            // Changes list
            if !changes.isEmpty {
                Section("Changed Files (\(selectedCount) selected)") {
                    ForEach($changes) { $change in
                        HStack(spacing: 12) {
                            Button {
                                change.isSelected.toggle()
                            } label: {
                                Image(systemName: change.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(change.isSelected ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "doc.text")
                                .foregroundStyle(changeColor(change.status))
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text((change.path as NSString).lastPathComponent)
                                    .font(.subheadline)
                                Text(change.path)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(change.status.label)
                                .font(.caption2)
                                .foregroundStyle(changeColor(change.status))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(changeColor(change.status).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Commit section
                Section("Commit") {
                    TextField("Commit message", text: $commitMessage, axis: .vertical)
                        .lineLimit(1...4)

                    Button {
                        Task { await commitAndPush() }
                    } label: {
                        HStack {
                            Spacer()
                            if isCommitting {
                                ProgressView()
                                    .tint(.white)
                                if let progress = commitProgress {
                                    Text(progress)
                                        .font(.subheadline)
                                }
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Commit & Push")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(commitMessage.isEmpty || selectedCount == 0 || isCommitting)
                    .listRowBackground(
                        (commitMessage.isEmpty || selectedCount == 0) ? Color(.systemGray5) : Color.blue
                    )
                    .foregroundStyle(
                        (commitMessage.isEmpty || selectedCount == 0) ? .secondary : .white
                    )

                    Button {
                        Task { await commitOnly() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Commit Only (no push)")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(commitMessage.isEmpty || selectedCount == 0 || isCommitting)
                }
            }

            // Error
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Git")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadChanges()
        }
        .refreshable {
            loadChanges()
        }
        .overlay(alignment: .bottom) {
            if showSuccess {
                Text("Pushed successfully")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Remote Has Changes", isPresented: $showConflictAlert) {
            Button("Pull & Merge") {
                Task { await pullRepo() }
            }
            Button("Force Push", role: .destructive) {
                // Not implemented in MVP-0
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The remote branch has newer commits. Pull the latest changes before pushing.")
        }
    }

    private func loadChanges() {
        changes = GitCommitService.shared.detectChanges(repo: repo)
    }

    private func commitAndPush() async {
        guard let token = appState.authService.getAccessToken() else { return }
        isCommitting = true
        errorMessage = nil

        do {
            try await GitCommitService.shared.commitAndPush(
                repo: repo,
                changes: changes,
                message: commitMessage,
                token: token
            ) { status in
                Task { @MainActor in commitProgress = status }
            }

            commitMessage = ""
            loadChanges()

            withAnimation { showSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showSuccess = false }
            }
        } catch let error as GitError {
            if case .pushFailed(let msg) = error, msg == "CONFLICT" {
                showConflictAlert = true
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isCommitting = false
        commitProgress = nil
    }

    private func commitOnly() async {
        // In MVP-0 with GitHub API, commit always pushes.
        // With SwiftGit2 this would be a local-only commit.
        // For now, just save snapshot to mark files as committed locally.
        GitCommitService.shared.saveSnapshot(repo: repo)
        commitMessage = ""
        loadChanges()
    }

    private func pullRepo() async {
        guard let token = appState.authService.getAccessToken() else { return }
        isPulling = true
        errorMessage = nil

        do {
            // Re-clone via API (MVP-0 pull = re-download)
            try await GitService.shared.cloneViaAPI(repo, token: token) { _ in }
            loadChanges()
        } catch {
            errorMessage = error.localizedDescription
        }

        isPulling = false
    }

    private func changeColor(_ status: GitFileChange.ChangeType) -> Color {
        switch status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        }
    }
}
