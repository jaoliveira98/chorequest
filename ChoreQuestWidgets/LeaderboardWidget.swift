import WidgetKit
import SwiftUI

/// This week's standings — leader on the small size, top 3 with medals on medium.
struct LeaderboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChoreQuestLeaderboard", provider: Provider()) { entry in
            LeaderboardWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Leaderboard")
        .description("This week's points standings.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct LeaderboardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    // If the app hasn't run since a previous week, the stored week points are stale —
    // show the empty state rather than last week's numbers.
    private var isThisWeek: Bool {
        Calendar.current.isDate(snapshot.generatedAt, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var body: some View {
        if snapshot.standings.isEmpty || !isThisWeek {
            empty
        } else if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    private var header: some View {
        Label("This week", systemImage: "trophy.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "trophy").font(.title2).foregroundStyle(.secondary)
            Text("No points yet").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var small: some View {
        let leader = snapshot.standings[0]
        return VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            AvatarView(emoji: leader.emoji, colorHex: leader.colorHex, size: 40)
            Text(leader.name).font(.caption).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(leader.weekPoints)")
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(Color(hex: leader.colorHex))
                Text("pts").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(Array(snapshot.standings.prefix(3).enumerated()), id: \.element.id) { index, standing in
                HStack(spacing: 8) {
                    Text(["🥇", "🥈", "🥉"][safe: index] ?? "\(index + 1)").font(.callout)
                    AvatarView(emoji: standing.emoji, colorHex: standing.colorHex, size: 26)
                    Text(standing.name).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("\(standing.weekPoints)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(Color(hex: standing.colorHex))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
