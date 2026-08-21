import Combine
import SwiftUI
import WatchKit
import WidgetKit

// MARK: - Model

/// Tasbeeh count for the watch app.
///
/// Kept local to the watch: the phone's counter lives in Flutter's `SharedPreferences`
/// (not the app group container), so there is nothing to sync it against. Every change
/// is written straight through to `UserDefaults` so the count survives the app being
/// suspended mid-dhikr.
final class CounterModel: ObservableObject {
    /// Guards against a runaway Crown spin producing a nonsensical count.
    static let maxCount = 99_999
    /// `0` means "no target"; the rest mirror the milestones the phone app beeps at.
    static let targetOptions = [0, 33, 34, 100, 1000]

    /// Floor on the gap between two count haptics. The Taptic engine cannot render two
    /// clicks closer than this anyway — it swallows the second — so calling `play` again
    /// only costs main-thread time during exactly the burst we are trying not to drop.
    private static let hapticInterval: TimeInterval = 0.08

    @Published private(set) var count: Int
    @Published private(set) var target: Int

    private enum Keys {
        static let count = "sc_watch_counter_count"
        static let target = "sc_watch_counter_target"
    }

    /// Must match `CounterComplication.kind` in the widget extension.
    private static let complicationKind = "TasbeehCounterComplication"
    /// Long enough that a burst of counting collapses into one reload — WidgetKit
    /// throttles an extension that asks too often, and a dropped reload would leave the
    /// complication stale for far longer than this wait.
    private static let reloadDebounce: TimeInterval = 2
    private var pendingReload: DispatchWorkItem?

    /// Same fallback as `PrayerDataStore`: a missing app group degrades to local storage
    /// rather than losing the count entirely.
    private let defaults: UserDefaults
    /// Serial, so the last value enqueued is the last value written even though the writes
    /// happen off the main thread.
    private let saveQueue = DispatchQueue(label: "com.shiacompanion.watch.counter-save", qos: .utility)
    private var lastHapticAt: TimeInterval = 0

    init() {
        let defaults = UserDefaults(suiteName: watchAppGroupID) ?? .standard
        self.defaults = defaults
        count = min(max(defaults.integer(forKey: Keys.count), 0), Self.maxCount)
        let storedTarget = defaults.integer(forKey: Keys.target)
        target = Self.targetOptions.contains(storedTarget) ? storedTarget : 0
    }

    /// How far into the current lap the count is. Reads full (rather than empty) exactly
    /// on a milestone, then starts over on the next count.
    var progress: Double {
        guard target > 0, count > 0 else { return 0 }
        let remainder = count % target
        return remainder == 0 ? 1 : Double(remainder) / Double(target)
    }

    /// `1` while below the first target, then `2`, `3`… so long sessions stay readable.
    var lap: Int {
        guard target > 0, count > 0 else { return 1 }
        return (count - 1) / target + 1
    }

    var targetLabel: String {
        target == 0 ? "No target" : "\(count % target == 0 && count > 0 ? target : count % target) / \(target)"
    }

    func adjust(by delta: Int) {
        guard delta != 0 else { return }
        let updated = min(max(count + delta, 0), Self.maxCount)
        guard updated != count else { return }

        // Compare laps rather than testing `updated % target`, so a Crown flick that
        // jumps several counts at once still lands the milestone haptic.
        let crossedTarget = target > 0 && updated > count && updated / target > count / target
        // The count lands first and alone. Everything after it is feedback, and a pinch
        // arriving mid-`adjust` has to find the main runloop free or the system drops it.
        setCount(updated)
        persistCount(updated)
        play(crossedTarget ? .success : (delta > 0 ? .click : .directionDown), force: crossedTarget)
        scheduleComplicationReload()
    }

    /// Publishes the new count with animation explicitly switched off.
    ///
    /// Double Tap invokes the button's action from inside the system's own animated
    /// transaction, so without this the number cross-faded to its new value on every
    /// pinch while a screen tap — which carries no such transaction — updated it
    /// instantly. That difference is the whole of "the gesture counts slower than
    /// tapping": the count was landing at the same moment either way, and then spending
    /// a further animation interval catching up on screen.
    private func setCount(_ value: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { count = value }
    }

    func reset() {
        guard count != 0 else { return }
        setCount(0)
        persistCount(0)
        play(.stop, force: true)
        scheduleComplicationReload()
    }

    func cycleTarget() {
        let index = Self.targetOptions.firstIndex(of: target) ?? 0
        target = Self.targetOptions[(index + 1) % Self.targetOptions.count]
        let updated = target
        saveQueue.async { [defaults] in defaults.set(updated, forKey: Keys.target) }
        play(.click, force: true)
        scheduleComplicationReload()
    }

