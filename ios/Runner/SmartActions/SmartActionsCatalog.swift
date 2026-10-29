import Foundation

/// One of the reader's playlists, as Dart describes it.
struct CatalogPlaylist: Decodable {
    let id: String
    /// The stored name: a starter playlist's English one ("Thursday Night"),
    /// or the reader's own.
    let name: String
    /// The name the app shows, when that differs (a starter playlist in Urdu).
    let subtitle: String?
}

/// One zikr - a dua, ziyarat, surah - as Dart describes it.
struct CatalogZikr: Decodable {
    /// The `zikr.json` key, which may be an alias (`AC5|E31`).
    let id: String
    /// The content uid it plays and opens (`E31`).
    let uid: String
    /// The English title without its Arabic script: what Siri can match.
    let name: String
    /// The title in the reader's zikr language, when that is not English.
    let subtitle: String?
    let link: String
    let audio: Bool
    /// Its slugs as words, old spellings included ("dua kumail").
    let keywords: [String]
}

/// A prayer time the app worked out for the home screen widgets.
struct PrayerTimeReading {
    let date: Date
    let name: String
    /// The time as the app writes it ("5:42 PM").
    let time: String
}

/// Today's date in the Islamic calendar, from the calendar widgets' data.
struct HijriDay {
    let day: Int
    let month: String
    let year: Int
    /// Today's event, or empty.
    let event: String
}

/// What the intents read without Dart: the catalog Dart last sent, and the
/// prayer times and calendar the app already writes to the app group for
/// its widgets (`HomeScreenWidgetService`). Shortcuts asks for these while
/// the app is not running, so they have to be on disk.
enum SmartActionsCatalog {
    private static let appGroupID = "group.com.developer110.shiacompanion"
    private static let playlistsKey = "sc_smart_playlists"
    private static let zikrsKey = "sc_smart_zikrs"
    private static let prayerScheduleKey = "sc_prayer_schedule"
    private static let prayerLocationKey = "sc_prayer_location"
    private static let calendarDaysKey = "sc_calendar_days"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(playlists: String?, zikrs: String?) {
        guard let defaults else { return }
        if let playlists { defaults.set(playlists, forKey: playlistsKey) }
        if let zikrs { defaults.set(zikrs, forKey: zikrsKey) }
    }

    static func playlists() -> [CatalogPlaylist] {
        decode(playlistsKey)
    }

    static func zikrs() -> [CatalogZikr] {
        decode(zikrsKey)
    }

    /// The zikr catalog as Dart sent it, for telling whether it changed.
    static var rawZikrs: String? {
        defaults?.string(forKey: zikrsKey)
    }

    private static func decode<T: Decodable>(_ key: String) -> [T] {
        guard
            let raw = defaults?.string(forKey: key),
            let data = raw.data(using: .utf8)
        else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    /// Whether every word of `query` starts a word of one of `candidates`,
    /// ignoring case and accents: "kumail" finds Dua Kumayl through its old
    /// spelling, "thursday" finds Thursday Night.
    static func matches(_ query: String, _ candidates: [String]) -> Bool {
        let wanted = words(query)
        if wanted.isEmpty { return true }
        return candidates.contains { candidate in
            let have = words(candidate)
            return wanted.allSatisfy { word in have.contains { $0.hasPrefix(word) } }
        }
    }

    private static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// The upcoming week of prayer times, soonest first. Same format as the
    /// prayer widget reads: `epochMillis|name|time|label[|name|time]`, `;`
    /// between entries.
    static func prayerSchedule() -> [PrayerTimeReading] {
        (defaults?.string(forKey: prayerScheduleKey) ?? "")
            .split(separator: ";")
            .compactMap { entry -> PrayerTimeReading? in
                let parts = entry
                    .split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
                    .map(String.init)
                guard parts.count >= 3, let millis = Double(parts[0]) else { return nil }
                return PrayerTimeReading(
                    date: Date(timeIntervalSince1970: millis / 1000),
                    name: parts[1],
                    time: parts[2]
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// The city the prayer times are for, when the app knows it.
    static var prayerLocation: String? {
        let location = defaults?.string(forKey: prayerLocationKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return location?.isEmpty == false ? location : nil
    }

    /// Today in the Islamic calendar: the last day starting by `now`, unless
    /// the run the app wrote has ended (a day lasts at most 25 hours, DST).
    static func hijriDay(at now: Date = Date()) -> HijriDay? {
        guard
            let data = defaults?.string(forKey: calendarDaysKey)?.data(using: .utf8),
            let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        let today = entries
            .compactMap { entry -> (start: Date, entry: [String: Any])? in
                guard let millis = (entry["start"] as? NSNumber)?.doubleValue else { return nil }
                return (Date(timeIntervalSince1970: millis / 1000), entry)
            }
            .filter { $0.start <= now && now.timeIntervalSince($0.start) < 25 * 3600 }
            .max { $0.start < $1.start }
        guard
            let entry = today?.entry,
            let day = (entry["day"] as? NSNumber)?.intValue, day > 0,
            let year = (entry["year"] as? NSNumber)?.intValue,
            let month = entry["month"] as? String, !month.isEmpty
        else { return nil }
        let event = (entry["event"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return HijriDay(day: day, month: month, year: year, event: event)
    }
}
