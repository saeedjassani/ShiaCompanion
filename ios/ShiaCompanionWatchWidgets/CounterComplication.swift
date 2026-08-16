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
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.target > 0 {
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
            }

            Text("\(entry.count)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 6)
        }
        .widgetAccentable()
    }

    /// The corner family only has room for the number; the curved label carries the lap.
    private var corner: some View {
        Text("\(entry.count)")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
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

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("Tasbeeh")
                    .font(.headline)
                    .lineLimit(1)
            }
            .widgetAccentable()

            Text("\(entry.count)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if entry.target > 0 {
                // The bar reads the lap, so the "×N" tells the user which lap it is.
                Gauge(value: entry.progress) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .frame(height: 6)

                Text(entry.lap > 1 ? "\(entry.targetLabel) · ×\(entry.lap)" : entry.targetLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No target")
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

struct CounterComplication: Widget {
    /// Mirrored as `CounterModel.complicationKind` in the watch app, which reloads this
    /// timeline after the count settles.
    let kind = "TasbeehCounterComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CounterProvider()) { entry in
            CounterComplicationView(entry: entry)
                .widgetContainerBackground()
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
    static var previews: some View {
        Group {
            CounterComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            CounterComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            CounterComplicationView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
        }
    }
}
#endif