    /// Blocks until every queued write has landed. Called when the app leaves the
    /// foreground, which is the only moment the process might be suspended before the
    /// background queue drains.
    func flushPendingWrites() {
        saveQueue.sync {}
    }

    /// The app group container is shared storage, and writing to it costs more than a
    /// plain `UserDefaults` write. Off the main thread it costs the counter nothing; the
    /// serial queue means a burst of pinches collapses into the same ordered sequence of
    /// writes without any of them blocking a tap.
    private func persistCount(_ value: Int) {
        saveQueue.async { [defaults] in defaults.set(value, forKey: Keys.count) }
    }

    /// Coalesces feedback, never counts: a skipped click means the user felt one buzz for
    /// two very fast pinches, which is what the hardware would have given them regardless.
    /// Milestones bypass the throttle — that buzz is the one being listened for.
    private func play(_ type: WKHapticType, force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastHapticAt >= Self.hapticInterval else { return }
        lastHapticAt = now
        // Hopped to the next runloop pass so the Taptic call — which is not free, and
        // occasionally far from it — happens after SwiftUI has drawn the new number
        // rather than in front of it.
        DispatchQueue.main.async {
            WKInterfaceDevice.current().play(type)
        }
    }

    /// Coalesces the reloads: counting is bursty (a Crown spin is dozens of changes a
    /// second), and only the value the user stops on is worth pushing to the widget.
    private func scheduleComplicationReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingReload = nil
            WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationKind)
        }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reloadDebounce, execute: work)
    }

    /// Called when the app leaves the foreground: a suspended app never runs the pending
    /// work item, so the last change has to be flushed while there is still time.
    func flushComplicationReload() {
        guard let work = pendingReload else { return }
        work.cancel()
        pendingReload = nil
        WidgetCenter.shared.reloadTimelines(ofKind: Self.complicationKind)
    }
}

// MARK: - View

/// Distinguishing *which* control has focus is what lets focus be restored without being
/// trapped: focus moving to another control here is the user navigating, focus going
/// `nil` is the system losing it.
private enum CounterField: Hashable {
    case target, dial, minus, reset
}

/// A single control — the dial — owns every way of counting, so each input route lands
/// on the same button: one screen tap, a hand pinch, and the Digital Crown.
///
/// Concentrating them is what gives the pinch anywhere to land. watchOS has no API for
/// a single pinch: the one first-class hook, `handGestureShortcut`, is wired by the
/// system to Double Tap. A *single* pinch reaches an app only through AssistiveTouch,
/// which activates whichever control holds focus — so the dial takes focus on appear,
/// making it both the Crown's rotation target and the thing a pinch mapped to "Tap"
/// will hit.
///
/// That makes focus load-bearing: anything that clears it silently turns every later
/// pinch into a no-op. The parent screen republishes prayer times on foregrounding, on
/// every phone sync and on an hourly rollover timer, and each of those rebuilds the
/// navigation stack underneath this view — so focus is tracked per-control and re-claimed
/// whenever it goes nowhere at all, rather than only being set once on appear.
///
/// This outer view exists only to pull the model out of the environment. `@EnvironmentObject`
/// invalidates whatever declares it on *any* published change, so declaring it on the
/// screen itself would rebuild the whole screen — the focus modifiers and the Crown's
/// rotation binding included — on every single count. Handing the model down as a plain
/// reference keeps that machinery still, and the three small subviews below re-render
/// instead.
struct CounterView: View {
    @EnvironmentObject private var model: CounterModel

    var body: some View {
        CounterScreen(model: model)
            // Nothing here changes but the object identity, so the screen only rebuilds
            // when it is genuinely a different counter.
            .equatable()
    }
}

private struct CounterScreen: View, Equatable {
    static func == (lhs: CounterScreen, rhs: CounterScreen) -> Bool {
        lhs.model === rhs.model
    }

    /// Deliberately *not* `@ObservedObject`: this view reads no published value, and
    /// observing one would undo the split described above.
    let model: CounterModel

    @Environment(\.scenePhase) private var scenePhase

    /// Raw Crown position. Only the *delta* is used, so the Crown keeps counting from
    /// wherever it happens to be after a reset.
    @State private var crownValue: Double = 0
    @State private var lastCrownStep = 0
    @State private var isConfirmingReset = false
    @State private var isOnScreen = false
    @FocusState private var focus: CounterField?

