import SwiftUI
import WatchKit

struct ContentView: View {
    @EnvironmentObject private var prayerModel: PrayerTimeModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with location
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

                // Next Prayer Banner
                if !prayerModel.nextPrayerName.isEmpty {
                    VStack(spacing: 4) {
                        Text("Next Prayer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(prayerModel.nextPrayerName)
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Text(prayerModel.nextPrayerTime)
                            .font(.title2)
                            .fontWeight(.bold)
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
                VStack(spacing: 0) {
                    ForEach(Array(prayerModel.prayerEntries.enumerated()), id: \.offset) { _, entry in
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

                        if entry.name != prayerModel.prayerEntries.last?.name {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.12))
                )

                // Refresh hint
                Text("Open Shia Companion app to refresh")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Prayer Icon

struct PrayerIcon: View {
    let prayerName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
        }
    }

    private var symbolName: String {
        let name = prayerName.lowercased()
        if name.contains("fajr") { return "sunrise" }
        if name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") { return "sun.max" }
        if name.contains("asr") { return "sun.min" }
        if name.contains("maghrib") { return "sunset" }
        if name.contains("isha") { return "moon.stars" }
        return "sun.max"
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let model = PrayerTimeModel()
        model.location = "Karbala"
        model.nextPrayerName = "Maghrib"
        model.nextPrayerTime = "7:30 pm"
        model.prayerEntries = [
            PrayerEntry(name: "Fajr", time: "4:30 am"),
            PrayerEntry(name: "Zuhr", time: "12:15 pm"),
            PrayerEntry(name: "Asr", time: "4:00 pm"),
            PrayerEntry(name: "Maghrib", time: "7:30 pm"),
            PrayerEntry(name: "Isha", time: "8:45 pm"),
        ]
        return ContentView()
            .environmentObject(model)
    }
}
#endif