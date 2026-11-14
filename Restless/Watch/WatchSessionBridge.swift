import Foundation
import OSLog
import UIKit
import WatchConnectivity

/// The phone's half of the wrist remote. It receives one action per wrist tap
/// and publishes the session the engine already persists; it makes no
/// transition of its own.
@MainActor
final class WatchSessionBridge: NSObject {
    private let engine: SessionEngine
    private let logger = Logger(subsystem: "com.whc.restless", category: "watch")
    private var session: WCSession?

    init(engine: SessionEngine) {
        self.engine = engine
        super.init()
        #if DEBUG
        debugLog("bridge created")
        #endif

        engine.sessionDidChange = { [weak self] in self?.publish() }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    /// Replaces the application context. A second change overwrites the first
    /// rather than queueing: the wrist only ever needs the latest session.
    func publish() {
        guard let session, session.activationState == .activated else { return }
        let context = currentContext()
        do {
            try session.updateApplicationContext(context)
            #if DEBUG
            debugLog("published phase=\(engine.snapshot.phase.rawValue) installed=\(session.isWatchAppInstalled)")
            #endif
        } catch {
            logger.error("Watch context publish failed: \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            debugLog("publish failed: \(error.localizedDescription)")
            #endif
            sendDirect(context, on: session)
        }
    }

    /// The context update is refused when the system's watch-app install state
    /// is stale. A reachable watch still accepts the same payload as a message.
    private func sendDirect(_ context: [String: Any], on session: WCSession) {
        guard !context.isEmpty, session.isReachable else { return }
        let logger = self.logger
        session.sendMessage(context, replyHandler: nil) { @Sendable error in
            logger.error("Watch message publish failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func currentContext() -> [String: Any] {
        WatchRemoteWire.context(
            for: WatchSessionPayload.published(
                snapshot: engine.snapshot,
                movementNames: engine.movementNames
            )
        )
    }

    private func handle(_ message: WatchActionMessage) {
        guard let action = message.action.sessionAction else { return }
        logger.info("Watch action \(message.action.rawValue, privacy: .public) id \(message.id.uuidString, privacy: .public)")
        #if DEBUG
        debugLog("received action=\(message.action.rawValue) id=\(message.id.uuidString) tap=\(message.tapTime.timeIntervalSince1970)")
        #endif

        // A wrist tap can wake the app in the background. Tell the alert centre
        // before the transition, so a rest it starts arms its notification.
        engine.setActive(UIApplication.shared.applicationState == .active)

        if engine.perform(action, at: message.tapTime, id: message.id) {
            publish()
        }
    }

    #if DEBUG
    /// A file the physical verification can copy out; OSLog is not reachable
    /// from the Mac for a cable-attached phone.
    private func debugLog(_ message: String) {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = directory.appendingPathComponent("watch-bridge.log")
        let line = "\(ISO8601DateFormatter().string(from: .now)) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
    #endif
}

/// Carries the reply closure across the main-actor hop. The block comes from
/// WatchConnectivity with no concurrency annotation, like the notification
/// delegate's completion handler.
private final class WatchReply: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void

    init(_ handler: @escaping ([String: Any]) -> Void) {
        self.handler = handler
    }

    func call(_ payload: [String: Any]) {
        handler(payload)
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.logger.error("Watch session activation failed: \(error.localizedDescription, privacy: .public)")
            }
            #if DEBUG
            self.debugLog("activated state=\(activationState.rawValue) error=\(error?.localizedDescription ?? "none")")
            #endif
            self.publish()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = WatchRemoteWire.action(from: message) else { return }
        Task { @MainActor in
            self.handle(action)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let action = WatchRemoteWire.action(from: message) else {
            replyHandler([:])
            return
        }
        let reply = WatchReply(replyHandler)
        Task { @MainActor in
            self.handle(action)
            reply.call(self.currentContext())
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.publish()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        let paired = session.isPaired
        Task { @MainActor in
            #if DEBUG
            self.debugLog("watch state changed installed=\(installed) paired=\(paired)")
            #endif
            self.publish()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
