import SwiftUI

/// A compact grid of curated emoji to choose from. Keeps avatar/chore creation
/// fast and consistent without wrestling the system emoji keyboard.
struct EmojiPicker: View {
    @Binding var selection: String
    let options: [String]

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(options, id: \.self) { emoji in
                Button {
                    selection = emoji
                } label: {
                    Text(emoji)
                        .font(.title2)
                        .frame(width: 46, height: 46)
                        .background(
                            selection == emoji ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    selection == emoji ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(emoji))
                .accessibilityAddTraits(selection == emoji ? [.isSelected] : [])
            }
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State private var sel = "🐼"
        var body: some View { EmojiPicker(selection: $sel, options: Palette.avatarEmojis).padding() }
    }
    return Wrapper()
}
