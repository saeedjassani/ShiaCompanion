import SwiftUI
import WidgetKit

private let appGroupID = "group.com.developer110.shiacompanion"

private enum WidgetKeys {
    static let favoritesTitle = "sc_favorites_title"
    static let favoriteItems = (1...12).map { "sc_favorites_item_\($0)" }
    static let favoriteUrls = (1...12).map { "sc_favorites_url_\($0)" }

    static let recitationTitle = "sc_recitation_title"
    static let recitationItems = (1...12).map { "sc_recitation_item_\($0)" }
    static let recitationUrls = (1...12).map { "sc_recitation_url_\($0)" }
    static let recitationSchedule = "sc_recitation_schedule"

    static let prayerTitle = "sc_prayer_title"
    static let prayerName = "sc_prayer_name"
    static let prayerTime = "sc_prayer_time"
    static let prayerLocation = "sc_prayer_location"
    static let prayerSchedule = "sc_prayer_schedule"
    static let prayerSecondaryName = "sc_prayer_secondary_name"
    static let prayerSecondaryTime = "sc_prayer_secondary_time"

    static let dailyPrayerTitle = "sc_daily_prayer_title"
    static let dailyPrayerNames = (1...6).map { "sc_daily_prayer_name_\($0)" }
    static let dailyPrayerTimes = (1...6).map { "sc_daily_prayer_time_\($0)" }
    static let dailyPrayerSchedule = "sc_daily_prayer_schedule"
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

struct WidgetListEntry: TimelineEntry {
    let date: Date
    let title: String
    let items: [WidgetListItem]
    let location: String
    let nextPrayerName: String
    let nextPrayerDate: Date?

    init(
        date: Date,
        title: String,
        items: [WidgetListItem],
        location: String = "",
        nextPrayerName: String = "",
        nextPrayerDate: Date? = nil
    ) {
        self.date = date
        self.title = title
        self.items = items
        self.location = location
        self.nextPrayerName = nextPrayerName
        self.nextPrayerDate = nextPrayerDate
    }
}

struct WidgetListItem {
    let title: String
    let url: URL?
    let time: String

    init(title: String, url: URL? = nil, time: String = "") {
        self.title = title
        self.url = url
        self.time = time
    }
}

private struct WidgetListScheduleEntry {
    let start: Date
    let items: [WidgetListItem]
}

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetListEntry {
        WidgetListEntry(
            date: Date(),
            title: "Favorites",
            items: [WidgetListItem(title: "No favorites yet", url: nil)]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetListEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetListEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .after(Date().addingTimeInterval(3600))))
    }

    private func loadEntry() -> WidgetListEntry {
        let defaults = UserDefaults.widgetData
        let items = widgetItems(
            defaults: defaults,
            titleKeys: WidgetKeys.favoriteItems,
            urlKeys: WidgetKeys.favoriteUrls,
            firstFallback: "No favorites yet"
        )

        return WidgetListEntry(
            date: Date(),
            title: defaults?.widgetString(WidgetKeys.favoritesTitle, fallback: "Favorites") ?? "Favorites",
            items: items
        )
    }
}

