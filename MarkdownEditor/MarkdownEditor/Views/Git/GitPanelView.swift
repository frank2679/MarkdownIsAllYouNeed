import SwiftUI

/// Main Git panel: branch info, sync state, changed files list, commit & push controls.
struct GitPanelView: View {
    let repo: Repository
    @EnvironmentObject var appState: AppState

    @State private var syncState: SyncState = .unknown
    @State private var changes: [FileChange] = []
    @State private var commitMessage = ""
    @State private var isLoading = false
    @State private var isPushing = false
    @State private var isPulling = false
    @State private var alertTitle = ""
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var selectedDiff: DiffNavigation?

    var body: some View {
        List {
            // Branch & Sync State
            Section {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.secondary)
                    Text(repo.defaultBranch)
                        .font(.headline)
                    Spacer()
                    SyncStateIndicator(state: syncState)
                }
            }

            // Actions
            Section {
                HStack(spacing: 12) {
                    Button {
                        Task { await performPull() }
                    } label: {
                        HStack {
                            if isPulling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text("Pull")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPulling || isPushing)

                    Button {
                        Task { await refreshStatus() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }

            // Changed Files
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Scanning changes...")
                        Spacer()
                    }
                } else if changes.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("No local changes")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                } else {
                    // Select All / Deselect All
                    HStack {
                        let selectedCount = changes.filter(\.isSelected).count
                        Text("\(selectedCount)/\(changes.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(selectedCount == changes.count ? "Deselect All" : "Select All") {
                            let shouldSelect = selectedCount < changes.count
                            for i in changes.indices {
                                changes[i].isSelected = shouldSelect
                            }
                        }
                        .font(.caption)
                    }

                    ForEach($changes) { $change in
                        ChangeFileRow(change: $change) {
                            if let diff = GitService.shared.diff(at: repo.localPath, for: change.path) {
                                selectedDiff = DiffNavigation(
                                    fileName: (change.path as NSString).lastPathComponent,
                                    diff: diff
                                )
                            }
                        }
                    }
                }
            } header: {
                Text("Changed Files")
            }

            // Commit & Push
            if !changes.isEmpty {
                Section {
                    TextField("Commit message", text: $commitMessage, axis: .vertical)
                        .lineLimit(2...5)

                    Button {
                        Task { await performCommitAndPush() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPushing {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Pushing...")
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Commit & Push")
                            }
                            Spacer()
                        }
                        .fontWeight(.semibold)
                    }
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || changes.filter(\.isSelected).isEmpty
                              || isPushing)
                } header: {
                    Text("Commit")
                }
            }
        }
        .navigationTitle("Git")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshStatus()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let alertMessage {
                Text(alertMessage)
            }
        }
        .alert("Conflict Detected", isPresented: $showConflictAlert) {
            Button("Pull & Merge", role: .none) {
                Task { await performPull() }
            }
            Button("Force Push", role: .destructive) {
                Task { await performForcePush() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
        .navigationDestination(item: $selectedDiff) { nav in
            DiffView(fileDiff: nav.diff, fileName: nav.fileName)
        }
    }

    // MARK: - Actions

    private func refreshStatus() async {
        isLoading = true
        syncState = .checking

        // Compute local changes
        let localChanges = GitService.shared.status(at: repo.localPath)
        var annotatedChanges = localChanges
        for i in annotatedChanges.indices {
            if let diff = GitService.shared.diff(at: repo.localPath, for: annotatedChanges[i].path) {
                annotatedChanges[i].additions = diff.additions
                annotatedChanges[i].deletions = diff.deletions
            }
        }
        changes = annotatedChanges

        // Check remote
        if let token = appState.authService.getAccessToken() {
            syncState = await GitService.shared.checkRemoteStatus(repo: repo, token: token)
        } else if !changes.isEmpty {
            syncState = .localChanges(count: changes.count)
        } else {
            syncState = .upToDate
        }

        isLoading = false
    }

    private func performPull() async {
        guard let token = appState.authService.getAccessToken() else {
            showError("Not authenticated")
            return
        }

        isPulling = true
        do {
            let result = try await GitService.shared.pull(repo: repo, token: token)
            switch result {
            case .upToDate:
                showInfo("Already up to date")
            case .updated(let count):
                showInfo("\(count) file\(count == 1 ? "" : "s") updated")
            case .conflicts(let files):
                showError("Conflicts in: \(files.joined(separator: ", "))")
            }
            await refreshStatus()
        } catch {
            showError(error.localizedDescription)
        }
        isPulling = false
    }

    private func performCommitAndPush() async {
        guard let token = appState.authService.getAccessToken() else {
            showError("Not authenticated")
            return
        }

        let selectedChanges = changes.filter(\.isSelected)
        guard !selectedChanges.isEmpty else { return }

        isPushing = true
        do {
            try await GitService.shared.commitAndPush(
                repo: repo,
                changes: selectedChanges,
                message: commitMessage,
                token: token
            )
            commitMessage = ""
            await refreshStatus()
        } catch let error as GitError {
            if case .conflictDetected(let msg) = error {
                conflictMessage = msg
                showConflictAlert = true
            } else {
                showError(error.localizedDescription)
            }
        } catch {
            showError(error.localizedDescription)
        }
        isPushing = false
    }

    private func performForcePush() async {
        guard let token = appState.authService.getAccessToken() else {
            showError("Not authenticated")
            return
        }

        let selectedChanges = changes.filter(\.isSelected)
        guard !selectedChanges.isEmpty else {
            showError("No changes selected")
            return
        }
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Commit message is required")
            return
        }

        isPushing = true
        do {
            try await GitService.shared.commitAndPush(
                repo: repo,
                changes: selectedChanges,
                message: commitMessage,
                token: token,
                force: true
            )
            commitMessage = ""
            await refreshStatus()
        } catch {
            showError(error.localizedDescription)
        }
        isPushing = false
    }

    private func showInfo(_ message: String) {
        alertTitle = "Git"
        alertMessage = message
        showAlert = true
    }

    private func showError(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Navigation Model

struct DiffNavigation: Identifiable, Hashable {
    let id = UUID()
    let fileName: String
    let diff: FileDiff

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiffNavigation, rhs: DiffNavigation) -> Bool {
        lhs.id == rhs.id
    }
}
