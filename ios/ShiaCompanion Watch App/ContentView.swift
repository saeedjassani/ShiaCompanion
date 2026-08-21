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
        .padding(.horizontal)
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
                        .lineLimit(1)
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
                    Text(prayerModel.nextPrayerTime)
                        .font(.title2)
                        .fontWeight(.bold)
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
                                .padding(.leading, 40)
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
        .padding(.horizontal)
    }

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
struct PrayerRow: View {
    let entry: UpcomingPrayerRow
    let isNext: Bool

    var body: some View {
        HStack(spacing: 0) {
            PrayerIcon(prayerName: entry.name)
                .frame(width: 24, height: 24)
                .padding(.trailing, 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.name)
                    .font(.body)
                    .foregroundColor(isNext ? .accentColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !entry.dayLabel.isEmpty {
                    Text(entry.dayLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(entry.time)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
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
