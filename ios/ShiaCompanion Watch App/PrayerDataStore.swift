import Foundation

/// Keys shared with the Flutter app (`HomeScreenWidgetService`) and the iOS widgets.
///
/// NOTE: app group containers are *not* shared between iOS and watchOS — the same
/// group identifier resolves to a different, device-local container on the watch.
/// Everything in here is written by `WatchConnectivityManager` from payloads that
/// the iPhone pushes over `WCSession`, and read back by both the watch app and the
/// complication extension (which do share this container, since both live on the watch).
///
/// `nonisolated`: the Watch App target defaults new declarations to `@MainActor`, but
/// these keys are read from `WCSessionDelegate` callbacks off the main actor.
nonisolated enum WatchDataKeys {
    static let prayerLocation = "sc_prayer_location"
    static let prayerSchedule = "sc_prayer_schedule"
    static let prayerName = "sc_prayer_name"
    static let prayerTime = "sc_prayer_time"
    static let prayerDate = "sc_prayer_date"
    static let prayerSecondaryName = "sc_prayer_secondary_name"
    static let prayerSecondaryTime = "sc_prayer_secondary_time"

    static let dailyPrayerNames = (1...5).map { "sc_daily_prayer_name_\($0)" }
    static let dailyPrayerTimes = (1...5).map { "sc_daily_prayer_time_\($0)" }
    static let dailyPrayerSchedule = "sc_daily_prayer_schedule"

    /// Epoch millis of the last payload the phone sent. Absent until the first sync.
    static let updatedAt = "sc_watch_updated_at"

    static let all: [String] =
        [
            prayerLocation,
            prayerSchedule,
            prayerName,
            prayerTime,
            prayerDate,
            prayerSecondaryName,
            prayerSecondaryTime,
            dailyPrayerSchedule,
            updatedAt,
        ] + dailyPrayerNames + dailyPrayerTimes
}

nonisolated let watchAppGroupID = "group.com.developer110.shiacompanion"