struct RecitationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetListEntry {
        WidgetListEntry(
            date: Date(),
            title: "Today's Recitations",
            items: [WidgetListItem(title: "Open app to refresh", url: nil)]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetListEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetListEntry>) -> Void) {
        completion(loadTimeline())
    }

    private func loadTimeline() -> Timeline<WidgetListEntry> {
        let defaults = UserDefaults.widgetData
        let schedule = parseListSchedule(defaults?.string(forKey: WidgetKeys.recitationSchedule) ?? "")
        let now = Date()

        if schedule.isEmpty {
            return Timeline(
                entries: [loadEntry(defaults: defaults, schedule: schedule, now: now)],
                policy: .after(now.addingTimeInterval(3600))
            )
        }

        let transitionDates = schedule
            .map(\.start)
            .filter { $0 > now }
            .prefix(8)
        var entries = [loadEntry(defaults: defaults, schedule: schedule, now: now)]

        for date in transitionDates {
            entries.append(loadEntry(defaults: defaults, schedule: schedule, now: date))
        }

        let policyDate = entries.last?.date.addingTimeInterval(86400) ?? now.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(policyDate))
    }

    private func loadEntry() -> WidgetListEntry {
        let defaults = UserDefaults.widgetData
        let schedule = parseListSchedule(defaults?.string(forKey: WidgetKeys.recitationSchedule) ?? "")
        return loadEntry(defaults: defaults, schedule: schedule, now: Date())
    }

    private func loadEntry(
        defaults: UserDefaults?,
        schedule: [WidgetListScheduleEntry],
        now: Date
    ) -> WidgetListEntry {
        let scheduledItems = currentListScheduleEntry(schedule, now: now)?.items
        let items: [WidgetListItem]
        if let scheduledItems = scheduledItems, !scheduledItems.isEmpty {
            items = scheduledItems
        } else {
            items = widgetItems(
                defaults: defaults,
                titleKeys: WidgetKeys.recitationItems,
                urlKeys: WidgetKeys.recitationUrls,
                firstFallback: "Open app to refresh"
            )
        }

        return WidgetListEntry(
            date: now,
            title: defaults?.widgetString(
                WidgetKeys.recitationTitle,
                fallback: "Today's Recitations"
            ) ?? "Today's Recitations",
            items: items
        )
    }
}

struct DailyPrayerTimesProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetListEntry {
        WidgetListEntry(
            date: Date(),
            title: "Prayer Times",
            items: [
                WidgetListItem(title: "Fajr", time: "05:00 am"),
                WidgetListItem(title: "Sunrise", time: "06:24 am"),
                WidgetListItem(title: "Zuhr", time: "12:30 pm"),
                WidgetListItem(title: "Asr", time: "04:15 pm"),
                WidgetListItem(title: "Maghrib", time: "08:10 pm"),
                WidgetListItem(title: "Isha", time: "09:05 pm")
            ],
            location: "Karbala",
            nextPrayerName: "Zuhr",
            nextPrayerDate: Date().addingTimeInterval(7200)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetListEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetListEntry>) -> Void) {
        completion(loadTimeline())
    }

    private func loadTimeline() -> Timeline<WidgetListEntry> {
        let defaults = UserDefaults.widgetData
        let schedule = parseListSchedule(defaults?.string(forKey: WidgetKeys.dailyPrayerSchedule) ?? "")
        let prayerSchedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        let now = Date()

        if schedule.isEmpty {
            return Timeline(
                entries: [loadEntry(defaults: defaults, schedule: schedule, prayerSchedule: prayerSchedule, now: now)],
                policy: .after(now.addingTimeInterval(3600))
            )
        }

        let transitionDates = schedule.map(\.start) + prayerSchedule.map(\.date)
        let upcomingTransitionDates = transitionDates
            .filter { $0 > now }
            .sorted()
            .prefix(8)
        var entries = [loadEntry(defaults: defaults, schedule: schedule, prayerSchedule: prayerSchedule, now: now)]

        for date in upcomingTransitionDates {
            entries.append(loadEntry(defaults: defaults, schedule: schedule, prayerSchedule: prayerSchedule, now: date))
        }

        let policyDate = entries.last?.date.addingTimeInterval(86400) ?? now.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(policyDate))
    }

    private func loadEntry() -> WidgetListEntry {
        let defaults = UserDefaults.widgetData
        let schedule = parseListSchedule(defaults?.string(forKey: WidgetKeys.dailyPrayerSchedule) ?? "")
        let prayerSchedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        return loadEntry(defaults: defaults, schedule: schedule, prayerSchedule: prayerSchedule, now: Date())
    }

    private func loadEntry(
        defaults: UserDefaults?,
        schedule: [WidgetListScheduleEntry],
        prayerSchedule: [PrayerScheduleEntry],
        now: Date
    ) -> WidgetListEntry {
        let scheduledItems = currentListScheduleEntry(schedule, now: now)?.items
        let items: [WidgetListItem]
        if let scheduledItems = scheduledItems, !scheduledItems.isEmpty {
            items = scheduledItems
        } else {
            items = dailyPrayerItems(defaults: defaults)
        }
        let nextPrayer = prayerSchedule.first { $0.date > now }

        return WidgetListEntry(
            date: now,
            title: defaults?.widgetString(WidgetKeys.dailyPrayerTitle, fallback: "Prayer Times") ?? "Prayer Times",
            items: items,
            location: defaults?.widgetString(WidgetKeys.prayerLocation, fallback: "Location needed") ?? "Location needed",
            nextPrayerName: nextPrayer?.name ?? defaults?.widgetString(WidgetKeys.prayerName, fallback: "") ?? "",
            nextPrayerDate: nextPrayer?.date
        )
    }
}

