import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct CalendarComplicationEntry: TimelineEntry {
    let date: Date
    /// Nil until the phone has sent a run of days, or once that run has been used up.
    let day: HijriDay?
    /// The first event after today. Today's own is on `day`.
    let next: IslamicEvent?

    static func placeholder(at date: Date = Date()) -> CalendarComplicationEntry {
        CalendarComplicationEntry(
            date: date,
            day: HijriDay(
                start: date,
                day: 15,
                month: "Rabi' Al-Thani",
                monthShort: "Rab II",
                year: 1448,
                event: "",
                color: -1
            ),
            next: IslamicEvent(
                start: date.addingTimeInterval(8 * 86400),
                hijri: "8 Jumada Al-Awwal",
                title: "Birth of Imam Hasan Askari (a.s.)",
                color: 1
            )
        )
    }

    /// Today's event when there is one, otherwise what comes next.
    var headlineEvent: (title: String, color: Int, when: String)? {
        if let day, !day.event.isEmpty {
            return (day.event, day.color, "Today")
        }
        if let next {
            return (next.title, next.color, relativeDayLabel(next.start, from: date))
        }
        return nil
    }
}

// MARK: - Provider

struct CalendarComplicationProvider: TimelineProvider {
    private let store = PrayerDataStore.shared

    func placeholder(in context: Context) -> CalendarComplicationEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarComplicationEntry) -> Void) {
        let entry = entry(at: Date())
        completion(context.isPreview && entry.day == nil ? .placeholder() : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarComplicationEntry>) -> Void) {
        let now = Date()
        // One entry per midnight, so the date turns over on its own for a week even
        // with the phone out of range.
        var entries = [entry(at: now)]
        for day in store.calendarDays.filter({ $0.start > now }).prefix(7) {
            entries.append(entry(at: day.start))
        }

        let policyDate = entries.count > 1
            ? entries[entries.count - 1].date.addingTimeInterval(86400)
            : now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(policyDate)))
    }

    private func entry(at date: Date) -> CalendarComplicationEntry {
        CalendarComplicationEntry(
            date: date,
            day: store.hijriDay(at: date),
            next: store.upcomingEvents(after: date, limit: 1).first
        )
    }
}

// MARK: - Views

struct CalendarComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarComplicationEntry

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

    /// The hijri day over a short month, sized off the container the way the prayer
    /// complication's circular family is, so it scales instead of clipping.
    private var circular: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            VStack(spacing: 0) {
                if let day = entry.day {
                    Text(verbatim: String(day.day))
                        .font(.system(size: side * 0.40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(day.monthShort)
                        .font(.system(size: side * 0.20, weight: .semibold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: side * 0.72)
                } else {
                    Image(systemName: "calendar")
                        .font(.system(size: side * 0.36))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetAccentable()
    }

    private var corner: some View {
        Text(verbatim: entry.day.map { String($0.day) } ?? "–")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .widgetAccentable()
            .widgetLabel {
                Text(entry.day?.month ?? "Open iPhone app")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }
    }

    private var inline: some View {
        Label {
            Text(entry.day?.dateLine ?? "Open iPhone app")
        } icon: {
            Image(systemName: "moon.stars")
        }
    }

    /// The hijri date as a heading, then today's event — or the next one and how far off
    /// it is.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 10, weight: .semibold))
                Text(entry.day?.dateLine ?? "Islamic Calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .widgetAccentable()

            if let event = entry.headlineEvent {
                Text(event.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
                if event.when != "Today" {
                    Text(event.when)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if entry.day == nil {
                Text("Open the iPhone app to sync.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let day = entry.day {
                Text(verbatim: "\(day.year) AH")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// Same as the other complications: a card in the Smart Stack, transparent on a face.
    @ViewBuilder
    func calendarContainerBackground() -> some View {
        if #available(watchOS 10.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

// MARK: - Widget

struct CalendarComplication: Widget {
    let kind = "IslamicCalendarComplication"

    /// Host matched by `ContentView.calendarURLHost` in the watch app.
    static let calendarURL = URL(string: "shiacompanion://calendar")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarComplicationProvider()) { entry in
            CalendarComplicationView(entry: entry)
                .calendarContainerBackground()
                .widgetURL(Self.calendarURL)
        }
        .configurationDisplayName("Islamic Calendar")
        .description("Today's Hijri date and the next event.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Preview

#if DEBUG
struct CalendarComplication_Previews: PreviewProvider {
    private static let families: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryCorner,
        .accessoryInline,
        .accessoryRectangular,
    ]

    private static let samples: [(String, CalendarComplicationEntry)] = [
        ("Upcoming", .placeholder()),
        ("Event today", CalendarComplicationEntry(
            date: Date(),
            day: HijriDay(
                start: Date(),
                day: 10,
                month: "Muharram",
                monthShort: "Muh",
                year: 1448,
                event: "Ashoora ‐ Martyrdom of Imam Hussain(a.s.) and his companions",
                color: 0
            ),
            next: nil
        )),
        ("Empty", CalendarComplicationEntry(date: Date(), day: nil, next: nil)),
    ]

    static var previews: some View {
        ForEach(families, id: \.self) { family in
            ForEach(samples, id: \.0) { name, entry in
                CalendarComplicationView(entry: entry)
                    .previewContext(WidgetPreviewContext(family: family))
                    .previewDisplayName("\(name) – \(String(describing: family))")
            }
        }
    }
}
#endif