/// Local storage for the last snapshot received from the iPhone.
///
/// Stateless (the container is the source of truth) so it can be read from any thread.
/// Explicitly `nonisolated`: the Watch App target defaults new declarations to
/// `@MainActor`, but `WatchConnectivityManager` reads and writes this from
/// `WCSessionDelegate` callbacks that arrive off the main actor.
nonisolated struct PrayerDataStore: Sendable {
    static let shared = PrayerDataStore()

    /// Falls back to `.standard` so a missing/misconfigured app group degrades to
    /// "watch app works, complication doesn't" instead of "nothing works".
    var defaults: UserDefaults { UserDefaults(suiteName: watchAppGroupID) ?? .standard }

    /// `true` once the phone has sent at least one snapshot.
    var hasSyncedData: Bool {
        defaults.object(forKey: WatchDataKeys.updatedAt) != nil
    }

    /// `true` when the synced snapshot actually contains prayer times. The phone
    /// publishes placeholder rows ("Set location" / "Open app") when no location has
    /// been chosen yet, and those must not be rendered as prayer times.
    var hasPrayerTimes: Bool {
        !string(WatchDataKeys.prayerSchedule).isEmpty
    }

    var lastSyncDate: Date? {
        let millis = defaults.double(forKey: WatchDataKeys.updatedAt)
        guard millis > 0 else { return nil }
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    var location: String {
        string(WatchDataKeys.prayerLocation)
    }

    func string(_ key: String) -> String {
        (defaults.string(forKey: key) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Merges a payload received from the phone. Only known keys are written so a
    /// malformed/oversized dictionary can't pollute the container.
    func apply(payload: [String: Any]) {
        var wroteSomething = false
        for key in WatchDataKeys.all {
            guard let value = payload[key] else { continue }
            if key == WatchDataKeys.updatedAt {
                defaults.set(Self.doubleValue(value), forKey: key)
            } else {
                defaults.set(Self.stringValue(value), forKey: key)
            }
            wroteSomething = true
        }
        // A payload without an explicit timestamp still counts as a successful sync.
        if wroteSomething, payload[WatchDataKeys.updatedAt] == nil {
            defaults.set(Date().timeIntervalSince1970 * 1000.0, forKey: WatchDataKeys.updatedAt)
        }
    }

    private static func stringValue(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private static func doubleValue(_ value: Any) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let parsed = Double(string) { return parsed }
        return Date().timeIntervalSince1970 * 1000.0
    }

    // MARK: - Derived data

    /// The upcoming prayer/period timeline (8 days), sorted ascending.
    var prayerSchedule: [PrayerScheduleEntry] {
        parsePrayerSchedule(string(WatchDataKeys.prayerSchedule))
    }

    func nextPrayer(after date: Date = Date()) -> PrayerScheduleEntry? {
        prayerSchedule.first { $0.date > date }
    }

    /// The five daily prayer times for the given day.
    ///
    /// Prefers the multi-day JSON schedule so the watch rolls over to the next day on
    /// its own; falls back to the flat `sc_daily_prayer_*` keys (which only ever hold
    /// the day the phone last published).
    func dailyPrayers(for date: Date = Date()) -> [PrayerEntry] {
        if let fromSchedule = dailyPrayersFromSchedule(for: date), !fromSchedule.isEmpty {
            return fromSchedule
        }

        var entries: [PrayerEntry] = []
        for index in 0..<WatchDataKeys.dailyPrayerNames.count {
            let name = string(WatchDataKeys.dailyPrayerNames[index])
            let time = string(WatchDataKeys.dailyPrayerTimes[index])
            if !name.isEmpty && !time.isEmpty {
                entries.append(PrayerEntry(name: name, time: time))
            }
        }
        return entries
    }

    private func dailyPrayersFromSchedule(for date: Date) -> [PrayerEntry]? {
        let raw = string(WatchDataKeys.dailyPrayerSchedule)
        guard
            !raw.isEmpty,
            let data = raw.data(using: .utf8),
            let days = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        let calendar = Calendar.current
        let match = days.first { day in
            guard let start = day["start"] as? Double else { return false }
            return calendar.isDate(
                Date(timeIntervalSince1970: start / 1000.0),
                inSameDayAs: date
            )
        }

        guard let items = match?["items"] as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            let name = (item["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let time = (item["time"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !time.isEmpty else { return nil }
            return PrayerEntry(name: name, time: time)
        }
    }
}

struct PrayerEntry: Hashable {
    let name: String
    let time: String
}

struct PrayerScheduleEntry: Hashable {
    let date: Date
    let name: String
    let time: String
    let dateLabel: String
    let secondaryName: String
    let secondaryTime: String
}

/// Decodes the `epochMillis|name|time|dateLabel[|secondaryName|secondaryTime]` records
/// that `HomeScreenWidgetService` joins with `;`.
nonisolated func parsePrayerSchedule(_ rawSchedule: String) -> [PrayerScheduleEntry] {
    rawSchedule
        .split(separator: ";")
        .compactMap { rawEntry in
            let parts = rawEntry
                .split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
                .map(String.init)
            guard parts.count == 4 || parts.count == 6, let epochMillis = Double(parts[0]) else {
                return nil
            }

            return PrayerScheduleEntry(
                date: Date(timeIntervalSince1970: epochMillis / 1000.0),
                name: parts[1],
                time: parts[2],
                dateLabel: parts[3],
                secondaryName: parts.count == 6 ? parts[4] : "",
                secondaryTime: parts.count == 6 ? parts[5] : ""
            )
        }
        .sorted { $0.date < $1.date }
}

/// SF Symbol for a prayer/period name. Shared by the app and the complication.
nonisolated func prayerSymbolName(for prayerName: String) -> String {
    let name = prayerName.lowercased()
    if name.contains("fajr") { return "sunrise" }
    if name.contains("sunrise") { return "sunrise.fill" }
    if name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") { return "sun.max" }
    if name.contains("asr") { return "sun.min" }
    if name.contains("maghrib") || name.contains("sunset") { return "sunset" }
    if name.contains("isha") { return "moon.stars" }
    if name.contains("midnight") { return "moon" }
    return "sun.max"
}
