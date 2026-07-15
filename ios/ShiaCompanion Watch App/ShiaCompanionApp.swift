import SwiftUI
import WatchKit

private let appGroupID = "group.com.developer110.shiacompanion"

@main
struct ShiaCompanion_Watch_AppApp: App {
    @StateObject private var prayerModel = PrayerTimeModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prayerModel)
                .onAppear {
                    prayerModel.refresh()
                }
        }
    }
}

// MARK: - Prayer Time Model

class PrayerTimeModel: ObservableObject {
    @Published var prayerEntries: [PrayerEntry] = []
    @Published var location: String = ""
    @Published var nextPrayerName: String = ""
    @Published var nextPrayerTime: String = ""

    private let dailyPrayerNameKeys = (1...5).map { "sc_daily_prayer_name_\($0)" }
    private let dailyPrayerTimeKeys = (1...5).map { "sc_daily_prayer_time_\($0)" }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func refresh() {
        loadDailyPrayerTimes()
        loadNextPrayer()
    }

    private func loadDailyPrayerTimes() {
        guard let defaults = defaults else { return }

        location = defaults.widgetString("sc_prayer_location", fallback: "Set location in app")

        var entries: [PrayerEntry] = []
        for i in 0..<5 {
            let name = defaults.widgetString(dailyPrayerNameKeys[i], fallback: i == 0 ? "Open app" : "")
            let time = defaults.widgetString(dailyPrayerTimeKeys[i], fallback: i == 0 ? "Set location" : "")
            if !name.isEmpty || !time.isEmpty {
                entries.append(PrayerEntry(name: name, time: time))
            }
        }
        prayerEntries = entries
    }

    private func loadNextPrayer() {
        guard let defaults = defaults else { return }
        let schedule = parsePrayerSchedule(defaults.string(forKey: "sc_prayer_schedule") ?? "")
        let now = Date()
        if let next = schedule.first(where: { $0.date > now }) {
            nextPrayerName = next.name
            nextPrayerTime = next.time
        }
    }
}

struct PrayerEntry {
    let name: String
    let time: String
}

private struct PrayerScheduleEntry {
    let date: Date
    let name: String
    let time: String
    let dateLabel: String
    let secondaryName: String
    let secondaryTime: String
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
                dateLabel: parts[3],
                secondaryName: parts.count == 6 ? parts[4] : "",
                secondaryTime: parts.count == 6 ? parts[5] : ""
            )
        }
        .sorted { $0.date < $1.date }
}

private extension UserDefaults {
    func widgetString(_ key: String, fallback: String) -> String {
        let value = string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : fallback
    }
}