private func widgetItems(
    defaults: UserDefaults?,
    titleKeys: [String],
    urlKeys: [String],
    firstFallback: String
) -> [WidgetListItem] {
    titleKeys.enumerated().compactMap { index, titleKey in
        let title = defaults?.widgetString(titleKey, fallback: index == 0 ? firstFallback : "") ?? ""
        if title.isEmpty {
            return nil
        }

        let rawUrl = defaults?.widgetString(urlKeys[index], fallback: "") ?? ""
        return WidgetListItem(title: title, url: URL(string: rawUrl))
    }
}

private func dailyPrayerItems(defaults: UserDefaults?) -> [WidgetListItem] {
    WidgetKeys.dailyPrayerNames.enumerated().compactMap { index, nameKey in
        let name = defaults?.widgetString(nameKey, fallback: index == 0 ? "Set location" : "") ?? ""
        let time = defaults?.widgetString(WidgetKeys.dailyPrayerTimes[index], fallback: index == 0 ? "Open app" : "") ?? ""
        if name.isEmpty && time.isEmpty {
            return nil
        }
        return WidgetListItem(title: name, time: time)
    }
}

private func currentListScheduleEntry(
    _ schedule: [WidgetListScheduleEntry],
    now: Date
) -> WidgetListScheduleEntry? {
    schedule.last { $0.start <= now }
}

