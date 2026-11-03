import AppIntents

/// The phrases Siri knows without anyone setting anything up, and the
/// actions the Shortcuts app lists under Shia Companion. Every phrase has to
/// name the app; a `\(\.$playlist)` slot matches the names the catalog last
/// gave Siri (`updateAppShortcutParameters()` in `SmartActionsBridge`).
///
/// English only for now. Siri has no Urdu, Persian or Gujarati; Arabic
/// phrases would go in an `AppShortcuts.xcstrings`.
@available(iOS 17.0, *)
struct ShiaCompanionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPlaylistIntent(),
            phrases: [
                "Play \(\.$playlist) in \(.applicationName)",
                "Play my \(\.$playlist) playlist in \(.applicationName)",
                "Play a playlist in \(.applicationName)",
            ],
            shortTitle: "Play Playlist",
            systemImageName: "music.note.list"
        )
        AppShortcut(
            intent: PlayRecitationIntent(),
            phrases: [
                "Play \(\.$recitation) in \(.applicationName)",
                "Recite \(\.$recitation) with \(.applicationName)",
                "Play a dua in \(.applicationName)",
            ],
            shortTitle: "Play Dua",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: OpenZikrIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Read \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Dua",
            systemImageName: "book"
        )
        AppShortcut(
            intent: GetNextPrayerTimeIntent(),
            phrases: [
                "When is the next prayer in \(.applicationName)",
                "Next prayer time in \(.applicationName)",
            ],
            shortTitle: "Next Prayer",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: GetTodaysPrayerTimesIntent(),
            phrases: [
                "Prayer times today in \(.applicationName)",
                "Today's prayer times in \(.applicationName)",
            ],
            shortTitle: "Today's Prayer Times",
            systemImageName: "sun.horizon"
        )
        AppShortcut(
            intent: GetHijriDateIntent(),
            phrases: [
                "What is the Hijri date in \(.applicationName)",
                "Islamic date in \(.applicationName)",
            ],
            shortTitle: "Hijri Date",
            systemImageName: "moon"
        )
    }
}
