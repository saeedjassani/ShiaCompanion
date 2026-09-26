import SwiftUI
import WatchKit

struct ContentView: View {
    /// The screens the app can be sent to from outside itself; the prayer list is the
    /// root.
    enum Route: Hashable {
        case counter
        case calendar
    }

    /// Complications open the watch app with a URL rather than a plain launch, so a tap
    /// lands on the screen the complication was showing. Matched on the host so the path
    /// stays free for anything more specific later.
    static let counterURLHost = "tasbeeh"
    static let calendarURLHost = "calendar"

    @EnvironmentObject private var prayerModel: PrayerTimeModel
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    switch prayerModel.state {
                    case .loaded:
                        loadedContent
                    case .waitingForPhone:
                        SyncPromptView(
                            title: "Waiting for iPhone",
                            message: "Open Shia Companion on your iPhone to send prayer times to your watch.",
                            isRequesting: connectivity.isRequesting,
                            errorMessage: connectivity.lastError
                        ) {
                            WatchConnectivityManager.shared.requestSnapshot()
                        }
                    case .needsLocation:
                        SyncPromptView(
                            title: "Location needed",
                            message: "Set your location in Shia Companion on your iPhone, then sync again.",
                            isRequesting: connectivity.isRequesting,
                            errorMessage: connectivity.lastError
                        ) {
                            WatchConnectivityManager.shared.requestSnapshot()
                        }
                    }

                    // Outside the switch: the counter works offline, and the calendar
                    // needs no location, so both stay reachable even when the phone has
                    // never synced prayer times.
                    calendarLink
                    counterLink
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .counter:
                    CounterView()
                case .calendar:
                    IslamicCalendarScreen()
                }
            }
        }
        .onOpenURL { url in
            // Assigning rather than appending: a second tap on the complication while the
            // screen is already open should leave one copy on the stack, not two.
            switch url.host {
            case Self.counterURLHost:
                path = [.counter]
            case Self.calendarURLHost:
                path = [.calendar]
            default:
                break
            }
        }
    }

    /// Today's hijri date, and a way into the upcoming events. Hidden until the phone
    /// has sent the calendar at least once.
    @ViewBuilder
    private var calendarLink: some View {
        if let day = prayerModel.hijriDay {
            NavigationLink(value: Route.calendar) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.dateLine)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(day.event.isEmpty ? "Upcoming events" : day.event)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Self.gutter)
        }
    }

    private var counterLink: some View {
        NavigationLink(value: Route.counter) {
            Label("Tasbeeh Counter", systemImage: "hand.tap.fill")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, Self.gutter)
        .padding(.bottom, 4)
    }

    private var loadedContent: some View {
        VStack(spacing: 12) {
            // Header with location
            if !prayerModel.location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Text(prayerModel.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }

            // Up Next Banner
            if !prayerModel.nextPrayerName.isEmpty {
                VStack(spacing: 4) {
                    Text(nextPrayerHeading)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(prayerModel.nextPrayerName)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(prayerModel.nextPrayerTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let date = prayerModel.nextPrayerDate {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                )
            }

            // The next few of the times chosen in Settings — the same rolling window
            // the phone's home card and the prayer times widget show, rather than the
            // calendar day's list, so the watch never sits on times that have passed.
            if !prayerModel.prayerEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(prayerModel.prayerEntries.enumerated()), id: \.offset) { index, entry in
                        // The day is named once, where the list crosses into it, the way
                        // the phone's card tags only the first column that has rolled
                        // over. Repeating "Tomorrow" down every remaining row said the
                        // same thing four times on a screen with no room to say it once.
                        if let label = dayBreakLabel(at: index) {
                            DayBreak(label: label)
                        }

                        PrayerRow(entry: entry, isNext: index == 0)

                        // The break draws its own rule, so a plain divider here would
                        // double it.
                        if index < prayerModel.prayerEntries.count - 1,
                           dayBreakLabel(at: index + 1) == nil {
                            Divider()
                                .padding(.leading, 34)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.12))
                )
            }

            Button {
                WatchConnectivityManager.shared.requestSnapshot()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)

            if let lastSync = prayerModel.lastSyncDate {
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Self.gutter)
    }

    /// The label for a day change landing on `index`, or `nil` where the day carries on.
    ///
    /// Compares against the row before rather than testing for "not today", so a list
    /// that somehow spans two midnights names both days instead of lumping them under
    /// one heading. In practice a selection of three to five times crosses at most one.
    private func dayBreakLabel(at index: Int) -> String? {
        let entries = prayerModel.prayerEntries
        guard index < entries.count else { return nil }
        let label = entries[index].dayLabel
        guard !label.isEmpty else { return nil }
        guard index > 0 else { return label }
        return entries[index - 1].dayLabel == label ? nil : label
    }

    /// Explicit rather than `.padding(.horizontal)`: the default is a platform-defined
    /// amount, and on a 162pt screen the difference between 8 and 16 a side is a tenth
    /// of the row the prayer times have to fit in.
    static let gutter: CGFloat = 8

    private var nextPrayerHeading: String {
        let label = prayerModel.nextPrayerDayLabel
        guard !label.isEmpty, label != "Today" else { return "Up Next" }
        return "Up Next · \(label)"
    }
}

