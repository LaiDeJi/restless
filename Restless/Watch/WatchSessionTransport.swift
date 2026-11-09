import Foundation
@preconcurrency import WatchConnectivity

/// The live phone end of the watch link. It owns the one `WCSession` on iOS:
/// arms travel as an application context so they survive a suspended watch app,
/// progress is best effort, and a completion is queued if the watch app is gone.
@MainActor
final class WatchSessionTransport: NSObject, WatchTransport {
    static let shared = WatchSessionTransport()

    private(set) var isReachable = false
    var onReachabilityChange: ((Bool) -> Void)?

    private var observers: [UUID: @MainActor (WatchMessage) -> Void] = [:]
    private var activated = false

    func activate() {
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        let session = WCSession.default
        guard session.delegate == nil else {
            updateReachability(session)
            return
        }
        session.delegate = self
        session.activate()
    }

    func observe(_ handler: @escaping @MainActor (WatchMessage) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    func send(_ message: WatchMessage) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(message) else { return }
        let payload: [String: Any] = ["message": data]

        switch message {
        case .arm, .disarm:
            // The context survives the watch app being suspended or relaunched.
            try? session.updateApplicationContext(payload)
        case .startRecording:
            // Queued: the watch may be asleep now and start when it wakes.
            _ = session.transferUserInfo(payload)
        case .progress, .alert, .cancelRecording:
            // Only useful while the watch app is in front; drop it otherwise.
            guard session.isReachable else { return }
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        case .completion:
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { _ in
                    Task { @MainActor in
                        _ = WCSession.default.transferUserInfo(payload)
                    }
                }
            } else {
                _ = session.transferUserInfo(payload)
            }
        case .recordingFailed, .recordingTrace:
            break
        }
    }

    // MARK: Delivery

    private func deliver(_ message: WatchMessage) {
        for observer in observers.values {
            observer(message)
        }
    }

    private func updateReachability(_ session: WCSession) {
        let value = session.isReachable
        guard value != isReachable else { return }
        isReachable = value
        onReachabilityChange?(value)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionTransport: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.updateReachability(session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateReachability(session)
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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let kind = file.metadata?["kind"] as? String
        if kind == "movement-trace",
           let data = try? Data(contentsOf: file.fileURL),
           let payload = try? JSONDecoder().decode(RecordingTracePayload.self, from: data) {
            Task { @MainActor in
                self.deliver(.recordingTrace(requestID: payload.requestID, samples: payload.samples))
            }
            return
        }

        // The curl lab's CSV still lands in Documents for Files.
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }
        let destination = documents.appendingPathComponent(file.fileURL.lastPathComponent)
        try? fileManager.removeItem(at: destination)
        try? fileManager.copyItem(at: file.fileURL, to: destination)
    }

    private nonisolated static func decode(_ payload: [String: Any]) -> WatchMessage? {
        guard let data = payload["message"] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchMessage.self, from: data)
    }
}
