import SwiftUI

/// One participant's standing: rank/medal, avatar, name, streak, and animated
/// point total.
struct LeaderboardRow: View {
    let rank: Int
    let participant: Participant
    let points: Int
    let streak: Int
    /// Top-3 medals only make sense when there are actually points on the board.
    let highlightTop: Bool

    private var medal: String? {
        guard highlightTop else { return nil }
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            rankBadge
            AvatarView(emoji: participant.emoji, colorHex: participant.colorHex, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(.headline)
                if streak > 1 {
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(points)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText(value: Double(points)))
                Text("pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var rankBadge: some View {
        Group {
            if let medal {
                Text(medal).font(.title2)
            } else {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32)
    }

    private var accessibilityText: Text {
        let streakPart = streak > 1 ? ", \(streak) day streak" : ""
        return Text("Rank \(rank), \(participant.name), \(points) points\(streakPart)")
    }
}

#Preview {
    List {
        LeaderboardRow(rank: 1, participant: Participant(name: "Alex", emoji: "🦸", colorHex: "#7C5CFF"), points: 24, streak: 4, highlightTop: true)
        LeaderboardRow(rank: 2, participant: Participant(name: "Sam", emoji: "🐼", colorHex: "#4FC3F7"), points: 18, streak: 1, highlightTop: true)
        LeaderboardRow(rank: 3, participant: Participant(name: "Jo", emoji: "🦊", colorHex: "#FF8A65"), points: 0, streak: 0, highlightTop: false)
    }
}
