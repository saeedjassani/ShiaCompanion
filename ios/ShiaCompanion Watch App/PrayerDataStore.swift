import Foundation
import SwiftUI

/// Keys shared with the Flutter app (`HomeScreenWidgetService`) and the iOS widgets.
///
/// NOTE: app group containers are *not* shared between iOS and watchOS — the same
/// group identifier resolves to a different, device-local container on the watch.
/// Everything in here is written by `WatchConnectivityManager` from payloads that
/// the iPhone pushes over `WCSession`, and read back by both the watch app and the
/// complication extension (which do share this container, since both live on the watch).
///
/// `nonisolated`: the Watch App target defaults new declarations to `@MainActor`, but
/// these keys are read from `WCSessionDelegate` callbacks off the main actor.
nonisolated enum WatchDataKeys {
    static let prayerLocation = "sc_prayer_location"
    static let prayerSchedule = "sc_prayer_schedule"
    static let prayerName = "sc_prayer_name"
    static let prayerTime = "sc_prayer_time"
    static let prayerDate = "sc_prayer_date"
    static let prayerSecondaryName = "sc_prayer_secondary_name"
    static let prayerSecondaryTime = "sc_prayer_secondary_time"

    static let dailyPrayerNames = (1...6).map { "sc_daily_prayer_name_\($0)" }
    static let dailyPrayerTimes = (1...6).map { "sc_daily_prayer_time_\($0)" }
    static let dailyPrayerSchedule = "sc_daily_prayer_schedule"

    /// Epoch millis of the last payload the phone sent. Absent until the first sync.
    static let updatedAt = "sc_watch_updated_at"

    static let all: [String] =
        [
            prayerLocation,
            prayerSchedule,
            prayerName,
            prayerTime,
            prayerDate,
            prayerSecondaryName,
            prayerSecondaryTime,
            dailyPrayerSchedule,
            updatedAt,
        ] + dailyPrayerNames + dailyPrayerTimes
}

nonisolated let watchAppGroupID = "group.com.developer110.shiacompanion"

