import Foundation
import Observation
import WatchConnectivity

/// The wrist's whole state. It holds the last session the phone published and
/// sends one message per tap; it never applies a transition of its own.
@MainActor
@Observable
final class WatchRemoteModel: NSObject {
    private(set) var payload: WatchSessionPayload?
    private(set) var sendFailed = false

    private var displayNow = Date.now
    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private var displayRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var sendTimeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        #if DEBUG
        if let seeded = WatchPreviewFixtures.payload(arguments: ProcessInfo.processInfo.arguments) {
            payload = seeded
            displayNow = .now
            if ProcessInfo.processInfo.arguments.contains("-watch-send-failed") {
                sendFailed = true
            }
            return
        }
        #endif
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
        readContext()
    }

    /// The published phase with an expired deadline resolved for display only.
    var snapshot: SessionSnapshot? {
        payload?.displaySnapshot(at: displayNow)
    }

    /// A wrist raise or a return from the notification. Re-reads the context so
    /// a delivery that arrived while the app was suspended is not missed.
    func refreshDisplay() {
        readContext()
    }

    /// The wrist is down. No display-only wake is needed while nothing is on
    /// screen; the next raise re-reads the context.
    func pauseDisplayRefresh() {
        displayRefreshTask?.cancel()
        displayRefreshTask = nil
    }

    func send(_ action: SessionAction) {
        sendTimeoutTask?.cancel()
        sendTimeoutTask = nil
        guard let session, let kind = WatchActionKind(action) else {
            sendFailed = true
            return
        }

        let wire = WatchRemoteWire.message(for: WatchActionMessage(action: kind))
        guard !wire.isEmpty else {
            sendFailed = true
            return
        }

        // The phone replies after it applies the action. A force-quit phone
        // never replies, so the timeout is what turns the screen to NOT SENT.
        sendTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.sendFailed = true
        }

        let callbacks = WatchSendCallbacks(
            onSuccess: { [weak self] payload in
                if let payload {
                    self?.receive(payload)
                } else {
                    self?.clearSendFailure()
                }
            },
            onFailure: { [weak self] in self?.markSendFailed() }
        )

        session.sendMessage(wire, replyHandler: { @Sendable reply in
            callbacks.succeed(WatchRemoteWire.payload(from: reply))
        }, errorHandler: { @Sendable _ in
            callbacks.fail()
        })
    }

    private func readContext() {
        displayNow = .now
        guard let session else { return }
        payload = WatchRemoteWire.payload(from: session.receivedApplicationContext)
        scheduleDisplayRefresh()
    }

    private func receive(_ payload: WatchSessionPayload) {
        displayNow = .now
        self.payload = payload
        clearSendFailure()
        scheduleDisplayRefresh()
    }

    private func clearSendFailure() {
        sendTimeoutTask?.cancel()
        sendTimeoutTask = nil
        sendFailed = false
    }

    private func markSendFailed() {
        sendTimeoutTask?.cancel()
        sendTimeoutTask = nil
        sendFailed = true
    }

    /// One display-only wake at the published deadline flips the phase. It
    /// shows no remaining time and sends nothing; a suspended app simply
    /// resumes this when the wrist is raised.
    private func scheduleDisplayRefresh() {
        displayRefreshTask?.cancel()
        displayRefreshTask = nil
        guard let deadline = payload?.displaySnapshot(at: displayNow).countdownDeadline else { return }
        let interval = deadline.timeIntervalSince(displayNow)
        guard interval > 0 else { return }

        displayRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, let self else { return }
            self.displayNow = .now
            self.scheduleDisplayRefresh()
        }
    }
}

extension WatchRemoteModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.readContext()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let payload = WatchRemoteWire.payload(from: applicationContext) else { return }
        Task { @MainActor in
            self.receive(payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let payload = WatchRemoteWire.payload(from: message) else { return }
        Task { @MainActor in
            self.receive(payload)
        }
    }
}

/// The send result hops to the main actor. Wrapping the closures keeps the
/// Objective-C blocks free of the main-actor-isolated model, which watchOS
/// calls on a background queue.
private final class WatchSendCallbacks: @unchecked Sendable {
    private let onSuccess: @MainActor (WatchSessionPayload?) -> Void
    private let onFailure: @MainActor () -> Void

    init(
        onSuccess: @escaping @MainActor (WatchSessionPayload?) -> Void,
        onFailure: @escaping @MainActor () -> Void
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    func succeed(_ payload: WatchSessionPayload?) {
        Task { @MainActor in onSuccess(payload) }
    }

    func fail() {
        Task { @MainActor in onFailure() }
    }
}
