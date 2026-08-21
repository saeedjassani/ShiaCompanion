import Combine
import SwiftUI
import WatchKit

@main
struct ShiaCompanion_Watch_AppApp: App {
    @StateObject private var prayerModel = PrayerTimeModel()
    /// Owned by the app so the count survives navigating away from the counter screen.
    @StateObject private var counterModel = CounterModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prayerModel)
                .environmentObject(counterModel)
                .onAppear {
                    WatchConnectivityManager.shared.activate()
                    prayerModel.refresh()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                WatchConnectivityManager.shared.requestSnapshot()
                prayerModel.refresh()
            } else {
                // Leaving the foreground is the last chance to push a debounced count to
                // the complication before the app is suspended.
                counterModel.flushComplicationReload()
            }
        }
    }
}

// MARK: - Prayer Time Model

/// One row of the watch's prayer list. Carries the day label so a row that has
/// rolled over into tomorrow can say so, the way the phone's card does.
struct UpcomingPrayerRow: Hashable {
    let name: String
    let time: String
    /// Empty for today; "Tomorrow" or a date for anything further out.
    let dayLabel: String
}

final class PrayerTimeModel: ObservableObject {
    @Published var prayerEntries: [UpcomingPrayerRow] = []
    @Published var location: String = ""
    @Published var nextPrayerName: String = ""
    @Published var nextPrayerTime: String = ""
    @Published var nextPrayerDate: Date?
    @Published var nextPrayerDayLabel: String = ""
    @Published var state: State = .waitingForPhone
    @Published var lastSyncDate: Date?

    enum State {
        /// The phone has never sent a snapshot.
        case waitingForPhone
        /// Synced, but the phone app has no location saved yet.
        case needsLocation
        case loaded
    }

    private let store = PrayerDataStore.shared
    private var observer: NSObjectProtocol?
    private var rolloverTimer: Timer?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .prayerDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        rolloverTimer?.invalidate()
    }

    func refresh() {
        let now = Date()
        if !store.hasSyncedData {
            state = .waitingForPhone
        } else if !store.hasPrayerTimes {
            state = .needsLocation
        } else {
            state = .loaded
        }
        lastSyncDate = store.lastSyncDate
        location = store.location
        prayerEntries = state == .loaded ? upcomingRows(at: now) : []

        if let next = store.nextPrayer(after: now) {
            nextPrayerName = next.name
            nextPrayerTime = next.time
            nextPrayerDate = next.date
            nextPrayerDayLabel = next.dateLabel
        } else {
            nextPrayerName = ""
            nextPrayerTime = ""
            nextPrayerDate = nil
            nextPrayerDayLabel = ""
        }

        scheduleRollover(after: now)
    }

    /// The same rolling window the phone's home card and the prayer times widget show:
    /// the next N of the times chosen in Settings, carrying on into tomorrow rather than
    /// stopping at the end of today.
    ///
    /// Falls back to the day's times only if the schedule holds nothing upcoming — that
    /// means a snapshot old enough to have run out, and a stale list still beats none.
    private func upcomingRows(at now: Date) -> [UpcomingPrayerRow] {
        let upcoming = store.upcomingPrayers(after: now, limit: store.selectedPrayerCount)
        if !upcoming.isEmpty {
            return upcoming.map { entry in
                UpcomingPrayerRow(
                    name: entry.name,
                    time: entry.time,
                    dayLabel: entry.dateLabel == "Today" ? "" : entry.dateLabel
                )
            }
        }
        return store.dailyPrayers(for: now).map {
            UpcomingPrayerRow(name: $0.name, time: $0.time, dayLabel: "")
        }
    }

    /// Re-derive the "next" prayer the moment the current one passes, so an open watch
    /// app doesn't sit on a stale banner.
    private func scheduleRollover(after now: Date) {
        rolloverTimer?.invalidate()
        guard let next = nextPrayerDate, next > now else { return }
        let interval = min(next.timeIntervalSince(now) + 1, 60 * 60)
        rolloverTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
    }
}
