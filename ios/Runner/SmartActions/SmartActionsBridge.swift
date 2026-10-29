import AppIntents
import Flutter
import Foundation

/// The native end of `lib/services/smart_actions_service.dart`: where the
/// App Intents in this folder hand work to Dart, which owns playback and
/// navigation, and where Dart hands back the catalog of playlists and duas
/// the intents offer.
///
/// Dart says `ready` once it can take calls. Until then an intent waits: the
/// app may have been launched for that very intent and still be starting.
@objc(SCSmartActions)
public final class SmartActionsBridge: NSObject {
    static let shared = SmartActionsBridge()

    private var channel: FlutterMethodChannel?
    private var isDartReady = false
    private var readyWaiters: [UUID: CheckedContinuation<Bool, Never>] = [:]
    private var pendingCall: (method: String, arguments: [String: Any], at: Date)?

    @objc(configureWithMessenger:)
    public static func configure(messenger: FlutterBinaryMessenger) {
        shared.attach(messenger)
    }

    private func attach(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "shia_companion/smart_actions",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        self.channel = channel
        // A new engine runs a new Dart isolate, which says when it is ready.
        isDartReady = false
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "ready":
            isDartReady = true
            let waiters = readyWaiters
            readyWaiters.removeAll()
            waiters.values.forEach { $0.resume(returning: true) }
            result(nil)
            runPendingCall()
        case "updateCatalog":
            SmartActionsCatalog.save(
                playlists: arguments["playlists"] as? String,
                zikrs: arguments["zikrs"] as? String
            )
            if #available(iOS 17.0, *) {
                // Siri learns the playlist and dua names its phrases accept.
                ShiaCompanionShortcuts.updateAppShortcutParameters()
            }
            if #available(iOS 18.0, *) {
                Task { await SmartActionsSpotlight.indexIfChanged() }
            }
            result(nil)
        case "donatePlaylist":
            if #available(iOS 17.0, *),
               let id = arguments["id"] as? String,
               let playlist = SmartActionsCatalog.playlists().first(where: { $0.id == id }) {
                let intent = PlayPlaylistIntent(playlist: PlaylistEntity(playlist))
                Task { _ = try? await IntentDonationManager.shared.donate(intent: intent) }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Whether Dart is ready, waiting up to `seconds` for it to say so.
    @MainActor
    func waitUntilReady(timeout seconds: Double) async -> Bool {
        if isDartReady { return true }
        let id = UUID()
        return await withCheckedContinuation { continuation in
            readyWaiters[id] = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.readyWaiters.removeValue(forKey: id)?.resume(returning: false)
            }
        }
    }

    /// Has Dart carry out `method` as soon as it says it is ready: what a play
    /// intent leaves behind when the app has to open first. Only the latest
    /// is kept, and only for a minute - a play the reader asked for long ago
    /// should not start by surprise.
    func runWhenReady(_ method: String, _ arguments: [String: Any]) {
        pendingCall = (method, arguments, Date())
    }

    private func runPendingCall() {
        guard let call = pendingCall else { return }
        pendingCall = nil
        guard Date().timeIntervalSince(call.at) < 60 else { return }
        if #available(iOS 17.0, *) {
            Task { @MainActor in try? await self.run(call.method, call.arguments) }
        }
    }

    /// Has Dart carry out `method`, throwing what went wrong - the error is
    /// what Siri says, or the Shortcuts app shows.
    @available(iOS 17.0, *)
    @MainActor
    func run(_ method: String, _ arguments: [String: Any]) async throws {
        guard let channel else { throw SmartActionError.appUnavailable }
        let reply: [String: Any]? = await withCheckedContinuation { continuation in
            channel.invokeMethod(method, arguments: arguments) { reply in
                // A FlutterError or FlutterMethodNotImplemented is no outcome.
                continuation.resume(returning: reply as? [String: Any])
            }
        }
        guard let reply else { throw SmartActionError.appUnavailable }
        if reply["ok"] as? Bool != true {
            throw SmartActionError.failed(reply["message"] as? String)
        }
    }
}

/// Why an intent could not do what it was asked.
@available(iOS 17.0, *)
enum SmartActionError: Error, CustomLocalizedStringResourceConvertible {
    /// Dart reported a failure, in the reader's app language when it could.
    case failed(String?)
    case appUnavailable
    case noPrayerTimes
    case noHijriDate

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failed(let message?):
            return "\(message)"
        case .failed(nil):
            return "Shia Companion couldn't do that."
        case .appUnavailable:
            return "Open Shia Companion, then try again."
        case .noPrayerTimes:
            return "Open Shia Companion to set your location and work out prayer times."
        case .noHijriDate:
            return "Open Shia Companion to bring its calendar up to date."
        }
    }
}
