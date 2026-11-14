import Foundation
import Testing
@testable import Restless

private let watchMovementID = UUID()

private func watchPreset(setRest: Int = 90, setsPerRound: Int = 3) -> WorkoutPreset {
    WorkoutPreset(
        name: "Remote",
        blocks: [
            WorkoutBlock(
                name: "Remote",
                rounds: 1,
                setsPerRound: setsPerRound,
                setRest: setRest,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: watchMovementID, endCondition: .manual)
                ]
            )
        ]
    )
}

@Test("An action message round-trips its id, action and tap instant")
func watchActionRoundTrip() throws {
    let message = WatchActionMessage(
        id: UUID(),
        action: .skipRest,
        tapTime: Date(timeIntervalSince1970: 1_000_000)
    )

    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(WatchActionMessage.self, from: data)

    #expect(decoded == message)
}

@Test("An unknown watch action decodes as ignored")
func watchUnknownActionIsIgnored() throws {
    let raw = """
    {"id":"8A3A3D45-58B4-4C0D-9B3F-5E0C8B1C9A10","action":"teleport","tapTime":0}
    """
    let decoded = try JSONDecoder().decode(WatchActionMessage.self, from: Data(raw.utf8))

    #expect(decoded.action == .ignored)
    #expect(decoded.action.sessionAction == nil)
}

@Test("Every watch action maps to the phone's own transition")
func watchActionMapping() {
    let pairs: [(WatchActionKind, SessionAction)] = [
        (.startSession, .startSession),
        (.setDone, .setDone),
        (.startSet, .startSet),
        (.pause, .pause),
        (.resume, .resume),
        (.skipRest, .skipRest),
        (.restart, .restart)
    ]

    for (kind, action) in pairs {
        #expect(kind.sessionAction == action)
        #expect(WatchActionKind(action) == kind)
    }
    #expect(WatchActionKind(.finishRest) == nil)
}

@Test("A published session round-trips the snapshot, active plan and names")
func watchSessionPayloadRoundTrip() throws {
    let preset = watchPreset()
    var snapshot = SessionSnapshot.initial(preset, now: Date(timeIntervalSince1970: 900_000))
    snapshot.doneSets = 2
    snapshot.phase = .resting
    snapshot.restKind = .set
    snapshot.duration = 90
    snapshot.deadline = Date(timeIntervalSince1970: 900_100)
    snapshot.pausedRemaining = 90
    let payload = WatchSessionPayload(
        snapshot: snapshot,
        movementNames: [watchMovementID: "Bench press"]
    )

    let data = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(WatchSessionPayload.self, from: data)

    #expect(decoded == payload)
    #expect(decoded.activePreset == preset)
    #expect(decoded.movementNames[watchMovementID] == "Bench press")
}

@Test("The wire carries one optional action and one optional session")
func watchWireRoundTrip() throws {
    let action = WatchActionMessage(action: .pause, tapTime: Date(timeIntervalSince1970: 500))
    let message = WatchRemoteWire.message(for: action)
    #expect(WatchRemoteWire.action(from: message) == action)

    let payload = WatchSessionPayload(snapshot: .initial(watchPreset()))
    let context = WatchRemoteWire.context(for: payload)
    #expect(WatchRemoteWire.payload(from: context) == payload)

    #expect(WatchRemoteWire.context(for: nil).isEmpty)
    #expect(WatchRemoteWire.payload(from: [:]) == nil)
}

@Test("A plan that cannot start publishes no context")
func watchUnstartablePlanPublishesNothing() {
    let emptyBlock = WorkoutBlock(name: "Empty", movements: [])
    let preset = WorkoutPreset(name: "Empty", blocks: [emptyBlock])
    let snapshot = SessionSnapshot.initial(preset)

    #expect(WatchSessionPayload.published(snapshot: snapshot) == nil)
    #expect(WatchRemoteWire.context(for: WatchSessionPayload.published(snapshot: snapshot)).isEmpty)
}

@MainActor
@Test("SET DONE applied four seconds late keeps the tap instant's deadline")
func delayedSetDoneKeepsTapDeadline() throws {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let engine = SessionEngine(preset: watchPreset(setRest: 90))
    engine.perform(.startSession)

    let tap = Date.now.addingTimeInterval(-4)
    let applied = engine.perform(.setDone, at: tap, id: UUID())

    #expect(applied)
    #expect(engine.snapshot.phase == .resting)
    let deadline = try #require(engine.snapshot.deadline)
    #expect(abs(deadline.timeIntervalSince(tap) - 90) < 0.5)
}