// MARK: - Sync prompt

struct SyncPromptView: View {
    let title: String
    let message: String
    let isRequesting: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title3)
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if isRequesting {
                ProgressView()
            } else {
                Button(action: onRetry) {
                    Label("Sync now", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            if let errorMessage = errorMessage, !isRequesting {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Prayer row

/// One upcoming time. Which day it belongs to is `DayBreak`'s job, above the first row
/// of that day — the row itself is only ever a name and a time.
///
/// `.footnote`, not `.body`: an icon, a name and a time side by side on a 162pt screen
/// come to more than the row holds at `.body`'s 17pt, and the name was the one losing
/// its tail — measured truncating on every watch up to 45mm at the default text size.
/// The time carries the layout priority, and where the name still cannot fit it becomes
/// its initial rather than a clipped word.
struct PrayerRow: View {
    let entry: UpcomingPrayerRow
    let isNext: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 0) {
            PrayerIcon(prayerName: entry.name)
                .frame(width: 22, height: 22)
                .padding(.trailing, 6)

            if dynamicTypeSize >= .xxxLarge {
                // From xxxLarge up the two never fit on one line however far they
                // shrink, so the time goes under the name instead of being elided.
                // The threshold is a size below the accessibility ones because that is
                // where the measurements say the row gives out, not where the API
                // happens to draw its line.
                VStack(alignment: .leading, spacing: 0) {
                    name
                    time
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                name
                Spacer(minLength: 4)
                time.layoutPriority(1)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }

    private var name: some View {
        // No `minimumScaleFactor`: the name is either the whole word at its proper size
        // or the initial. Half-shrunk text on a watch is the worst of the three.
        PrayerNameText(
            name: entry.name,
            font: .footnote,
            color: isNext ? .accentColor : .primary
        )
    }

    private var time: some View {
        Text(entry.time)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// Names the day the rows below it belong to. A rule rather than a row of its own, so
/// the list still reads as one card of times with a seam in it.
struct DayBreak: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

// MARK: - Islamic calendar

/// Today's hijri date and the events coming up after it.
struct IslamicCalendarScreen: View {
    @EnvironmentObject private var prayerModel: PrayerTimeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let day = prayerModel.hijriDay {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: String(day.day))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(day.month)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(verbatim: "\(day.year) AH")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if !day.event.isEmpty {
                            EventLine(title: day.event, color: day.color)
                                .padding(.top, 4)
                        }
                    }
                }

                if prayerModel.upcomingEvents.isEmpty {
                    Text("Open Shia Companion on your iPhone to sync the calendar.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Upcoming")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(prayerModel.upcomingEvents.enumerated()), id: \.offset) { index, event in
                            UpcomingEventRow(event: event)
                            if index < prayerModel.upcomingEvents.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, ContentView.gutter)
        }
        .navigationTitle("Calendar")
    }
}

private struct EventLine: View {
    let title: String
    let color: Int

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Circle()
                .fill(islamicEventColor(color))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(title)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct UpcomingEventRow: View {
    let event: IslamicEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            EventLine(title: event.title, color: event.color)
            Text(verbatim: "\(relativeDayLabel(event.start)) · \(event.hijri)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.leading, 11)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Prayer Icon

struct PrayerIcon: View {
    let prayerName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
            PrayerGlyphView(name: prayerName, color: .accentColor)
                .frame(width: 13, height: 13)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let model = PrayerTimeModel()
        model.state = .loaded
        model.location = "Karbala"
        model.nextPrayerName = "Maghrib"
        model.nextPrayerTime = "7:30 pm"
        model.nextPrayerDate = Date().addingTimeInterval(3600)
        model.prayerEntries = [
            UpcomingPrayerRow(name: "Maghrib", time: "7:30 pm", dayLabel: ""),
            UpcomingPrayerRow(name: "Isha", time: "8:45 pm", dayLabel: ""),
            UpcomingPrayerRow(name: "Fajr", time: "4:30 am", dayLabel: "Tomorrow"),
            UpcomingPrayerRow(name: "Zuhr", time: "12:15 pm", dayLabel: "Tomorrow"),
            UpcomingPrayerRow(name: "Asr", time: "4:00 pm", dayLabel: "Tomorrow"),
        ]
        return ContentView()
            .environmentObject(model)
            .environmentObject(CounterModel())
    }
}
#endif
