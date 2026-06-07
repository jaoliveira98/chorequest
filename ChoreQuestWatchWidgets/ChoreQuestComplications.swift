import WidgetKit
import SwiftUI

/// watchOS complications so ChoreQuest can be added to a watch face as a tappable
/// shortcut (the small icons on the face). Tapping any of them launches the watch
/// app straight into the logging screen. These are launchers — they don't show
/// live data yet (that would need a shared App Group); the app opens instantly.
@main
struct ChoreQuestComplications: WidgetBundle {
    var body: some Widget {
        ChoreQuestLauncherComplication()
    }
}

struct LauncherEntry: TimelineEntry {
    let date: Date
}

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        // Static launcher — never needs to refresh.
        completion(Timeline(entries: [LauncherEntry(date: Date())], policy: .never))
    }
}

struct ChoreQuestLauncherComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChoreQuestLauncher", provider: LauncherProvider()) { _ in
            ComplicationView()
        }
        .configurationDisplayName("ChoreQuest")
        .description("Open ChoreQuest to log a chore.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

private struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("ChoreQuest", systemImage: "checklist")

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "checklist").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ChoreQuest").font(.headline)
                    Text("Tap to log").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

        case .accessoryCorner:
            Image(systemName: "checklist")
                .font(.title2)
                .widgetLabel("ChoreQuest")

        default: // .accessoryCircular
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checklist").font(.title3)
            }
        }
    }
}
