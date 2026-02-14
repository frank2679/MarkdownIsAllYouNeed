import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("Account") {
                if let user = appState.currentUser {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: user.avatarURL)) { image in
                                image.resizable()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name ?? user.login)
                                    .font(.body.weight(.medium))
                                Text("GitHub Connected")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading profile...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
            }

            Section("AI Settings") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Coming in MVP-1")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Storage") {
                HStack {
                    Text("Local Repos")
                    Spacer()
                    Text(localStorageSize())
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                                    HStack {
                                        Text("Version")
                                        Spacer()
                                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0")
                                            .foregroundStyle(.secondary)
                                    }            }
        }
        .navigationTitle("Settings")
    }

    private func localStorageSize() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reposDir = docs.appendingPathComponent("repos")
        guard let size = try? FileManager.default.allocatedSizeOfDirectory(at: reposDir) else {
            return "0 MB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        guard let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [],
            errorHandler: nil
        ) else {
            return 0
        }

        var totalSize: UInt64 = 0
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            totalSize += UInt64(resourceValues.totalFileAllocatedSize ?? 0)
        }
        return totalSize
    }
}
