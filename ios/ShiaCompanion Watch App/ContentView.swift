import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var prayerModel: PrayerTimeModel
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    var body: some View {
        NavigationStack {
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
        }
    }

    private var counterLink: some View {
        NavigationLink {
            CounterView()
        } label: {
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

            // All Prayer Times List
            if !prayerModel.prayerEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(prayerModel.prayerEntries.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            PrayerIcon(prayerName: entry.name)
                                .frame(width: 24, height: 24)
                            Text(entry.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(entry.time)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)

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
            PrayerEntry(name: "Fajr", time: "4:30 am"),
            PrayerEntry(name: "Zuhr", time: "12:15 pm"),
            PrayerEntry(name: "Asr", time: "4:00 pm"),
            PrayerEntry(name: "Maghrib", time: "7:30 pm"),
            PrayerEntry(name: "Isha", time: "8:45 pm"),
        ]
        return ContentView()
            .environmentObject(model)
            .environmentObject(CounterModel())
    }
}
#endif
