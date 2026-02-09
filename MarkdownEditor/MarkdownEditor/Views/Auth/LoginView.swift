import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.richtext")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("MarkdownIsAllYouNeed")
                .font(.title.bold())

            Text("Use Markdown as your working language.\nWork anywhere, anytime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                isLoading = true
                Task {
                    await appState.login()
                    isLoading = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle")
                    }
                    Text("Sign in with GitHub")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
        .padding()
    }
}
