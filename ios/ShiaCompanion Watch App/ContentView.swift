import SwiftUI
import WatchKit

struct ContentView: View {
    /// The screens the app can be sent to from outside itself. Only the counter has a
    /// destination today; the prayer list is the root.
    enum Route: Hashable {
        case counter
    }

    /// Complications open the watch app with a URL rather than a plain launch, so a tap
    /// lands on the screen the complication was showing. Matched on the host so the path
    /// stays free for anything more specific later.
    static let counterURLHost = "tasbeeh"

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

                    // Outside the switch: the counter works offline, so it stays reachable
                    // even when the phone has never synced prayer times.
                    counterLink
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .counter:
                    CounterView()
                }
            }
        }
        .onOpenURL { url in
            guard url.host == Self.counterURLHost else { return }
            // Assigning rather than appending: a second tap on the complication while the
            // counter is already open should leave one counter on the stack, not two.
            path = [.counter]
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
                        PrayerRow(entry: entry, isNext: index == 0)

                        if index < prayerModel.prayerEntries.count - 1 {
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

/// One upcoming time. The day label only appears once the list has rolled past
/// midnight, so a today-only list reads exactly as it did before.
///
/// `.footnote`, not `.body`: an icon, a name and a time side by side on a 162pt screen
/// come to more than the row holds at `.body`'s 17pt, and the name was the one losing
/// its tail — measured truncating on every watch up to 45mm at the default text size.
/// The time carries the layout priority, because a shortened name ("Maghri…") is still
/// recognisable and a shortened time is not.
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
                    day
                    time
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    name
                    day
                }
                Spacer(minLength: 4)
                time.layoutPriority(1)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
    }

    private var name: some View {
        Text(entry.name)
            .font(.footnote)
            .foregroundColor(isNext ? .accentColor : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var day: some View {
        if !entry.dayLabel.isEmpty {
            Text(entry.dayLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var time: some View {
        Text(entry.time)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Prayer Icon

struct PrayerIcon: View {
    let prayerName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
            Image(systemName: prayerSymbolName(for: prayerName))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
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
