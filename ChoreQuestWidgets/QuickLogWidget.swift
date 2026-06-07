import WidgetKit
import SwiftUI
import AppIntents

/// Configure whose chores this widget logs (long-press → Edit Widget).
struct QuickLogConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Quick Log"
    static var description = IntentDescription("Pick whose chores this widget logs.")

    @Parameter(title: "Person") var person: ParticipantEntity?
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let person: ParticipantEntity?
}

struct QuickLogProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: Date(), snapshot: .sample, person: nil)
    }

    func snapshot(for configuration: QuickLogConfigIntent, in context: Context) async -> QuickLogEntry {
        let loaded = WidgetStore.load()
        let snap = (context.isPreview || loaded.chores.isEmpty) ? .sample : loaded
        return QuickLogEntry(date: Date(), snapshot: snap, person: configuration.person)
    }

    func timeline(for configuration: QuickLogConfigIntent, in context: Context) async -> Timeline<QuickLogEntry> {
        let entry = QuickLogEntry(date: Date(), snapshot: WidgetStore.load(), person: configuration.person)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ChoreQuestQuickLog",
                               intent: QuickLogConfigIntent.self,
                               provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Log")
        .description("Tap a chore to log it instantly. Long-press → Edit Widget to choose who.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct QuickLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuickLogEntry

    private var maxChores: Int { family == .systemLarge ? 16 : 8 }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        if let person = entry.person {
            if entry.snapshot.chores.isEmpty {
                message("No chores yet", "Add chores in ChoreQuest.")
            } else {
                configured(for: person)
            }
        } else {
            message("Choose who", "Long-press → Edit Widget → pick a person.")
        }
    }

    private func configured(for person: ParticipantEntity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AvatarView(emoji: person.emoji, colorHex: person.colorHex, size: 22)
                Text(person.name).font(.caption.weight(.semibold)).lineLimit(1)
                Spacer()
                Text("Tap to log").font(.caption2).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(entry.snapshot.chores.prefix(maxChores)) { chore in
                    Button(intent: QuickLogIntent(choreID: chore.id, participantID: person.id)) {
                        VStack(spacing: 1) {
                            Text(chore.emoji).font(.title3)
                            Text(chore.name).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color(hex: chore.colorHex ?? "#7C5CFF").opacity(0.18),
                                    in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func message(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "hand.tap.fill").font(.title3).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
