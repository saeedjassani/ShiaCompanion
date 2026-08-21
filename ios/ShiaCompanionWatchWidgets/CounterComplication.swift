import SwiftUI
import WidgetKit

// MARK: - Storage

/// Read-only view of the tasbeeh count the watch app writes to the app group.
///
/// The keys are duplicated from `CounterModel` rather than shared: `CounterView.swift`
/// belongs to the Watch App target only, and pulling it into the extension would drag
/// `WatchKit` haptics and the whole SwiftUI screen in with it. Keep the two lists in
/// step — they are the only contract between the app and this complication.
struct CounterDataStore {
    static let shared = CounterDataStore()

    private enum Keys {
        static let count = "sc_watch_counter_count"
        static let target = "sc_watch_counter_target"
    }

    /// Same fallback as `PrayerDataStore`: a missing app group degrades to an empty
    /// complication rather than a crash.
    private var defaults: UserDefaults { UserDefaults(suiteName: watchAppGroupID) ?? .standard }

    var count: Int { max(defaults.integer(forKey: Keys.count), 0) }

    /// `0` means "no target". Anything the app never offers is treated as no target so a
    /// stale container can't produce a nonsense denominator.
    var target: Int {
        let stored = defaults.integer(forKey: Keys.target)
        return stored > 0 ? stored : 0
    }
}

// MARK: - Timeline entry

struct CounterEntry: TimelineEntry {
    let date: Date
    let count: Int
    let target: Int

    static func placeholder(at date: Date = Date()) -> CounterEntry {
        CounterEntry(date: date, count: 21, target: 33)
    }

    /// Mirrors `CounterModel.progress`: reads full (rather than empty) exactly on a
    /// milestone, then starts over on the next count.
    var progress: Double {
        guard target > 0, count > 0 else { return 0 }
        let remainder = count % target
        return remainder == 0 ? 1 : Double(remainder) / Double(target)
    }

    /// `1` while below the first target, then `2`, `3`… so long sessions stay readable.
    var lap: Int {
        guard target > 0, count > 0 else { return 1 }
        return (count - 1) / target + 1
    }

    /// Position within the current lap, matching the numerator the app shows.
    var countInLap: Int {
        guard target > 0, count > 0 else { return count }
        let remainder = count % target
        return remainder == 0 ? target : remainder
    }

    var targetLabel: String {
        target == 0 ? "No target" : "\(countInLap) / \(target)"
    }
}

// MARK: - Provider

struct CounterProvider: TimelineProvider {
    private let store = CounterDataStore.shared

    func placeholder(in context: Context) -> CounterEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
        if context.isPreview && store.count == 0 {
            completion(.placeholder())
        } else {
            completion(entry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
        // The count only ever moves because the user moved it, so there is nothing to
        // schedule ahead: the watch app reloads this kind after it settles.
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> CounterEntry {
        CounterEntry(date: Date(), count: store.count, target: store.target)
    }
}

// MARK: - Views

struct CounterComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CounterEntry

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

    /// The dial from `CounterView`, shrunk: ring for the current lap, count in the middle.
    ///
    /// Sized off the container rather than in fixed points: the circular family is
    /// 10pt wider on a 49mm watch than on a 41mm one, and a number laid out for the
    /// big one loses digits inside the small one's circle.
    private var circular: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                AccessoryWidgetBackground()

                if entry.target > 0 {
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(style: StrokeStyle(lineWidth: side * 0.09, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(side * 0.05)
                }

                Text("\(entry.count)")
                    .font(.system(size: side * 0.42, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.35)
                    .allowsTightening(true)
                    .lineLimit(1)
                    // The chord across the middle of the ring, not the width of the
                    // square the ring is drawn in — five digits have to shrink to sit
                    // inside the circle rather than run out through its sides.
                    .frame(width: side * 0.66)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .widgetAccentable()
    }

    /// The corner family only has room for the number; the curved label carries the lap.
    private var corner: some View {
        Text("\(entry.count)")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .lineLimit(1)
            .widgetLabel {
                if entry.target > 0 {
                    Gauge(value: entry.progress) {
                        Text("Tasbeeh")
                    }
                } else {
                    Text("Tasbeeh")
                }
            }
    }

    private var inline: some View {
        Label {
            Text(entry.target > 0 ? "Tasbeeh \(entry.targetLabel)" : "Tasbeeh \(entry.count)")
        } icon: {
            Image(systemName: "hand.tap.fill")
        }
    }

    /// Two short rows and a hairline gauge.
    ///
    /// The rectangular family is only about 49pt tall on a 41mm watch, and the previous
    /// four-row stack (`.headline` title, 20pt count, 6pt gauge, caption) measured past
    /// that — so the target line, the thing the ring is counting towards, was the row
    /// that fell off the bottom. The count and its target now share a baseline, which
    /// buys back a whole row.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 10, weight: .medium))
                Text("Tasbeeh")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .widgetAccentable()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.count)")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    // The count never yields room to the label beside it.
                    .layoutPriority(1)

                Spacer(minLength: 2)

                Text(targetSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            if entry.target > 0 {
                Gauge(value: entry.progress) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "12 / 33 · ×2" — the lap only once there has been more than one.
    private var targetSummary: String {
        guard entry.target > 0 else { return "No target" }
        return entry.lap > 1 ? "\(entry.targetLabel) · ×\(entry.lap)" : entry.targetLabel
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

struct CounterComplication: Widget {
    /// Mirrored as `CounterModel.complicationKind` in the watch app, which reloads this
    /// timeline after the count settles.
    let kind = "TasbeehCounterComplication"

    /// Host matched by `ContentView.counterURLHost` in the watch app. The scheme is
    /// declared in the Watch App's `Info.plist`.
    static let counterURL = URL(string: "shiacompanion://tasbeeh")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CounterProvider()) { entry in
            CounterComplicationView(entry: entry)
                .widgetContainerBackground()
                // Without a URL a tap only launches the app, which lands on the prayer
                // list — one screen short of the counter the complication was showing.
                // `ContentView` matches the host and pushes the counter.
                .widgetURL(Self.counterURL)
        }
        .configurationDisplayName("Tasbeeh")
        .description("Your running dhikr count, with the ring showing progress to your target.")
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
struct CounterComplication_Previews: PreviewProvider {
    private static let families: [WidgetFamily] = [
        .accessoryCircular,
        .accessoryCorner,
        .accessoryInline,
        .accessoryRectangular,
    ]

    /// The widest content each family can be asked to hold: no target, a long lap
    /// label, and a count at the cap. Previewing every family against all three is
    /// how cropping shows up here rather than on someone's wrist.
    private static let samples: [(String, CounterEntry)] = [
        ("Typical", CounterEntry(date: Date(), count: 21, target: 33)),
        ("No target", CounterEntry(date: Date(), count: 486, target: 0)),
        ("Widest", CounterEntry(date: Date(), count: 99_999, target: 1000)),
    ]

    static var previews: some View {
        ForEach(families, id: \.self) { family in
            ForEach(samples, id: \.0) { name, entry in
                CounterComplicationView(entry: entry)
                    .previewContext(WidgetPreviewContext(family: family))
                    .previewDisplayName("\(name) – \(String(describing: family))")
            }
        }
    }
}
#endif
