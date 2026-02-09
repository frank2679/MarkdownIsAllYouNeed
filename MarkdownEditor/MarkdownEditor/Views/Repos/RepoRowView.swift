import SwiftUI

struct RepoRowView: View {
    let repo: Repository
    let isCloned: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCloned ? "folder.fill" : "folder")
                .foregroundStyle(isCloned ? .blue : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(repo.owner.login)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if repo.fork {
                        Text("Fork")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if repo.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if repo.stargazersCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star")
                            Text("\(repo.stargazersCount)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isCloned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
