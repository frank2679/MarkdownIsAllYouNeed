import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var repos: [Repository] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                        RepoRowView(repo: repo, isCloned: true)
                    }
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
                        RepoRowView(repo: repo, isCloned: false)
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
}
