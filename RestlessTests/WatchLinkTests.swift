import Foundation
import Testing
@testable import Restless

@MainActor
private final class FakeTransport: WatchTransport {
    var isReachable = true
    var onReachabilityChange: ((Bool) -> Void)?
    private(set) var sent: [WatchMessage] = []

    func send(_ message: WatchMessage) {
        sent.append(message)
    }
}

@MainActor
@Test("Arming sends the token, profile and target")
func armingSendsTokenProfileAndTarget() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    let profile = MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9)

    link.arm(movementID: UUID(), profile: profile, target: 10)

    guard case .arm(let token, _, let sentProfile, let target) = transport.sent.first else {
        Issue.record("expected arm")
        return
    }
    #expect(token == link.armed?.token)
    #expect(sentProfile == profile)
    #expect(target == 10)
}

@MainActor
@Test("Progress from a stale token is ignored")
func staleProgressIsIgnored() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)
    guard let token = link.armed?.token else { return }

    link.handleProgress(token: UUID(), reps: 7)
    #expect(link.reps == 0)

    link.handleProgress(token: token, reps: 7)
    #expect(link.reps == 7)
}

@MainActor
@Test("A duplicate completion consumes one set")
func duplicateCompletionConsumesOneSet() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    var completions = 0
    link.onComplete = { completions += 1 }
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)
    guard let token = link.armed?.token else { return }

    link.handleCompletion(token: token)
    link.handleCompletion(token: token)

    #expect(completions == 1)
}

@MainActor
@Test("A completion from an older set is ignored")
func olderCompletionIsIgnored() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    var completions = 0
    link.onComplete = { completions += 1 }
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)
    guard let oldToken = link.armed?.token else { return }
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)

    link.handleCompletion(token: oldToken)

    #expect(completions == 0)
}

@MainActor
@Test("Disconnecting marks the link unreachable without losing the arm")
func disconnectKeepsArm() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)
    let token = link.armed?.token

    transport.isReachable = false
    transport.onReachabilityChange?(false)

    #expect(link.reachable == false)
    #expect(link.armed?.token == token)
}

@MainActor
@Test("Disarming clears the arm and sends a disarm")
func disarmClearsArm() {
    let transport = FakeTransport()
    let link = WatchLink(transport: transport)
    link.arm(movementID: UUID(), profile: MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 0.9), target: 10)

    link.disarm()

    #expect(link.armed == nil)
    #expect(transport.sent.last == .disarm)
}
