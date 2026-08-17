import AppIntents
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

    /// How long before a prayer the widget starts asking the Smart Stack for room.
    static let imminentLead: TimeInterval = 45 * 60
    /// ...and how long after it is still the thing you want to see.
    static let relevantTail: TimeInterval = 15 * 60

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

    /// Name for the families that crop a full one, e.g. "Mgrb" for Maghrib.
    var shortName: String {
        hasData ? prayerShortName(for: name) : name
    }

    var symbolName: String {
        hasData ? prayerSymbolName(for: name) : "moon.stars"
    }

    /// Ranks this entry against every other widget competing for the Smart Stack.
    /// A flat score parks the widget wherever it first landed; scoring by how
    /// close the prayer is floats it to the top as the time approaches.
    var relevance: TimelineEntryRelevance? {
        guard hasData, let prayerDate else { return nil }
        let lead = prayerDate.timeIntervalSince(date)
        guard lead > 0 else { return TimelineEntryRelevance(score: 0) }
        let imminent = lead <= Self.imminentLead
        // `duration` expires the score at the prayer itself, so a stale entry
        // cannot keep claiming the top slot after the time has passed.
        return TimelineEntryRelevance(score: imminent ? 90 : 20, duration: lead)
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
            // A second, identical entry shortly before the prayer. An entry's
            // relevance score is fixed when the entry starts, so without this the
            // Smart Stack would rank the widget on how far off the prayer looked
            // hours ago and never notice it becoming imminent.
            let imminent = prayer.date.addingTimeInterval(-NextPrayerEntry.imminentLead)
            if imminent > renderDate {
                entries.append(entry(at: imminent, next: prayer, location: location))
            }
            renderDate = prayer.date
        }

        completion(Timeline(entries: entries, policy: .after(renderDate)))
    }

    /// Windows in which the system may surface "Up Next" in the Smart Stack on its
    /// own. Without them the widget is only ever visible where a user pinned it by
    /// hand, which is the gap between "it's a complication" and "it's a widget".
    @available(watchOS 11.0, *)
    func relevance() async -> WidgetRelevance<Void> {
        let now = Date()
        let attributes = store.prayerSchedule
            .filter { $0.date > now }
            .prefix(16)
            .map { prayer in
                WidgetRelevanceAttribute<Void>(
                    context: Self.relevantWindow(
                        from: prayer.date.addingTimeInterval(-NextPrayerEntry.imminentLead),
                        to: prayer.date.addingTimeInterval(NextPrayerEntry.relevantTail)
                    )
                )
            }
        return WidgetRelevance(attributes)
    }

    @available(watchOS 11.0, *)
    private static func relevantWindow(from start: Date, to end: Date) -> RelevantContext {
        if #available(watchOS 26.0, *) {
            // `.scheduled`: a prayer time is a fixed appointment, not a soft hint.
            return .date(interval: DateInterval(start: start, end: end), kind: .scheduled)
        }
        return .date(from: start, to: end)
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

    /// Full name when it fits, initial when it doesn't, so Maghrib degrades to
    /// "M" rather than "Maghri…". This family has the room to keep the whole
    /// word most of the time. `ViewThatFits` is watchOS 9, so no shim needed.
    private var prayerNameLabel: some View {
        ViewThatFits(in: .horizontal) {
            Text(entry.name)
                .font(.headline)
                .lineLimit(1)
            Text(entry.shortName)
                .font(.headline)
                .lineLimit(1)
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
        // Faces with a label slot draw the name outside the circle — the only
        // room on this family that the time isn't already using.
        .widgetLabel {
            Text(entry.shortName)
        }
    }

    private var corner: some View {
        Text(entry.compactTime)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .widgetLabel {
                // The curved bezel label is narrower than it looks; a full
                // "Maghrib" loses its tail there. This is the one family with no
                // symbol of its own, so the letter stands unaided — Maghrib and
                // Midnight both read "M" here, told apart only by the time.
                Text(entry.shortName)
            }
    }

    private var inline: some View {
        Label {
            // accessoryInline is one shared line and the system ignores layout
            // modifiers on it, so the string itself has to be the short one.
            Text(entry.hasData ? "\(entry.shortName) \(entry.compactTime)" : "Open Shia Companion")
        } icon: {
            Image(systemName: entry.symbolName)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 11, weight: .medium))
                if entry.hasData {
                    prayerNameLabel
                } else {
                    Text("Shia Companion")
                        .font(.headline)
                        .lineLimit(1)
                }
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
    /// watchOS applies this in the Smart Stack only — watch-face complications ignore
    /// it and stay transparent either way. `.clear` therefore bought nothing on the
    /// face and cost the widget its card in the stack, where it read as unstyled
    /// text floating on black instead of a widget.
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(watchOS 10.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
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
        CounterComplication()
    }
}

// MARK: - Preview

#if DEBUG
private extension NextPrayerEntry {
    static func preview(_ name: String, _ time: String) -> NextPrayerEntry {
        NextPrayerEntry(
            date: Date(),
            name: name,
            time: time,
            prayerDate: Date().addingTimeInterval(1800),
            dayLabel: "Today",
            location: "Karbala",
            hasData: true,
            hint: ""
        )
    }
}

struct NextPrayerComplication_Previews: PreviewProvider {
    private static let families: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryCorner,
        .accessoryInline,
        .accessoryRectangular,
    ]

    /// Maghrib and Midnight are the longest labels the phone can send, and the
    /// reason the short forms exist — preview both so cropping shows up here
    /// rather than on someone's wrist.
    private static let samples: [NextPrayerEntry] = [
        .preview("Asr", "4:15 pm"),
        .preview("Maghrib", "7:30 pm"),
        .preview("Midnight", "11:58 pm"),
    ]

    static var previews: some View {
        ForEach(families, id: \.self) { family in
            ForEach(samples, id: \.name) { entry in
                NextPrayerComplicationView(entry: entry)
                    .previewContext(WidgetPreviewContext(family: family))
                    .previewDisplayName("\(entry.name) – \(String(describing: family))")
            }
        }
    }
}
#endif
