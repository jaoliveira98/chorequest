import WidgetKit
import SwiftUI

/// Points earned today — household total on small, per-person on medium.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChoreQuestToday", provider: Provider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Points earned today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        if family == .systemSmall { small } else { medium }
    }

    private var header: some View {
        Label("Today", systemImage: "checkmark.seal.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            Text("\(snapshot.todayTotal)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(snapshot.todayTotal == 1 ? "point today" : "points today")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        let people = snapshot.standings.sorted { $0.todayPoints > $1.todayPoints }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                header
                Spacer()
                Text("\(snapshot.todayTotal) total").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            if people.isEmpty || people.allSatisfy({ $0.todayPoints == 0 }) {
                Spacer(minLength: 0)
                Text("Nothing logged yet today").font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(people.prefix(3)) { standing in
                    HStack(spacing: 8) {
                        AvatarView(emoji: standing.emoji, colorHex: standing.colorHex, size: 26)
                        Text(standing.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("+\(standing.todayPoints)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Color(hex: standing.colorHex))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
