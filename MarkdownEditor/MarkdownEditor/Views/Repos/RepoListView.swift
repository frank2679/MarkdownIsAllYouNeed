import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var repos: [Repository] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cloneTarget: Repository?
    @State private var cloneProgress: String?
    @State private var isCloning = false

    var clonedRepos: [Repository] {
        repos.filter { $0.isClonedLocally }
    }

    var remoteRepos: [Repository] {
        repos.filter { !$0.isClonedLocally }
    }

    var filteredCloned: [Repository] {
        if searchText.isEmpty { return clonedRepos }
        return clonedRepos.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredRemote: [Repository] {
        if searchText.isEmpty { return remoteRepos }
        return remoteRepos.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if !filteredCloned.isEmpty {
                Section("Cloned") {
                    ForEach(filteredCloned) { repo in
                        NavigationLink(value: repo) {
                            RepoRowView(repo: repo, isCloned: true)
                        }
                    }
                    .onDelete(perform: deleteClonedRepos)
                }
            }

            Section("All Repositories") {
                if isLoading && repos.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    ForEach(filteredRemote) { repo in
                        Button {
                            cloneTarget = repo
                        } label: {
                            RepoRowView(repo: repo, isCloned: false)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Repos")
        .navigationDestination(for: Repository.self) { repo in
            FileTreeView(repo: repo)
        }
        .searchable(text: $searchText, prompt: "Search repos...")
        .refreshable {
            await loadRepos()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await loadRepos() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if repos.isEmpty {
                await loadRepos()
            }
        }
        .alert("Clone Repository?", isPresented: .init(
            get: { cloneTarget != nil && !isCloning },
            set: { if !$0 { cloneTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { cloneTarget = nil }
            Button("Clone") {
                if let repo = cloneTarget {
                    Task { await cloneRepo(repo) }
                }
            }
        } message: {
            if let repo = cloneTarget {
                Text("Clone \(repo.fullName) to local storage?")
            }
        }
        .overlay {
            if isCloning {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(cloneProgress ?? "Cloning...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 200, height: 120)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func loadRepos() async {
        guard let token = appState.authService.getAccessToken() else { return }
        isLoading = true
        errorMessage = nil

        let provider = GitHubProvider(token: token)
        do {
            repos = try await provider.fetchRepos(page: 1)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cloneRepo(_ repo: Repository) async {
        guard let token = appState.authService.getAccessToken() else { return }
        isCloning = true
        cloneProgress = "Starting..."

        do {
            try await GitService.shared.cloneViaAPI(repo, token: token) { status in
                Task { @MainActor in
                    cloneProgress = status
                }
            }
            await loadRepos()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCloning = false
        cloneTarget = nil
    }

    private func deleteClonedRepos(at offsets: IndexSet) {
        for index in offsets {
            let repo = filteredCloned[index]
            try? GitService.shared.deleteLocalRepo(at: repo.localPath)
        }
        Task { await loadRepos() }
    }
}