@MainActor
@Test("A late skip reconciles into the ready phase")
func delayedSkipReachesReady() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let engine = SessionEngine(preset: watchPreset(setRest: 90))
    engine.perform(.startSession)

    let restStart = Date.now.addingTimeInterval(-10)
    engine.perform(.setDone, at: restStart, id: UUID())
    #expect(engine.snapshot.phase == .resting)

    engine.perform(.skipRest, at: restStart.addingTimeInterval(5), id: UUID())

    #expect(engine.snapshot.phase == .ready)
    #expect(engine.snapshot.deadline == nil)
}

@MainActor
@Test("A tap time far in the future is clamped to arrival")
func futureTapClampsToArrival() throws {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let engine = SessionEngine(preset: watchPreset(setRest: 90))
    engine.perform(.startSession)

    engine.perform(.setDone, at: Date.now.addingTimeInterval(120), id: UUID())

    let deadline = try #require(engine.snapshot.deadline)
    #expect(abs(deadline.timeIntervalSinceNow - 90) < 2)
}

@MainActor
@Test("An action id that already applied is dropped")
func duplicateActionIDIsDropped() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let engine = SessionEngine(preset: watchPreset(setRest: 0))
    engine.perform(.startSession)

    let id = UUID()
    engine.perform(.setDone, at: .now, id: id)
    #expect(engine.snapshot.doneSets == 1)

    engine.perform(.setDone, at: .now, id: id)
    #expect(engine.snapshot.doneSets == 1)

    engine.perform(.setDone, at: .now, id: UUID())
    #expect(engine.snapshot.doneSets == 2)
}

@Test("A published rest deadline that passed renders the following phase")
func publishedRestDeadlineExpiresForDisplay() {
    let preset = watchPreset(setRest: 45)
    var snapshot = SessionSnapshot.initial(preset, now: .now)
    snapshot.doneSets = 1
    snapshot.phase = .resting
    snapshot.restKind = .set
    snapshot.duration = 45
    snapshot.deadline = Date.now.addingTimeInterval(-1)
    snapshot.pausedRemaining = 45
    let payload = WatchSessionPayload(snapshot: snapshot)

    let shown = payload.displaySnapshot(at: .now)

    #expect(shown.phase == .ready)
    #expect(shown.doneSets == 1)
}

@Test("A published work deadline that passed renders the rest it started")
func publishedWorkDeadlineExpiresForDisplay() {
    let preset = watchPreset(setRest: 90)
    var snapshot = SessionSnapshot.initial(preset, now: .now)
    snapshot.phase = .performing
    snapshot.setDuration = 60
    snapshot.setDeadline = Date.now.addingTimeInterval(-1)
    let payload = WatchSessionPayload(snapshot: snapshot)

    let shown = payload.displaySnapshot(at: .now)

    #expect(shown.phase == .resting)
    #expect(shown.doneSets == 1)
}

@Test("The rest after a displayed work deadline keeps the work's own instant")
func publishedWorkDeadlineSetsExactRestDeadline() throws {
    let preset = watchPreset(setRest: 90)
    let workDeadline = Date.now.addingTimeInterval(-10)
    var snapshot = SessionSnapshot.initial(preset, now: workDeadline)
    snapshot.phase = .performing
    snapshot.setDuration = 60
    snapshot.setDeadline = workDeadline
    let payload = WatchSessionPayload(snapshot: snapshot)

    let shown = payload.displaySnapshot(at: .now)
    let restDeadline = try #require(shown.deadline)

    #expect(shown.phase == .resting)
    #expect(abs(restDeadline.timeIntervalSince(workDeadline) - 90) < 0.5)
}

@Test("A work deadline and its rest that both passed render ready")
func publishedLongAbsenceRendersReady() {
    let preset = watchPreset(setRest: 90)
    var snapshot = SessionSnapshot.initial(preset, now: .now)
    snapshot.phase = .performing
    snapshot.setDuration = 60
    snapshot.setDeadline = Date.now.addingTimeInterval(-300)
    let payload = WatchSessionPayload(snapshot: snapshot)

    let shown = payload.displaySnapshot(at: .now)

    #expect(shown.phase == .ready)
    #expect(shown.doneSets == 1)
}

@Test("The payload names the movement the current position points at")
func payloadResolvesMovementName() {
    let payload = WatchSessionPayload(
        snapshot: .initial(watchPreset()),
        movementNames: [watchMovementID: "Bench press"]
    )

    #expect(payload.movementName == "Bench press")
    #expect(payload.position.set == 1)
}
