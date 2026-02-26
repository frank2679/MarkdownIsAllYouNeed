import SwiftUI

struct EditorToolbar: View {
    let onFormat: (String) -> Void
    var onDismissKeyboard: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    toolbarButton(nil, format: "undo", icon: "arrow.uturn.backward")
                    toolbarButton(nil, format: "redo", icon: "arrow.uturn.forward")

                    Divider().frame(height: 20)

                    toolbarButton("H1", format: "heading1", icon: nil)
                    toolbarButton("H2", format: "heading2", icon: nil)

                    Divider().frame(height: 20)

                    toolbarButton(nil, format: "bold", icon: "bold")
                    toolbarButton(nil, format: "italic", icon: "italic")
                    toolbarButton(nil, format: "strikethrough", icon: "strikethrough")

                    Divider().frame(height: 20)

                    toolbarButton(nil, format: "unorderedList", icon: "list.bullet")
                    toolbarButton(nil, format: "orderedList", icon: "list.number")

                    Divider().frame(height: 20)

                    toolbarButton(nil, format: "code", icon: "chevron.left.forwardslash.chevron.right")
                    toolbarButton(nil, format: "codeBlock", icon: "text.alignleft")
                    toolbarButton(nil, format: "blockquote", icon: "text.quote")
                    toolbarButton(nil, format: "horizontalRule", icon: "minus")

                    Divider().frame(height: 20)

                    toolbarButton(nil, format: "link", icon: "link")
                }
                .padding(.horizontal, 8)
            }

            // Pinned dismiss-keyboard button
            Divider().frame(height: 20)
            Button {
                onDismissKeyboard?()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 14))
                    .frame(width: 40, height: 32)
            }
            .foregroundStyle(.secondary)
            .padding(.trailing, 4)
        }
        .frame(height: 40)
        .background(.bar)
    }

    @ViewBuilder
    private func toolbarButton(_ text: String?, format: String, icon: String?) -> some View {
        Button {
            onFormat(format)
        } label: {
            if let text = text {
                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(width: 36, height: 32)
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 36, height: 32)
            }
        }
        .foregroundStyle(.primary)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
