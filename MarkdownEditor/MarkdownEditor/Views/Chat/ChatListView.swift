import SwiftUI

struct ChatListView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("AI Chat")
                .font(.title2.bold())
            Text("Coming in MVP-1")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .navigationTitle("AI Chat")
    }
}
