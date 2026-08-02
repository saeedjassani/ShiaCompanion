import Combine
import SwiftUI
import WatchKit

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

    @Published private(set) var count: Int
    @Published private(set) var target: Int

    private enum Keys {
        static let count = "sc_watch_counter_count"
        static let target = "sc_watch_counter_target"
    }

    /// Same fallback as `PrayerDataStore`: a missing app group degrades to local storage
    /// rather than losing the count entirely.
    private var defaults: UserDefaults { UserDefaults(suiteName: watchAppGroupID) ?? .standard }

    init() {
        let defaults = UserDefaults(suiteName: watchAppGroupID) ?? .standard
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
        count = updated
        defaults.set(updated, forKey: Keys.count)
        WKInterfaceDevice.current().play(crossedTarget ? .success : (delta > 0 ? .click : .directionDown))
    }

    func reset() {
        guard count != 0 else { return }
        count = 0
        defaults.set(0, forKey: Keys.count)
        WKInterfaceDevice.current().play(.stop)
    }

    func cycleTarget() {
        let index = Self.targetOptions.firstIndex(of: target) ?? 0
        target = Self.targetOptions[(index + 1) % Self.targetOptions.count]
        defaults.set(target, forKey: Keys.target)
        WKInterfaceDevice.current().play(.click)
    }
}

// MARK: - View

/// Counting is available four ways so a dhikr can be kept without looking at the watch:
/// tapping the dial, swiping up/down on it, turning the Digital Crown, and the
/// double-tap hand gesture on hardware that supports it.
struct CounterView: View {
    @EnvironmentObject private var model: CounterModel

    /// Raw Crown position. Only the *delta* is used, so the Crown keeps counting from
    /// wherever it happens to be after a reset.
    @State private var crownValue: Double = 0
    @State private var lastCrownStep = 0
    @State private var isConfirmingReset = false

    /// Movement under this is a tap, not a swipe.
    private static let swipeThreshold: CGFloat = 16

    var body: some View {
        VStack(spacing: 6) {
            targetButton
            dial
            controls
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .focusable()
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
        .navigationTitle("Tasbeeh")
        .confirmationDialog(
            "Reset the count?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { model.reset() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var targetButton: some View {
        Button {
            model.cycleTarget()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(.system(size: 9))
                Text(model.targetLabel)
                    .font(.system(size: 11))
                if model.target > 0 && model.lap > 1 {
                    Text("×\(model.lap)")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Target")
        .accessibilityValue(model.targetLabel)
        .accessibilityHint("Changes the target count")
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            if model.target > 0 {
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .animation(.easeOut(duration: 0.15), value: model.count)
            }

            VStack(spacing: 0) {
                Text("\(model.count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text("Tap · Swipe · Crown")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .gesture(dialGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Count")
        .accessibilityValue("\(model.count)")
        .accessibilityAdjustableAction { direction in
            model.adjust(by: direction == .increment ? 1 : -1)
        }
    }

    /// One gesture handles both taps and swipes: a `DragGesture` with no minimum
    /// distance always wins over a separate `TapGesture`, so the two are told apart by
    /// how far the finger travelled instead of by gesture composition.
    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) < Self.swipeThreshold && abs(dy) < Self.swipeThreshold {
                    model.adjust(by: 1)
                } else if abs(dy) > abs(dx) {
                    // Swipe up counts on, swipe down takes one back.
                    model.adjust(by: dy < 0 ? 1 : -1)
                }
            }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button {
                model.adjust(by: -1)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(model.count == 0)
            .accessibilityLabel("Subtract one")

            Button {
                isConfirmingReset = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(model.count == 0)
            .accessibilityLabel("Reset")

            addButton
        }
        .buttonStyle(.bordered)
        .font(.system(size: 13))
    }

    /// The screen's primary action, which is what the Double Tap hand gesture (pinching
    /// thumb and index finger) invokes on Series 9 / Ultra 2 and later. Styled prominent
    /// so the system's Double Tap highlight lands on an obvious control — watchOS gives
    /// no way to query whether the hardware supports the gesture, so the affordance has
    /// to read correctly on watches that don't.
    private var addButton: some View {
        Button {
            model.adjust(by: 1)
        } label: {
            Image(systemName: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Add one")
        .modifier(PrimaryHandGestureShortcut())
    }
}

/// Routes the Double Tap hand gesture to the add button. The modifier is watchOS 11+,
/// and the app deploys back to watchOS 9.
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