private func parseListSchedule(_ rawSchedule: String) -> [WidgetListScheduleEntry] {
    guard
        let data = rawSchedule.data(using: .utf8),
        let rawEntries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
        return []
    }

    return rawEntries.compactMap { rawEntry in
        guard
            let startMillis = (rawEntry["start"] as? NSNumber)?.doubleValue,
            let rawItems = rawEntry["items"] as? [[String: Any]]
        else {
            return nil
        }

        let items = rawItems.compactMap { rawItem -> WidgetListItem? in
            guard let title = (rawItem["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !title.isEmpty
            else {
                return nil
            }

            let rawUrl = (rawItem["url"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let time = (rawItem["time"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return WidgetListItem(title: title, url: URL(string: rawUrl), time: time)
        }

        return WidgetListScheduleEntry(
            start: Date(timeIntervalSince1970: startMillis / 1000.0),
            items: items
        )
    }
    .sorted { $0.start < $1.start }
}

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let name: String
    let time: String
    let location: String
    let secondaryName: String
    let secondaryTime: String
    let nextRefresh: Date
}

private struct PrayerScheduleEntry {
    let date: Date
    let name: String
    let time: String
    let secondaryName: String
    let secondaryTime: String
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        PrayerWidgetEntry(
            date: Date(),
            title: "Up Next",
            name: "Prayer Times",
            time: "Set location",
            location: "Location needed",
            secondaryName: "",
            secondaryTime: "",
            nextRefresh: Date().addingTimeInterval(1800)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        completion(loadTimeline())
    }

    private func loadTimeline() -> Timeline<PrayerWidgetEntry> {
        let defaults = UserDefaults.widgetData
        let schedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        let now = Date()
        let transitionDates = schedule
            .filter { $0.date > now }
            .prefix(8)
            .map(\.date)
        var entries = [loadEntry(defaults: defaults, schedule: schedule, now: now)]

        for date in transitionDates where date > now {
            entries.append(loadEntry(defaults: defaults, schedule: schedule, now: date))
        }

        let policyDate = entries.last?.nextRefresh ?? Date().addingTimeInterval(1800)
        return Timeline(entries: entries, policy: .after(policyDate))
    }

    private func loadEntry() -> PrayerWidgetEntry {
        let defaults = UserDefaults.widgetData
        let schedule = parsePrayerSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        return loadEntry(defaults: defaults, schedule: schedule, now: Date())
    }

    private func loadEntry(
        defaults: UserDefaults?,
        schedule: [PrayerScheduleEntry],
        now: Date
    ) -> PrayerWidgetEntry {
        let nextPrayer = schedule.first { $0.date > now }
        let nextRefresh = nextPrayer?.date ?? now.addingTimeInterval(1800)

        return PrayerWidgetEntry(
            date: now,
            title: (defaults?.widgetString(WidgetKeys.prayerTitle, fallback: "Up Next") ?? "Up Next")
                .replacingOccurrences(of: "Upcoming", with: "Next"),
            name: nextPrayer?.name ?? defaults?.widgetString(WidgetKeys.prayerName, fallback: "Prayer Times") ?? "Prayer Times",
            time: nextPrayer?.time ?? defaults?.widgetString(WidgetKeys.prayerTime, fallback: "Set location") ?? "Set location",
            location: defaults?.widgetString(WidgetKeys.prayerLocation, fallback: "Location needed") ?? "Location needed",
            secondaryName: nextPrayer?.secondaryName ?? defaults?.widgetString(WidgetKeys.prayerSecondaryName, fallback: "") ?? "",
            secondaryTime: nextPrayer?.secondaryTime ?? defaults?.widgetString(WidgetKeys.prayerSecondaryTime, fallback: "") ?? "",
            nextRefresh: nextRefresh
        )
    }

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
                time: parts[2],
                secondaryName: parts.count == 6 ? parts[4] : "",
                secondaryTime: parts.count == 6 ? parts[5] : ""
            )
        }
        .sorted { $0.date < $1.date }
}

struct WidgetListView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetListEntry

    var body: some View {
        let visibleItems = Array(entry.items.prefix(visibleItemCount))
        let isEmptyState = entry.items.count == 1 && entry.items.first?.url == nil

        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .foregroundColor(.primaryText)
                .lineLimit(1)
            Color.clear.frame(height: 8)
            if isEmptyState, let item = entry.items.first {
                Spacer(minLength: 0)
                Text(item.title)
                    .font(.caption)
                    .foregroundColor(.bodyText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(visibleItems.enumerated()), id: \.offset) { _, item in
                    if let url = item.url {
                        Link(destination: url) {
                            widgetItemRow(item.title, clickable: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        widgetItemRow(item.title, clickable: false)
                    }
                }
            }
        }
        .widgetCard()
    }

    private var visibleItemCount: Int {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 4
        default:
            return 10
        }
    }

    private func widgetItemRow(_ title: String, clickable: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.bodyText)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondaryText)
                .opacity(clickable ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct DailyPrayerTimesView: View {
    let entry: WidgetListEntry

    var body: some View {
        let visibleItems = Array(entry.items.prefix(6))
        let hasPrayerTimes = visibleItems.contains { !$0.time.isEmpty }
        // Six columns only fit a medium widget once the gutters tighten up.
        let columnSpacing: CGFloat = visibleItems.count > 5 ? 4 : 8

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(entry.location)
                        .font(.caption2.weight(.semibold))
                }
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.nextPrayerName.isEmpty, let nextPrayerDate = entry.nextPrayerDate {
                    HStack(spacing: 3) {
                        Text("\(entry.nextPrayerName) in")
                        // Timer text reserves room for the widest value it can
                        // ever show, so it needs trailing alignment of its own
                        // to sit flush against the edge of the widget.
                        Text(nextPrayerDate, style: .timer)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.bodyText)
                    .lineLimit(1)
                    .layoutPriority(1)
                }
            }
            Spacer(minLength: 0)
            if hasPrayerTimes {
                HStack(alignment: .center, spacing: columnSpacing) {
                    ForEach(Array(visibleItems.enumerated()), id: \.offset) { _, item in
                        VStack(spacing: 4) {
                            PrayerGlyph(prayerName: item.title, badgeSize: 25, symbolSize: 13)
                            Text(item.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                            Text(item.time)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.bodyText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if let item = visibleItems.first {
                Spacer(minLength: 0)
                Text(item.title)
                    .font(.caption)
                    .foregroundColor(.bodyText)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .widgetCard()
    }
}

struct PrayerWidgetView: View {
    let entry: PrayerWidgetEntry

    var body: some View {
        let footer = !entry.secondaryName.isEmpty && !entry.secondaryTime.isEmpty
            ? "\(entry.secondaryName): \(entry.secondaryTime)"
            : entry.location

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(compactNextTitle(entry.title))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                PrayerGlyph(prayerName: entry.name, badgeSize: 24, symbolSize: 13)
            }
            Text(entry.name)
                .font(.headline.weight(.bold))
                .foregroundColor(.primaryText)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.time)
                .font(.title.weight(.bold))
                .foregroundColor(.bodyText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(footer)
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .widgetCard()
    }
}

struct PrayerGlyph: View {
    let prayerName: String
    let badgeSize: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.iconBackground)
            Image(systemName: prayerSymbolName(for: prayerName))
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundColor(.accentText)
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}

private func compactNextTitle(_ title: String) -> String {
    return title
        .replacingOccurrences(of: "Upcoming", with: "Next")
        .replacingOccurrences(of: " Prayer", with: "")
}

private func prayerSymbolName(for prayerName: String) -> String {
    let name = prayerName.lowercased()
    if name.contains("fajr") {
        return "sunrise"
    }
    if name.contains("sunrise") {
        return "sunrise.fill"
    }
    if name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") {
        return "sun.max"
    }
    if name.contains("asr") {
        return "sun.min"
    }
    if name.contains("maghrib") || name.contains("sunset") {
        return "sunset"
    }
    if name.contains("isha") {
        return "moon.stars"
    }
    if name.contains("midnight") {
        return "moon"
    }
    return "sun.max"
}

private extension View {
    func widgetCard() -> some View {
        self
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetBackground()
    }

    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(Color.widgetBackground, for: .widget)
        } else {
            self.background(Color.widgetBackground)
        }
    }
}

private extension Color {
    static let widgetBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.11, blue: 0.09, alpha: 1.0)
            : UIColor(red: 0.43, green: 0.30, blue: 0.25, alpha: 1.0)
    })
    static let primaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.95, blue: 0.91, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.97, blue: 0.94, alpha: 1.0)
    })
    static let bodyText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.84, blue: 0.77, alpha: 1.0)
            : UIColor(red: 0.97, green: 0.89, blue: 0.83, alpha: 1.0)
    })
    static let secondaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.75, green: 0.66, blue: 0.60, alpha: 1.0)
            : UIColor(red: 0.89, green: 0.78, blue: 0.70, alpha: 1.0)
    })
    static let iconBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.85, blue: 0.47, alpha: 0.16)
            : UIColor(red: 1.0, green: 0.78, blue: 0.34, alpha: 0.20)
    })
    static let accentText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.85, blue: 0.47, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.78, blue: 0.34, alpha: 1.0)
    })
}

struct FavoritesWidget: Widget {
    let kind = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            WidgetListView(entry: entry)
        }
        .configurationDisplayName("Favorites")
        .description("Saved Shia Companion favorites.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TodaysRecitationWidget: Widget {
    let kind = "TodaysRecitationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecitationProvider()) { entry in
            WidgetListView(entry: entry)
        }
        .configurationDisplayName("Today's Recitations")
        .description("Daily recitations from Shia Companion.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DailyPrayerTimesWidget: Widget {
    let kind = "DailyPrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPrayerTimesProvider()) { entry in
            DailyPrayerTimesView(entry: entry)
        }
        .configurationDisplayName("Prayer Times")
        .description("The prayer times you picked in Settings, for your saved location.")
        .supportedFamilies([.systemMedium])
    }
}

struct UpcomingPrayerWidget: Widget {
    let kind = "UpcomingPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("The next of the times you picked in Settings, for your saved location.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ShiaCompanionWidgets: WidgetBundle {
    var body: some Widget {
        FavoritesWidget()
        TodaysRecitationWidget()
        DailyPrayerTimesWidget()
        UpcomingPrayerWidget()
    }
}
