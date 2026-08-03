import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct NextPrayerEntry: TimelineEntry {
    let date: Date
    let name: String
    let time: String
    let prayerDate: Date?
    let dayLabel: String
    let location: String
    let hasData: Bool
    /// Shown instead of a time when `hasData` is false.
    let hint: String

    static func placeholder(at date: Date = Date()) -> NextPrayerEntry {
        NextPrayerEntry(
            date: date,
            name: "Maghrib",
            time: "7:30 pm",
            prayerDate: date.addingTimeInterval(3600),
            dayLabel: "Today",
            location: "Karbala",
            hasData: true,
            hint: ""
        )
    }

    static func empty(at date: Date = Date(), hint: String) -> NextPrayerEntry {
        NextPrayerEntry(
            date: date,
            name: "Open app",
            time: "--:--",
            prayerDate: nil,
            dayLabel: "",
            location: "",
            hasData: false,
            hint: hint
        )
    }

    /// Time without the meridiem, for the tight circular/corner families.
    var compactTime: String {
        let trimmed = time.trimmingCharacters(in: .whitespaces)
        guard let firstSpace = trimmed.firstIndex(of: " ") else { return trimmed }
        return String(trimmed[trimmed.startIndex..<firstSpace])
    }

    var symbolName: String {
        hasData ? prayerSymbolName(for: name) : "moon.stars"
    }
}

// MARK: - Provider

struct NextPrayerProvider: TimelineProvider {
    private let store = PrayerDataStore.shared

    func placeholder(in context: Context) -> NextPrayerEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPrayerEntry) -> Void) {
        if context.isPreview && !store.hasPrayerTimes {
            completion(.placeholder())
        } else {
            completion(entry(at: Date()))
        }
    }

    static func emptyHint(store: PrayerDataStore) -> String {
        store.hasSyncedData
            ? "Set your location in the iPhone app."
            : "Open the iPhone app to sync prayer times."
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerEntry>) -> Void) {
        let now = Date()
        // One entry per upcoming prayer so the complication rolls over on its own,
        // even if the phone is out of range for days.
        let upcoming = store.prayerSchedule.filter { $0.date > now }.prefix(24)

        guard !upcoming.isEmpty else {
            // Nothing usable yet — retry in an hour; a live sync reloads us sooner.
            completion(
                Timeline(
                    entries: [.empty(at: now, hint: Self.emptyHint(store: store))],
                    policy: .after(now.addingTimeInterval(3600))
                )
            )
            return
        }

        let location = store.location
        var entries: [NextPrayerEntry] = []
        // Entry N renders "the prayer after N", starting from right now.
        var renderDate = now
        for prayer in upcoming {
            entries.append(entry(at: renderDate, next: prayer, location: location))
            renderDate = prayer.date
        }

        completion(Timeline(entries: entries, policy: .after(renderDate)))
    }

    private func entry(at date: Date) -> NextPrayerEntry {
        guard let next = store.nextPrayer(after: date) else {
            return .empty(at: date, hint: Self.emptyHint(store: store))
        }
        return entry(at: date, next: next, location: store.location)
    }

    private func entry(
        at date: Date,
        next: PrayerScheduleEntry,
        location: String
    ) -> NextPrayerEntry {
        NextPrayerEntry(
            date: date,
            name: next.name,
            time: next.time,
            prayerDate: next.date,
            dayLabel: next.dateLabel,
            location: location,
            hasData: true,
            hint: ""
        )
    }
}

// MARK: - Views

struct NextPrayerComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextPrayerEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 12, weight: .medium))
            Text(entry.compactTime)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .widgetAccentable()
    }

    private var corner: some View {
        Text(entry.compactTime)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .widgetLabel {
                Text(entry.name)
            }
    }

    private var inline: some View {
        Label {
            Text(entry.hasData ? "\(entry.name) \(entry.time)" : "Open Shia Companion")
        } icon: {
            Image(systemName: entry.symbolName)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 11, weight: .medium))
                Text(entry.hasData ? entry.name : "Shia Companion")
                    .font(.headline)
                    .lineLimit(1)
            }
            .widgetAccentable()

            if entry.hasData {
                Text(entry.time)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if let prayerDate = entry.prayerDate {
                    Text(prayerDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(entry.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// watchOS 10 requires widgets to declare a container background to render in the
    /// Smart Stack; complications on a watch face keep their own (transparent) styling.
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(watchOS 10.0, *) {
            containerBackground(.clear, for: .widget)
        } else {
            self
        }
    }
}

// MARK: - Widget

struct NextPrayerComplication: Widget {
    let kind = "NextPrayerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            NextPrayerComplicationView(entry: entry)
                .widgetContainerBackground()
        }
        .configurationDisplayName("Up Next")
        .description("The next of the times you picked in Settings, for your saved location.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

@main
struct ShiaCompanionWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerComplication()
    }
}

// MARK: - Preview

#if DEBUG
struct NextPrayerComplication_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NextPrayerComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            NextPrayerComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            NextPrayerComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }
}
#endif
