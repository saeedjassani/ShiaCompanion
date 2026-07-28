import Combine
import SwiftUI
import WatchKit

@main
struct ShiaCompanion_Watch_AppApp: App {
    @StateObject private var prayerModel = PrayerTimeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(prayerModel)
                .onAppear {
                    WatchConnectivityManager.shared.activate()
                    prayerModel.refresh()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                WatchConnectivityManager.shared.requestSnapshot()
                prayerModel.refresh()
            }
        }
    }
}

// MARK: - Prayer Time Model

final class PrayerTimeModel: ObservableObject {
    @Published var prayerEntries: [PrayerEntry] = []
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
        prayerEntries = state == .loaded ? store.dailyPrayers(for: now) : []

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
