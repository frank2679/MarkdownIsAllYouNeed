import SwiftUI

struct ProfileView: View {
    let user: UserProfile

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: user.avatarURL)) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                        Text(user.name ?? user.login)
                            .font(.title2.bold())

                        Text("@\(user.login)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Repositories") {
                HStack {
                    Text("Public")
                    Spacer()
                    Text("\(user.publicRepos)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Private")
                    Spacer()
                    Text("\(user.privateRepos)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
