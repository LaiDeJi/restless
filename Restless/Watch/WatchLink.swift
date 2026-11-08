import Foundation
import Observation

/// What the phone sends the watch, and what it listens for. The live
/// implementation uses WatchConnectivity; tests use a fake.
@MainActor
protocol WatchTransport: AnyObject {
    var isReachable: Bool { get }
    var onReachabilityChange: ((Bool) -> Void)? { get set }
    func send(_ message: WatchMessage)
    func observe(_ handler: @escaping @MainActor (WatchMessage) -> Void) -> UUID
    func removeObserver(_ id: UUID)
}

extension WatchTransport {
    func observe(_ handler: @escaping @MainActor (WatchMessage) -> Void) -> UUID { UUID() }
    func removeObserver(_ id: UUID) {}
}

/// A transport that is never reachable, used until the WatchConnectivity link
/// is wired and as the app's safe default.
@MainActor
final class UnavailableWatchTransport: WatchTransport {
    var isReachable = false
    var onReachabilityChange: ((Bool) -> Void)?
    func send(_ message: WatchMessage) {}
}

/// The phone side of the tokenized watch link. It arms a ready reps set, keeps
/// the last progress, and consumes exactly one completion per token.
@MainActor
@Observable
final class WatchLink {
    struct Arm: Hashable, Sendable {
        let token: UUID
        let movementID: UUID
        let profile: MovementProfile
        let target: Int
    }

    private(set) var armed: Arm?
    private(set) var reps = 0
    private(set) var reachable: Bool

    /// Called once per accepted completion, so the app can apply the same
    /// `setDone` transition as the button and the island link.
    var onComplete: (@MainActor () -> Void)?

    private let transport: any WatchTransport
    private var completedToken: UUID?

    init(transport: any WatchTransport) {
        self.transport = transport
        self.reachable = transport.isReachable
        transport.onReachabilityChange = { [weak self] value in
            self?.reachable = value
        }
        _ = transport.observe { [weak self] message in
            guard let self else { return }
            switch message {
            case .progress(let token, let reps):
                self.handleProgress(token: token, reps: reps)
            case .completion(let token):
                self.handleCompletion(token: token)
            default:
                break
            }
        }
    }

    func arm(movementID: UUID, profile: MovementProfile, target: Int) {
        let token = UUID()
        let target = max(target, 1)
        let arm = Arm(token: token, movementID: movementID, profile: profile, target: target)
        armed = arm
        reps = 0
        completedToken = nil
        transport.send(.arm(token: token, movementID: movementID, profile: profile, target: target))
    }

    func disarm() {
        guard armed != nil else { return }
        armed = nil
        reps = 0
        completedToken = nil
        transport.send(.disarm)
    }

    func handleProgress(token: UUID, reps: Int) {
        guard let armed, armed.token == token else { return }
        self.reps = min(max(reps, 0), armed.target)
    }

    func handleCompletion(token: UUID) {
        guard let armed, armed.token == token, completedToken != token else { return }
        completedToken = token
        self.armed = nil
        reps = 0
        onComplete?()
    }
}
