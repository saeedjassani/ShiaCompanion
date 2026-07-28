import Combine
import Foundation
import WatchConnectivity
import WidgetKit

extension Notification.Name {
    static let prayerDataDidChange = Notification.Name("prayerDataDidChange")
}

/// Receives prayer snapshots pushed from the iPhone.
///
/// App group containers are *not* shared between iOS and watchOS, so this is the only
/// way prayer data reaches the watch. The phone sends the same payload three ways so the
/// watch stays current whether or not it is reachable at the time:
///   * `updateApplicationContext` — latest-only, delivered in the background.
///   * `transferCurrentComplicationUserInfo` — wakes the complication.
///   * a reply to `requestSnapshot` — an immediate pull when the watch app opens.
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    /// `true` while a snapshot request to the phone is in flight.
    @Published private(set) var isRequesting = false
    /// Set when the last pull failed, so the UI can explain what went wrong.
    @Published private(set) var lastError: String?

    private override init() {
        super.init()
    }

    nonisolated func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            applyPendingContext(from: session)
            requestSnapshot()
        }
    }

    /// Ask the phone for the current snapshot. Reaching out also wakes the iPhone app in
    /// the background, so this works even when the user hasn't opened it recently.
    nonisolated func requestSnapshot() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }

        setRequesting(true, error: nil)
        session.sendMessage(
            ["request": "snapshot"],
            replyHandler: { [weak self] reply in
                self?.ingest(payload: reply)
                self?.setRequesting(false, error: nil)
            },
            errorHandler: { [weak self] error in
                self?.setRequesting(false, error: error.localizedDescription)
            }
        )
    }

    /// `receivedApplicationContext` survives relaunches, so replay it on every activation.
    private nonisolated func applyPendingContext(from session: WCSession) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        ingest(payload: context)
    }

    private nonisolated func ingest(payload: [String: Any]) {
        guard !payload.isEmpty else { return }
        PrayerDataStore.shared.apply(payload: payload)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .prayerDataDidChange, object: nil)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private nonisolated func setRequesting(_ requesting: Bool, error: String?) {
        Task { @MainActor [weak self] in
            self?.isRequesting = requesting
            self?.lastError = error
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            setRequesting(false, error: error.localizedDescription)
            return
        }
        guard activationState == .activated else { return }
        applyPendingContext(from: session)
        requestSnapshot()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        ingest(payload: applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        ingest(payload: userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        ingest(payload: message)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            requestSnapshot()
        }
    }
}