    var body: some View {
        VStack(spacing: 6) {
            targetButton
            dial
            CounterControls(
                model: model,
                focus: $focus,
                onReset: { isConfirmingReset = true }
            )
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .navigationTitle("Tasbeeh")
        .confirmationDialog(
            "Reset the count?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { model.reset() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            isOnScreen = true
            focus = .dial
        }
        .onDisappear {
            isOnScreen = false
            model.flushPendingWrites()
        }
        .onChange(of: focus) { field in
            // Only `nil` is a loss. Landing on minus, reset or the target button is the
            // user walking the focus ring, and stealing focus back would leave an
            // AssistiveTouch user unable to press anything but the dial.
            guard field == nil else { return }
            claimDialFocus()
        }
        .onChange(of: isConfirmingReset) { presenting in
            // The dialog takes focus with it on the way out, and it takes its dismissal
            // animation to hand it back, so the re-claim has to outlast the transition.
            guard !presenting else { return }
            claimDialFocus(after: 0.35)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                claimDialFocus(after: 0.25)
            } else {
                model.flushPendingWrites()
            }
        }
    }

    /// Re-asserts focus a runloop pass later, because a claim made inside the same update
    /// that cleared it is simply overwritten again. Re-checks on arrival so a user who
    /// moved focus in the meantime keeps it.
    private func claimDialFocus(after delay: TimeInterval = 0.05) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isOnScreen, !isConfirmingReset, focus == nil else { return }
            focus = .dial
        }
    }

    private var targetButton: some View {
        Button {
            model.cycleTarget()
        } label: {
            TargetLabel(model: model)
        }
        .buttonStyle(.plain)
        .focused($focus, equals: .target)
        .accessibilityLabel("Target")
        .accessibilityHint("Changes the target count")
    }

    private var dial: some View {
        Button {
            model.adjust(by: 1)
        } label: {
            DialFace(model: model, isFocused: focus == .dial)
        }
        .buttonStyle(.plain)
        .focused($focus, equals: .dial)
        .digitalCrownRotation(
            $crownValue,
            from: -Double(CounterModel.maxCount),
            through: Double(CounterModel.maxCount),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            // We play our own click per count; the built-in detent haptic would double it.
            isHapticFeedbackEnabled: false
        )
        .onChange(of: crownValue) { value in
            let step = Int(value.rounded())
            guard step != lastCrownStep else { return }
            let delta = step - lastCrownStep
            lastCrownStep = step
            model.adjust(by: delta)
        }
        .modifier(PrimaryHandGestureShortcut())
        .accessibilityLabel("Add one")
    }
}

/// The target button's contents. Split out so ticking the lap over redraws a label
/// rather than the screen.
private struct TargetLabel: View {
    @ObservedObject var model: CounterModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "target")
                .font(.system(size: 9))
            Text(model.targetLabel)
                .font(.system(size: 11))
            // Kept in the tree at zero opacity rather than branched in and out: the lap
            // ticks over mid-session, and adding a view to a focusable control's label
            // makes the focus engine re-evaluate and can drop the dial's focus.
            Text("×\(model.lap)")
                .font(.system(size: 11, weight: .semibold))
                .opacity(model.target > 0 && model.lap > 1 ? 1 : 0)
        }
        .foregroundColor(.secondary)
        .accessibilityValue(model.targetLabel)
    }
}

/// The dial's contents, and the only thing in the screen that a count has to redraw.
private struct DialFace: View {
    @ObservedObject var model: CounterModel
    let isFocused: Bool

    var body: some View {
        ZStack {
            // Doubles as the focus indicator: `.plain` draws no focus ring of its own, and
            // a lost focus is otherwise invisible right up until a pinch does nothing.
            Circle()
                .fill(Color.accentColor.opacity(isFocused ? 0.22 : 0.08))

            // Always present, trimmed to nothing when there is no target, so switching
            // targets does not restructure the focused button's label.
            Circle()
                .trim(from: 0, to: model.target > 0 ? model.progress : 0)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(2)
                .animation(.easeOut(duration: 0.15), value: model.progress)

            VStack(spacing: 0) {
                Text("\(model.count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text("Tap · Pinch · Crown")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .accessibilityValue("Count \(model.count)")
    }
}

/// Minus and reset. They only observe the model to dim themselves at zero, which is
/// reason enough to keep them out of the screen's own update.
private struct CounterControls: View {
    @ObservedObject var model: CounterModel
    @FocusState.Binding var focus: CounterField?
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.adjust(by: -1)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(model.count == 0)
            .focused($focus, equals: .minus)
            .accessibilityLabel("Subtract one")

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(model.count == 0)
            .focused($focus, equals: .reset)
            .accessibilityLabel("Reset")
        }
        .buttonStyle(.bordered)
        .font(.system(size: 13))
    }
}

/// Routes the Double Tap hand gesture to the dial. The modifier is watchOS 11+, and the
/// app deploys back to watchOS 9.
private struct PrimaryHandGestureShortcut: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(watchOS 11.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CounterView_Previews: PreviewProvider {
    static var previews: some View {
        CounterView()
            .environmentObject(CounterModel())
    }
}
#endif
