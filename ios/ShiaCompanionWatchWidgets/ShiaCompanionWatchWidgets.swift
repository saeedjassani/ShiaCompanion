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

    /// Symbol over time, both sized from the container.
    ///
    /// The circular family is a circle drawn inside a square, and the square is what
    /// SwiftUI proposes to its content — so a time laid out to the full proposed width
    /// runs out through the sides of the circle and loses its last digits. Everything
    /// here is a fraction of the container's side, and the time is held to the chord
    /// across the band it sits in, so it scales down instead of being clipped.
    private var circular: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            VStack(spacing: 0) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: side * 0.20, weight: .medium))
                Text(entry.compactTime)
                    .font(.system(size: side * 0.34, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
                    .lineLimit(1)
                    // 0.70, not the 0.76 the widest band would allow: the symbol above
                    // pushes the time below centre, and the chord it sits in is
                    // narrower than the one through the middle. Measured against
                    // "11:58" on a 42pt circle, which is where 0.76 ran over.
                    .frame(width: side * 0.70)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetAccentable()
        // Faces with a label slot draw the name outside the circle — the only
        // room on this family that the time isn't already using.
        .widgetLabel {
            Text(entry.name)
        }
    }

    private var corner: some View {
        // Confirmed on-device: corner renders its main content flat in the corner
        // and the widgetLabel curved along the bezel — they are not two lines to
        // balance, they're one reading line the system bends for you. Putting the
        // time there (not the icon) is what makes that line read as a clock: the
        // icon sits fixed in the corner, the time is what curves.
        Image(systemName: entry.symbolName)
            .font(.system(size: 15, weight: .medium))
            .widgetLabel {
                Text(entry.compactTime)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .allowsTightening(true)
                    .lineLimit(1)
            }
    }

    private var inline: some View {
        Label {
            // Kept short: the inline slot is the one family whose width the system
            // owns, and it elides rather than scales.
            Text(entry.hasData ? "\(entry.name) \(entry.compactTime)" : "Open iPhone app")
        } icon: {
            Image(systemName: entry.symbolName)
        }
    }

    /// A name row and a time row, and nothing else.
    ///
    /// Not where the cropping was — the family is 152x69.5pt even on a 40mm watch, and
    /// the previous three-row stack (`.headline` name, 15pt time, caption countdown)
    /// measured about 9pt inside that. This is a legibility change rather than a fix:
    /// the time was the smallest thing on the roomiest family, and the countdown had
    /// nothing bounding its width. Beside the time instead of under it, the countdown
    /// is capped, the time is half again as large, and the stack keeps ~25pt spare for
    /// larger accessibility text.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 10, weight: .medium))
                if entry.hasData {
                    // Degrades name → initial rather than clipping the word; the day
                    // label goes first, since the time below already implies the day.
                    PrayerNameText(
                        name: entry.name,
                        dayLabel: entry.dayLabel == "Today" ? "" : entry.dayLabel,
                        font: .system(size: 12, weight: .semibold),
                        compactFont: .system(size: 10.5, weight: .semibold)
                    )
                } else {
                    Text("Shia Companion")
                        .font(.system(size: 12, weight: .semibold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .widgetAccentable()

            if entry.hasData {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.time)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 2)

                    if let prayerDate = entry.prayerDate {
                        // Relative text asks for far more width than a countdown
                        // needs; cap it so it can never push the time out of shape.
                        Text(prayerDate, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .frame(maxWidth: 58, alignment: .trailing)
                    }
                }
            } else {
                Text(entry.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
    static func preview(
        _ name: String,
        _ time: String,
        dayLabel: String = "Today",
        in seconds: TimeInterval = 1800
    ) -> NextPrayerEntry {
        NextPrayerEntry(
            date: Date(),
            name: name,
            time: time,
            prayerDate: Date().addingTimeInterval(seconds),
            dayLabel: dayLabel,
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
    private static let samples: [(String, NextPrayerEntry)] = [
        ("Asr", .preview("Asr", "4:15 pm")),
        ("Maghrib", .preview("Maghrib", "7:30 pm")),
        // The widest the complication ever gets: longest name, widest time, a day
        // label, and a countdown long enough to want a lot of room.
        ("Midnight tomorrow", .preview(
            "Midnight",
            "11:58 pm",
            dayLabel: "Tomorrow",
            in: 13 * 3600
        )),
        ("Empty", .empty(hint: "Open the iPhone app to sync prayer times.")),
    ]

    static var previews: some View {
        ForEach(families, id: \.self) { family in
            ForEach(samples, id: \.0) { name, entry in
                NextPrayerComplicationView(entry: entry)
                    .previewContext(WidgetPreviewContext(family: family))
                    .previewDisplayName("\(name) – \(String(describing: family))")
            }
        }
    }
}
#endif
