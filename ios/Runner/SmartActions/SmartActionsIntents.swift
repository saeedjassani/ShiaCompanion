import AppIntents
import Foundation

// The actions Shia Companion offers Siri and the Shortcuts app. Playing and
// opening go through Dart (`SmartActionsBridge`); prayer times and the Hijri
// date are read straight from what the app writes for its widgets.

@available(iOS 17.0, *)
struct PlayPlaylistIntent: AudioPlaybackIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Play Playlist"
    static var description = IntentDescription(
        "Plays one of your Shia Companion playlists, on the lock screen like any playlist."
    )

    @Parameter(title: "Playlist", requestValueDialog: "Which playlist?")
    var playlist: PlaylistEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$playlist)")
    }

    init() {}

    init(playlist: PlaylistEntity) {
        self.playlist = playlist
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await startPlayback(for: self, method: "playPlaylist", arguments: ["id": playlist.id])
        return .result()
    }
}

@available(iOS 17.0, *)
struct PlayRecitationIntent: AudioPlaybackIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Play Dua"
    static var description = IntentDescription(
        "Plays the recitation of a dua, ziyarat or surah."
    )

    @Parameter(title: "Dua", requestValueDialog: "Which dua?")
    var recitation: RecitationEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$recitation)")
    }

    init() {}

    init(recitation: RecitationEntity) {
        self.recitation = recitation
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await startPlayback(for: self, method: "playZikr", arguments: ["uid": recitation.id])
        return .result()
    }
}

/// Starts playback through Dart. When Dart isn't running - iOS launched the
/// app in the background just for this, and Flutter only starts with the
/// app's window - the app opens, and the bridge plays once Dart is up.
@available(iOS 17.0, *)
@MainActor
private func startPlayback<Intent: ForegroundContinuableIntent>(
    for intent: Intent,
    method: String,
    arguments: [String: Any]
) async throws {
    let bridge = SmartActionsBridge.shared
    if await bridge.waitUntilReady(timeout: 3) {
        try await bridge.run(method, arguments)
        return
    }
    bridge.runWhenReady(method, arguments)
    throw intent.needsToContinueInForegroundError(
        "Shia Companion needs to open to start playing.",
        alwaysConfirm: false
    )
}

@available(iOS 17.0, *)
struct OpenZikrIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open Dua"
    static var description = IntentDescription(
        "Opens a dua, ziyarat or surah in Shia Companion."
    )

    @Parameter(title: "Dua", requestValueDialog: "Which dua?")
    var target: ZikrEntity

    init() {}

    init(target: ZikrEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let bridge = SmartActionsBridge.shared
        guard await bridge.waitUntilReady(timeout: 20) else {
            throw SmartActionError.appUnavailable
        }
        try await bridge.run("openLink", ["url": target.link])
        return .result()
    }
}

/// A prayer and its time, so a shortcut can use either.
@available(iOS 17.0, *)
struct PrayerTimeEntity: TransientAppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Prayer Time"

    @Property(title: "Prayer")
    var name: String

    @Property(title: "Time")
    var time: Date

    @Property(title: "Time as Text")
    var timeText: String

    init() {}

    init(_ reading: PrayerTimeReading) {
        name = reading.name
        time = reading.date
        timeText = reading.time
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(timeText)")
    }
}

@available(iOS 17.0, *)
struct GetNextPrayerTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Prayer Time"
    static var description = IntentDescription(
        "The next prayer time at your location, as Shia Companion works it out."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<PrayerTimeEntity> & ProvidesDialog {
        let now = Date()
        guard let next = SmartActionsCatalog.prayerSchedule().first(where: { $0.date > now }) else {
            throw SmartActionError.noPrayerTimes
        }
        let dialog: IntentDialog
        if let location = SmartActionsCatalog.prayerLocation {
            dialog = "\(next.name) is at \(next.time) in \(location)."
        } else {
            dialog = "\(next.name) is at \(next.time)."
        }
        return .result(value: PrayerTimeEntity(next), dialog: dialog)
    }
}

@available(iOS 17.0, *)
struct GetTodaysPrayerTimesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Prayer Times"
    static var description = IntentDescription(
        "Today's prayer times at your location - the ones you chose to show on widgets."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<[PrayerTimeEntity]> & ProvidesDialog {
        let today = SmartActionsCatalog.prayerSchedule()
            .filter { Calendar.current.isDateInToday($0.date) }
        guard !today.isEmpty else { throw SmartActionError.noPrayerTimes }
        let list = today.map { "\($0.name) \($0.time)" }.joined(separator: ", ")
        return .result(value: today.map(PrayerTimeEntity.init), dialog: "\(list)")
    }
}

@available(iOS 17.0, *)
struct GetHijriDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Hijri Date"
    static var description = IntentDescription(
        "Today's date in the Islamic calendar, with any event on it, as Shia Companion's calendar has it."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let today = SmartActionsCatalog.hijriDay() else {
            throw SmartActionError.noHijriDate
        }
        let date = "\(today.day) \(today.month) \(today.year)"
        let dialog: IntentDialog
        if today.event.isEmpty {
            dialog = "Today is \(date)."
        } else {
            dialog = "Today is \(date): \(today.event)."
        }
        return .result(value: date, dialog: dialog)
    }
}
