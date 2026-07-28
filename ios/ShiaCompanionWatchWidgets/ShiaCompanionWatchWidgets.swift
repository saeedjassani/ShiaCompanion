import SwiftUI
import WidgetKit

private let appGroupID = "group.com.developer110.shiacompanion"

private enum WidgetKeys {
    static let prayerName = "sc_prayer_name"
    static let prayerTime = "sc_prayer_time"
    static let prayerLocation = "sc_prayer_location"
    static let prayerSchedule = "sc_prayer_schedule"
}

private extension UserDefaults {
    static var widgetData: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func widgetString(_ key: String, fallback: String) -> String {
        let value = string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : fallback
    }
}

// MARK: - Prayer schedule parsing

private struct PrayerScheduleEntry {
    let date: Date
    let name: String
    let time: String
}

private func parsePrayerSchedule(_ rawSchedule: String) -> [PrayerScheduleEntry] {
    rawSchedule
        .split(separator: ";")
        .compactMap { rawEntry in
            let parts = rawEntry
                .split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
                .map(String.init)
            guard (parts.count == 4 || parts.count == 6), let epochMillis = Double(parts[0]) else {
                return nil
            }

            return PrayerScheduleEntry(
                date: Date(timeIntervalSince1970: epochMillis / 1000.0),
                name: parts[1],
                time: parts[2]
            )
        }
        .sorted { $0.date < $1.date }
}

// MARK: - Timeline entry

struct NextPrayerEntry: TimelineEntry {
    let date: Date
    let name: String
    let time: String
    let location: String
}

struct NextPrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextPrayerEntry {
        NextPrayerEntry(date: Date(), name: "Maghrib", time: "7:30 pm", location: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPrayerEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerEntry>) -> Void) {
        let defaults = UserDefaults.widgetData
        let schedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        let now = Date()
        let transitionDates = schedule
            .filter { $0.date > now }
            .prefix(8)
            .map(\.date)

        var entries = [loadEntry(defaults: defaults, schedule: schedule, now: now)]
        for date in transitionDates {
            entries.append(loadEntry(defaults: defaults, schedule: schedule, now: date))
        }

        let policyDate = entries.last?.date.addingTimeInterval(1800) ?? now.addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(policyDate)))
    }

    private func loadEntry() -> NextPrayerEntry {
        let defaults = UserDefaults.widgetData
        let schedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        return loadEntry(defaults: defaults, schedule: schedule, now: Date())
    }

    private func loadEntry(
        defaults: UserDefaults?,
        schedule: [PrayerScheduleEntry],
        now: Date
    ) -> NextPrayerEntry {
        let nextPrayer = schedule.first { $0.date > now }

        return NextPrayerEntry(
            date: now,
            name: nextPrayer?.name ?? defaults?.widgetString(WidgetKeys.prayerName, fallback: "Prayer Times") ?? "Prayer Times",
            time: nextPrayer?.time ?? defaults?.widgetString(WidgetKeys.prayerTime, fallback: "Open app") ?? "Open app",
            location: defaults?.widgetString(WidgetKeys.prayerLocation, fallback: "") ?? ""
        )
    }
}

// MARK: - Views

private func prayerSymbolName(for prayerName: String) -> String {
    let name = prayerName.lowercased()
    if name.contains("fajr") {
        return "sunrise"
    }
    if name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") {
        return "sun.max"
    }
    if name.contains("asr") {
        return "sun.min"
    }
    if name.contains("maghrib") {
        return "sunset"
    }
    if name.contains("isha") {
        return "moon.stars"
    }
    return "sun.max"
}

private func shortTime(_ time: String) -> String {
    time
        .replacingOccurrences(of: " am", with: "", options: .caseInsensitive)
        .replacingOccurrences(of: " pm", with: "", options: .caseInsensitive)
}

struct NextPrayerCircularView: View {
    let entry: NextPrayerEntry

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: prayerSymbolName(for: entry.name))
                .font(.system(size: 14, weight: .semibold))
            Text(shortTime(entry.time))
                .font(.system(size: 11, weight: .semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .widgetAccentable()
    }
}

struct NextPrayerRectangularView: View {
    let entry: NextPrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.name)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(entry.time)
                .font(.title3)
                .lineLimit(1)
            if !entry.location.isEmpty {
                Text(entry.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct NextPrayerInlineView: View {
    let entry: NextPrayerEntry

    var body: some View {
        Label("\(entry.name) \(entry.time)", systemImage: prayerSymbolName(for: entry.name))
    }
}

struct NextPrayerCornerView: View {
    let entry: NextPrayerEntry

    var body: some View {
        Image(systemName: prayerSymbolName(for: entry.name))
            .widgetLabel {
                Text(entry.time)
            }
    }
}

struct NextPrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextPrayerEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            NextPrayerCircularView(entry: entry)
        case .accessoryInline:
            NextPrayerInlineView(entry: entry)
        case .accessoryCorner:
            NextPrayerCornerView(entry: entry)
        default:
            NextPrayerRectangularView(entry: entry)
        }
    }
}

// MARK: - Widget

struct NextPrayerWidget: Widget {
    let kind = "NextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Shows your next prayer time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

@main
struct ShiaCompanionWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
    }
}
