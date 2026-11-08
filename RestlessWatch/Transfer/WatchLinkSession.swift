import Foundation
@preconcurrency import WatchConnectivity

/// The watch end of the two-way link. The phone arms a set or starts a
/// recording; the watch reports progress, completions, and trace files.
@MainActor
final class WatchLinkSession: NSObject {
    static let shared = WatchLinkSession()

    /// Delivered on the main actor, so the model can mutate its state directly.
    var onMessage: (@MainActor (WatchMessage) -> Void)?

    private(set) var isReachable = false
    private var activated = false

    func activate() {
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        let session = WCSession.default
        guard session.delegate == nil else {
            isReachable = session.isReachable
            return
        }
        session.delegate = self
        session.activate()
    }

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(message) else { return }
        let payload: [String: Any] = ["message": data]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                Task { @MainActor in
                    _ = WCSession.default.transferUserInfo(payload)
                }
            }
        } else {
            _ = session.transferUserInfo(payload)
        }
    }

    /// Returns false when the session is not active, so the caller can say the
    /// file stayed on the watch.
    func send(file url: URL, metadata: [String: Any]) -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated else { return false }
        session.transferFile(url, metadata: metadata)
        return true
    }

    private func deliver(_ message: WatchMessage) {
        onMessage?(message)
    }

    private nonisolated static func decode(_ payload: [String: Any]) -> WatchMessage? {
        guard let data = payload["message"] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchMessage.self, from: data)
    }
}

// MARK: - WCSessionDelegate

extension WatchLinkSession: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        let arm = Self.decode(context)
        Task { @MainActor in
            self.isReachable = session.isReachable
            if let arm {
                self.deliver(arm)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let decoded = Self.decode(message) else { return }
        Task { @MainActor in
            self.deliver(decoded)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let decoded = Self.decode(userInfo) else { return }
        Task { @MainActor in
            self.deliver(decoded)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let decoded = Self.decode(applicationContext) else { return }
        Task { @MainActor in
            self.deliver(decoded)
        }
    }
}