/// Local storage for the last snapshot received from the iPhone.
///
/// Stateless (the container is the source of truth) so it can be read from any thread.
/// Explicitly `nonisolated`: the Watch App target defaults new declarations to
/// `@MainActor`, but `WatchConnectivityManager` reads and writes this from
/// `WCSessionDelegate` callbacks that arrive off the main actor.
nonisolated struct PrayerDataStore: Sendable {
    static let shared = PrayerDataStore()

    /// Falls back to `.standard` so a missing/misconfigured app group degrades to
    /// "watch app works, complication doesn't" instead of "nothing works".
    var defaults: UserDefaults { UserDefaults(suiteName: watchAppGroupID) ?? .standard }

    /// `true` once the phone has sent at least one snapshot.
    var hasSyncedData: Bool {
        defaults.object(forKey: WatchDataKeys.updatedAt) != nil
    }

    /// `true` when the synced snapshot actually contains prayer times. The phone
    /// publishes placeholder rows ("Set location" / "Open app") when no location has
    /// been chosen yet, and those must not be rendered as prayer times.
    var hasPrayerTimes: Bool {
        !string(WatchDataKeys.prayerSchedule).isEmpty
    }

    var lastSyncDate: Date? {
        let millis = defaults.double(forKey: WatchDataKeys.updatedAt)
        guard millis > 0 else { return nil }
        return Date(timeIntervalSince1970: millis / 1000.0)
    }

    var location: String {
        string(WatchDataKeys.prayerLocation)
    }

    func string(_ key: String) -> String {
        (defaults.string(forKey: key) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Merges a payload received from the phone. Only known keys are written so a
    /// malformed/oversized dictionary can't pollute the container.
    func apply(payload: [String: Any]) {
        var wroteSomething = false
        for key in WatchDataKeys.all {
            guard let value = payload[key] else { continue }
            if key == WatchDataKeys.updatedAt {
                defaults.set(Self.doubleValue(value), forKey: key)
            } else {
                defaults.set(Self.stringValue(value), forKey: key)
            }
            wroteSomething = true
        }
        // A payload without an explicit timestamp still counts as a successful sync.
        if wroteSomething, payload[WatchDataKeys.updatedAt] == nil {
            defaults.set(Date().timeIntervalSince1970 * 1000.0, forKey: WatchDataKeys.updatedAt)
        }
    }

    private static func stringValue(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private static func doubleValue(_ value: Any) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String, let parsed = Double(string) { return parsed }
        return Date().timeIntervalSince1970 * 1000.0
    }

    // MARK: - Derived data

    /// The upcoming prayer/period timeline (8 days), sorted ascending.
    var prayerSchedule: [PrayerScheduleEntry] {
        parsePrayerSchedule(string(WatchDataKeys.prayerSchedule))
    }

    func nextPrayer(after date: Date = Date()) -> PrayerScheduleEntry? {
        prayerSchedule.first { $0.date > date }
    }

    /// The next `limit` times from the synced schedule, soonest first.
    ///
    /// The schedule the phone publishes already contains only the times chosen in
    /// Settings, spread over the next eight days, so taking a prefix of it is the same
    /// rolling window the home card and the prayer times widget show — the list carries
    /// on into tomorrow rather than emptying out after the day's last prayer.
    func upcomingPrayers(after date: Date = Date(), limit: Int) -> [PrayerScheduleEntry] {
        guard limit > 0 else { return [] }
        return Array(prayerSchedule.lazy.filter { $0.date > date }.prefix(limit))
    }

    /// How many times the phone's selection holds, so the watch shows the same number of
    /// columns the phone's card does.
    ///
    /// Counted from a day of the published daily schedule rather than sent as its own
    /// key: the phone already writes one entry per selected time per day, and deriving it
    /// keeps the two in step without another key to sync. Settings bounds the selection
    /// to 3–5; anything outside that means a stale or malformed payload, so it falls back
    /// to the five daily prayers.
    var selectedPrayerCount: Int {
        let fallback = 5
        let counts = dailyPrayerCountsPerDay()
        guard let count = counts.first(where: { $0 > 0 }) else { return fallback }
        return (3...5).contains(count) ? count : fallback
    }

    private func dailyPrayerCountsPerDay() -> [Int] {
        let raw = string(WatchDataKeys.dailyPrayerSchedule)
        guard
            !raw.isEmpty,
            let data = raw.data(using: .utf8),
            let days = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return days.map { ($0["items"] as? [[String: Any]])?.count ?? 0 }
    }

    /// The five daily prayer times for the given day.
    ///
    /// Prefers the multi-day JSON schedule so the watch rolls over to the next day on
    /// its own; falls back to the flat `sc_daily_prayer_*` keys (which only ever hold
    /// the day the phone last published).
    func dailyPrayers(for date: Date = Date()) -> [PrayerEntry] {
        if let fromSchedule = dailyPrayersFromSchedule(for: date), !fromSchedule.isEmpty {
            return fromSchedule
        }

        var entries: [PrayerEntry] = []
        for index in 0..<WatchDataKeys.dailyPrayerNames.count {
            let name = string(WatchDataKeys.dailyPrayerNames[index])
            let time = string(WatchDataKeys.dailyPrayerTimes[index])
            if !name.isEmpty && !time.isEmpty {
                entries.append(PrayerEntry(name: name, time: time))
            }
        }
        return entries
    }

    private func dailyPrayersFromSchedule(for date: Date) -> [PrayerEntry]? {
        let raw = string(WatchDataKeys.dailyPrayerSchedule)
        guard
            !raw.isEmpty,
            let data = raw.data(using: .utf8),
            let days = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        let calendar = Calendar.current
        let match = days.first { day in
            guard let start = day["start"] as? Double else { return false }
            return calendar.isDate(
                Date(timeIntervalSince1970: start / 1000.0),
                inSameDayAs: date
            )
        }

        guard let items = match?["items"] as? [[String: Any]] else { return nil }
        return items.compactMap { item in
            let name = (item["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let time = (item["time"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !time.isEmpty else { return nil }
            return PrayerEntry(name: name, time: time)
        }
    }
}

struct PrayerEntry: Hashable {
    let name: String
    let time: String
}

struct PrayerScheduleEntry: Hashable {
    let date: Date
    let name: String
    let time: String
    let dateLabel: String
    let secondaryName: String
    let secondaryTime: String
}

/// Decodes the `epochMillis|name|time|dateLabel[|secondaryName|secondaryTime]` records
/// that `HomeScreenWidgetService` joins with `;`.
nonisolated func parsePrayerSchedule(_ rawSchedule: String) -> [PrayerScheduleEntry] {
    rawSchedule
        .split(separator: ";")
        .compactMap { rawEntry in
            let parts = rawEntry
                .split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)
                .map(String.init)
            guard parts.count == 4 || parts.count == 6, let epochMillis = Double(parts[0]) else {
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

/// First letter of a prayer/period name, for `accessoryCorner`.
///
/// Corner is the one family with no room to negotiate: its curved bezel label
/// sits beside the time, and measured on-device *any* name crops it — a letter
/// is what fits, barely. Every other family gets the whole word.
///
/// Ambiguous by construction, and corner has no symbol slot to lean on, so
/// Sunrise/Sunset both read "S" and Maghrib/Midnight both read "M" with only
/// the time to tell them apart. That is the trade corner forces.
///
/// Taken from the name as the phone sent it rather than a canonical spelling,
/// so the letter always matches the word shown everywhere else in the app —
/// "Dhuhr" reads "D", not "Z".
nonisolated func prayerInitial(for prayerName: String) -> String {
    let trimmed = prayerName.trimmingCharacters(in: .whitespaces)
    return trimmed.first.map { String($0).uppercased() } ?? trimmed
}

/// A prayer name that falls back to its initial rather than to a truncated word.
///
/// "Maghri…" is not a shorter way of writing Maghrib — it is a word the reader has to
/// finish themselves, and a glance at a watch is over before they can. An initial is
/// unambiguous about being shorthand, and it sits beside a symbol that already says
/// which part of the day this is.
///
/// The rungs are tried widest first, and `ViewThatFits` takes the first that fits the
/// width it is offered — so nothing is ever shown half-finished.
///
/// A smaller type style sits between the whole name and the initial, because a name set
/// one step down is still the name, while an initial is ambiguous by construction:
/// Maghrib and Midnight both reduce to "M", and a list can hold both at once. The
/// initial is the last resort, not the first.
@MainActor
struct PrayerNameText: View {
    let name: String
    /// "Tomorrow" and the like. The watch list names the day on its own divider, so only
    /// the complications pass one.
    var dayLabel: String = ""
    var font: Font = .footnote
    /// One step down from `font`, for the middle rung. Both are Dynamic Type styles, so
    /// the pair keeps its relationship at every text size.
    var compactFont: Font = .caption2
    /// Left unset inside complications, where the widget rendering mode owns the colour.
    var color: Color?

    var body: some View {
        if #available(watchOS 10.0, *) {
            let r = paddedRungs
            ViewThatFits(in: .horizontal) {
                label(r[0].0, r[0].1)
                label(r[1].0, r[1].1)
                label(r[2].0, r[2].1)
                label(r[3].0, r[3].1)
                label(r[4].0, r[4].1)
            }
        } else {
            // `ViewThatFits` is watchOS 10. Older watches shrink the name, which is what
            // they did before this existed.
            label(paddedRungs[0].0, font).minimumScaleFactor(0.6)
        }
    }

    /// Widest first: the name with its day label, the name alone, the name a size down,
    /// the initial with the label, the initial alone. Rungs that say nothing new are
    /// dropped, then the list is padded to five so `ViewThatFits` has a fixed set of
    /// children; the padding repeats the last rung, which changes nothing.
    private var rungs: [(String, Font)] {
        let initial = prayerInitial(for: name)
        let long = dayLabel.isEmpty ? name : "\(name) · \(dayLabel)"
        var out: [(String, Font)] = [(long, font)]
        if long != name { out.append((name, font)) }
        out.append((name, compactFont))
        if long != name { out.append(("\(initial) · \(dayLabel)", font)) }
        out.append((initial, font))
        return out
    }

    private var paddedRungs: [(String, Font)] {
        var out = rungs
        while out.count < 5 { out.append(out[out.count - 1]) }
        return out
    }

    @ViewBuilder
    private func label(_ text: String, _ textFont: Font) -> some View {
        let base = Text(text).font(textFont).lineLimit(1)
        if let color {
            base.foregroundColor(color)
        } else {
            base
        }
    }
}

// MARK: - Prayer glyph

/// Which of the eight prayer/time glyphs a name resolves to. Mirrors
/// `PrayerGlyphType` in the Flutter app's `lib/widgets/prayer_glyph.dart` —
/// keep the two in step, since this is what makes the icon on a complication
/// match the one the phone showed for the same prayer.
nonisolated enum PrayerGlyphType {
    case fajr, sunrise, zuhr, asr, sunset, maghrib, isha, midnight, unknown
}

nonisolated func prayerGlyphType(for prayerName: String) -> PrayerGlyphType {
    let name = prayerName.lowercased()
    if name.contains("fajr") { return .fajr }
    if name.contains("sunrise") { return .sunrise }
    if name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") { return .zuhr }
    if name.contains("asr") { return .asr }
    if name.contains("sunset") { return .sunset }
    if name.contains("maghrib") { return .maghrib }
    if name.contains("isha") { return .isha }
    if name.contains("midnight") { return .midnight }
    return .unknown
}

/// Drop-in replacement for `Image(systemName: prayerSymbolName(for: name))`:
/// draws the same horizon/sun/crescent/star glyphs the Flutter app paints in
/// `PrayerGlyph` (`lib/widgets/prayer_glyph.dart`) instead of borrowing SF
/// Symbols that don't match it. Scales to whatever square frame it's given.
///
/// Ported by hand from Flutter's `Canvas` painter to SwiftUI's `Canvas` —
/// the two APIs shape curves differently enough (`arcToPoint` vs `addArc`,
/// no direct equivalent for Flutter's cloud/crescent control points) that
/// the cloud and crescent here are rebuilt from circles rather than
/// transliterated stroke-for-stroke. Everything else — the ray angles, the
/// horizon line, the star — maps straight across. Check this against the
/// app's icon set once built; the shapes were not rendered anywhere to
/// confirm the port before landing.
@available(watchOS 8.0, *)
struct PrayerGlyphView: View {
    let name: String
    var color: Color = .primary

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let scale = side / 24
            context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            PrayerGlyphDrawing.draw(prayerGlyphType(for: name), in: &context, scale: scale, color: color)
        }
    }
}

/// The drawing primitives, namespaced so they can be reused verbatim by the
/// phone widgets target (`ShiaCompanionWidgets.swift`), which cannot import
/// this file directly across targets.
@available(watchOS 8.0, *)
nonisolated enum PrayerGlyphDrawing {
    static func draw(
        _ type: PrayerGlyphType,
        in ctx: inout GraphicsContext,
        scale: CGFloat,
        color: Color
    ) {
        let discStroke: CGFloat = 2.0 * scale
        let rayStroke: CGFloat = 1.7 * scale
        let rays8: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
        let rays5: [Double] = [30, 60, 90, 120, 150]

        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, width: CGFloat) {
            var p = Path()
            p.move(to: CGPoint(x: x1 * scale, y: y1 * scale))
            p.addLine(to: CGPoint(x: x2 * scale, y: y2 * scale))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        func ring(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            let rect = CGRect(x: (cx - r) * scale, y: (cy - r) * scale, width: 2 * r * scale, height: 2 * r * scale)
            ctx.stroke(Path(ellipseIn: rect), with: .color(color), style: StrokeStyle(lineWidth: discStroke, lineCap: .round))
        }

        /// Upper half of a circle resting on the horizon line, open at the bottom —
        /// sunrise/sunset's half-disc.
        func openDome(_ cx: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            var p = Path()
            p.addArc(
                center: CGPoint(x: cx * scale, y: y * scale),
                radius: r * scale,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: discStroke, lineCap: .round))
        }

        func rays(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, gap: CGFloat, len: CGFloat, angles: [Double]) {
            let inner = (r + 1.0 + gap) * scale
            let outer = inner + len * scale
            for a in angles {
                let rad = a * .pi / 180
                let c = cos(rad), s = sin(rad)
                var p = Path()
                p.move(to: CGPoint(x: cx * scale + c * inner, y: cy * scale - s * inner))
                p.addLine(to: CGPoint(x: cx * scale + c * outer, y: cy * scale - s * outer))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: rayStroke, lineCap: .round))
            }
        }

        /// A rounded base with three overlapping bumps on top, filled — reads
        /// as a cloud silhouette rather than the lobed-arc path the app draws,
        /// but at this render size the silhouette is what actually shows.
        func cloud(_ cx: CGFloat, _ baseY: CGFloat, _ cloudScale: CGFloat) {
            let s = cloudScale * scale
            let bx = cx * scale
            let by = baseY * scale
            func bump(_ dx: CGFloat, _ dy: CGFloat, _ r: CGFloat) -> CGRect {
                CGRect(
                    x: bx + dx * s - r * s, y: by + dy * s - r * s,
                    width: 2 * r * s, height: 2 * r * s
                )
            }
            var p = Path()
            let base = CGRect(x: bx - 6.4 * s, y: by - 2.6 * s, width: 12.8 * s, height: 2.6 * s)
            p.addRoundedRect(in: base, cornerSize: CGSize(width: 1.3 * s, height: 1.3 * s))
            p.addEllipse(in: bump(-3.4, -3.4, 3.2))
            p.addEllipse(in: bump(0.4, -5.2, 4.2))
            p.addEllipse(in: bump(4.2, -3.0, 3.0))
            ctx.fill(p, with: .color(color))
        }

        /// A crescent, filled: two overlapping discs, even-odd rule — the
        /// standard way to draw a crescent without matching the app's specific
        /// `arcToPoint` control points stroke-for-stroke. The cut-out circle
        /// has to stay fully inside the outer one with real margin, not just
        /// barely — right at the tangent point, anti-aliasing at these small
        /// render sizes reads as a second sliver on the opposite side, which
        /// is exactly what "not enough margin" looked like here the first
        /// time (an extra thin crescent where there should be none).
        func crescent(_ cx: CGFloat, _ cy: CGFloat, _ crescentScale: CGFloat) {
            let outerR = 9.0 * crescentScale * scale
            let innerR = 6.5 * crescentScale * scale
            let offsetX = 1.2 * crescentScale * scale
            let offsetY = -0.6 * crescentScale * scale
            let outerRect = CGRect(
                x: cx * scale - outerR, y: cy * scale - outerR,
                width: outerR * 2, height: outerR * 2
            )
            let innerRect = CGRect(
                x: cx * scale + offsetX - innerR, y: cy * scale + offsetY - innerR,
                width: innerR * 2, height: innerR * 2
            )
            var p = Path()
            p.addEllipse(in: outerRect)
            p.addEllipse(in: innerRect)
            ctx.fill(p, with: .color(color), style: FillStyle(eoFill: true))
        }

        func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
            let i = r * 0.36
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }
            var p = Path()
            p.move(to: pt(cx, cy - r))
            p.addQuadCurve(to: pt(cx + r, cy), control: pt(cx + i * 0.6, cy - i * 0.6))
            p.addQuadCurve(to: pt(cx, cy + r), control: pt(cx + i * 0.6, cy + i * 0.6))
            p.addQuadCurve(to: pt(cx - r, cy), control: pt(cx - i * 0.6, cy + i * 0.6))
            p.addQuadCurve(to: pt(cx, cy - r), control: pt(cx - i * 0.6, cy - i * 0.6))
            ctx.fill(p, with: .color(color))
        }

        switch type {
        case .fajr:
            line(3.5, 17, 20.5, 17, width: discStroke)
            line(12, 16, 12, 10.6, width: rayStroke)
            line(8.9, 16, 6.9, 11.7, width: rayStroke)
            line(15.1, 16, 17.1, 11.7, width: rayStroke)
        case .sunrise:
            line(3.5, 17, 20.5, 17, width: discStroke)
            openDome(12, 17, 4.5)
            rays(12, 17, 4.5, gap: 0.8, len: 1.7, angles: rays5)
        case .zuhr:
            ring(12, 11.6, 4)
            rays(12, 11.6, 4, gap: 0.9, len: 1.9, angles: rays8)
        case .asr:
            ring(7.8, 7.8, 3.0)
            rays(7.8, 7.8, 3.0, gap: 0.85, len: 1.4, angles: rays8)
            cloud(9.8, 20.5, 0.74)
        case .sunset:
            line(3.5, 17, 20.5, 17, width: discStroke)
            openDome(12, 17, 2.8)
            rays(12, 17, 2.8, gap: 0.8, len: 1.3, angles: rays5)
            cloud(11.3, 11.2, 0.72)
        case .maghrib:
            crescent(12, 8, 1)
        case .isha:
            crescent(13, 6.5, 0.78)
            cloud(3.6, 21, 0.52)
        case .midnight:
            star(13, 10, 4.4)
            star(7, 16, 2.6)
            star(18, 17, 2)
        case .unknown:
            // Never actually shown — every known prayer/time name resolves
            // above — but keeps the same grammar rather than an unrelated
            // borrowed symbol: horizon, dome, pinnacle.
            line(4, 19, 20, 19, width: discStroke)
            openDome(12, 19, 4)
            line(12, 15, 12, 11.5, width: rayStroke)
        }
    }
}
