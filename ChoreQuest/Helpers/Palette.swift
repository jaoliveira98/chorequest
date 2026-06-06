import Foundation

/// Curated presets used by the editors so adding people and chores stays fast
/// and the app looks consistent (no free-form color/emoji entry needed).
enum Palette {
    /// Friendly, high-contrast swatches that read well in light and dark mode.
    static let colors: [String] = [
        "#7C5CFF", "#4FC3F7", "#4DD0E1", "#4DB6AC",
        "#81C784", "#FFB74D", "#FF8A65", "#F06292",
        "#BA68C8", "#9575CD", "#A1887F", "#90A4AE"
    ]

    /// Emoji suggestions for participant avatars.
    static let avatarEmojis: [String] = [
        "🙂", "😎", "🤩", "🦸", "🦹", "🧑‍🚀", "🧙", "🦄",
        "🐱", "🐶", "🦊", "🐼", "🐵", "🐸", "🐯", "🐰",
        "👧", "👦", "👩", "👨", "🧑", "👵", "👴", "👶"
    ]

    /// Emoji suggestions for chores.
    static let choreEmojis: [String] = [
        "🍽️", "🗑️", "🧹", "🧺", "🍳", "🧸", "🚽", "🛒",
        "🐾", "🛏️", "🧽", "🪣", "🧼", "🚿", "🪟", "🌱",
        "🚗", "📦", "💡", "🔧", "🍴", "🪥", "👕", "🧯"
    ]

    static let defaultColor = colors[0]
}
