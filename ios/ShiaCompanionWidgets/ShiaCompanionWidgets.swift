import SwiftUI
import WidgetKit

private let appGroupID = "group.com.developer110.shiacompanion"

private enum WidgetKeys {
    static let favoritesTitle = "sc_favorites_title"
    static let favoritesSubtitle = "sc_favorites_subtitle"
    static let favoriteItems = (1...8).map { "sc_favorites_item_\($0)" }
    static let favoriteUrls = (1...8).map { "sc_favorites_url_\($0)" }

    static let recitationTitle = "sc_recitation_title"
    static let recitationSubtitle = "sc_recitation_subtitle"
    static let recitationItems = (1...8).map { "sc_recitation_item_\($0)" }
    static let recitationUrls = (1...8).map { "sc_recitation_url_\($0)" }

    static let prayerTitle = "sc_prayer_title"
    static let prayerName = "sc_prayer_name"
    static let prayerTime = "sc_prayer_time"
    static let prayerDate = "sc_prayer_date"
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

struct WidgetListEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let items: [WidgetListItem]
}

struct WidgetListItem {
    let title: String
    let url: URL?
}

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetListEntry {
        WidgetListEntry(
            date: Date(),
            title: "Favorites",
            subtitle: "Open app to add favorites",
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
            subtitle: defaults?.widgetString(
                WidgetKeys.favoritesSubtitle,
                fallback: "Open app to add favorites"
            ) ?? "Open app to add favorites",
            items: items
        )
    }
}

struct RecitationProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetListEntry {
        WidgetListEntry(
            date: Date(),
            title: "Today's Recitations",
            subtitle: "",
            items: [WidgetListItem(title: "Open app to refresh", url: nil)]
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
            titleKeys: WidgetKeys.recitationItems,
            urlKeys: WidgetKeys.recitationUrls,
            firstFallback: "Open app to refresh"
        )

        return WidgetListEntry(
            date: Date(),
            title: defaults?.widgetString(
                WidgetKeys.recitationTitle,
                fallback: "Today's Recitations"
            ) ?? "Today's Recitations",
            subtitle: defaults?.widgetString(WidgetKeys.recitationSubtitle, fallback: "") ?? "",
            items: items
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

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let name: String
    let time: String
    let dateLabel: String
    let location: String
    let nextRefresh: Date
}

private struct PrayerScheduleEntry {
    let date: Date
    let name: String
    let time: String
    let dateLabel: String
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        PrayerWidgetEntry(
            date: Date(),
            title: "Upcoming Prayer",
            name: "Prayer Times",
            time: "Set location",
            dateLabel: "Open app",
            location: "Location needed",
            nextRefresh: Date().addingTimeInterval(1800)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.nextRefresh)))
    }

    private func loadEntry() -> PrayerWidgetEntry {
        let defaults = UserDefaults.widgetData
        let schedule = parseSchedule(defaults?.string(forKey: WidgetKeys.prayerSchedule) ?? "")
        let now = Date()
        let nextPrayer = schedule.first { $0.date > now }
        let nextRefresh = nextPrayer?.date.addingTimeInterval(60) ?? Date().addingTimeInterval(1800)

        return PrayerWidgetEntry(
            date: now,
            title: defaults?.widgetString(WidgetKeys.prayerTitle, fallback: "Upcoming Prayer") ?? "Upcoming Prayer",
            name: nextPrayer?.name ?? defaults?.widgetString(WidgetKeys.prayerName, fallback: "Prayer Times") ?? "Prayer Times",
            time: nextPrayer?.time ?? defaults?.widgetString(WidgetKeys.prayerTime, fallback: "Set location") ?? "Set location",
            dateLabel: nextPrayer?.dateLabel ?? defaults?.widgetString(WidgetKeys.prayerDate, fallback: "Open app") ?? "Open app",
            location: defaults?.widgetString(WidgetKeys.prayerLocation, fallback: "Location needed") ?? "Location needed",
            nextRefresh: nextRefresh
        )
    }

    private func parseSchedule(_ rawSchedule: String) -> [PrayerScheduleEntry] {
        rawSchedule
            .split(separator: ";")
            .compactMap { rawEntry in
                let parts = rawEntry.split(separator: "|", maxSplits: 3).map(String.init)
                guard parts.count == 4, let epochMillis = Double(parts[0]) else {
                    return nil
                }

                return PrayerScheduleEntry(
                    date: Date(timeIntervalSince1970: epochMillis / 1000.0),
                    name: parts[1],
                    time: parts[2],
                    dateLabel: parts[3]
                )
            }
            .sorted { $0.date < $1.date }
    }
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
            if !entry.subtitle.isEmpty {
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
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
            return 8
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

struct PrayerWidgetView: View {
    let entry: PrayerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            Text(entry.name)
                .font(.headline)
                .foregroundColor(.primaryText)
                .lineLimit(1)
            Text(entry.time)
                .font(.title2.weight(.bold))
                .foregroundColor(.bodyText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(entry.dateLabel)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(entry.location)
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
        .widgetCard()
    }
}

private extension View {
    func widgetCard() -> some View {
        self
            .padding(14)
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
}

struct FavoritesWidget: Widget {
    let kind = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            WidgetListView(entry: entry)
        }
        .configurationDisplayName("Favorites")
        .description("Saved Shia Companion favorites.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpcomingPrayerWidget: Widget {
    let kind = "UpcomingPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Prayer")
        .description("The next prayer time for your saved location.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct ShiaCompanionWidgets: WidgetBundle {
    var body: some Widget {
        FavoritesWidget()
        TodaysRecitationWidget()
        UpcomingPrayerWidget()
    }
}
