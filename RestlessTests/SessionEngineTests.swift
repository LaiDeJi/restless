import Foundation
import Testing
@testable import Restless

private let timedID = UUID()
private let timed = WorkoutPreset(
    name: "Timed",
    blocks: [
        WorkoutBlock(
            name: "Core",
            rounds: 1,
            setsPerRound: 2,
            setRest: 45,
            roundRest: 60,
            movements: [
                BlockMovement(movementId: timedID, endCondition: .time, target: 60)
            ]
        )
    ]
)

@MainActor
@Test("A timed set that expired while the app was away lands in its rest")
func timedSetExpiredWhileAway() {
    SessionStore.clear()
    var snapshot = SessionSnapshot.initial(timed, now: .now)
    snapshot.phase = .performing
    snapshot.setDuration = 60
    snapshot.setDeadline = .now.addingTimeInterval(-1)
    SessionStore.save(snapshot)

    let engine = SessionEngine(preset: timed)

    #expect(engine.snapshot.doneSets == 1)
    #expect(engine.snapshot.phase == .resting)
    #expect(engine.snapshot.restKind == .set)
    #expect(engine.snapshot.duration == 45)
    SessionStore.clear()
}

@MainActor
@Test("Pause does not touch a performing timed set")
func pauseDoesNotTouchTimedSet() {
    SessionStore.clear()
    let engine = SessionEngine(preset: timed)

    engine.perform(.startSession)
    engine.perform(.startSet)
    #expect(engine.snapshot.phase == .performing)
    #expect(engine.snapshot.setDeadline != nil)

    engine.perform(.pause)
    #expect(engine.snapshot.phase == .performing)
    #expect(engine.snapshot.setDeadline != nil)
    SessionStore.clear()
}

@MainActor
@Test("Activation and restart open the start gate")
func activationGate() {
    SessionStore.clear()
    let engine = SessionEngine(preset: timed)
    #expect(engine.snapshot.phase == .notStarted)

    engine.perform(.startSession)
    #expect(engine.snapshot.phase == .ready)

    engine.use(timed)
    #expect(engine.snapshot.phase == .notStarted)
    #expect(engine.snapshot.doneSets == 0)
    SessionStore.clear()
}

@MainActor
@Test("A v5 snapshot round-trips through the store")
func snapshotRoundTrip() {
    SessionStore.clear()
    var snapshot = SessionSnapshot.initial(timed, now: .now)
    snapshot.doneSets = 1
    snapshot.phase = .resting
    snapshot.restKind = .set
    snapshot.duration = 45
    snapshot.deadline = .now.addingTimeInterval(45)
    snapshot.pausedRemaining = 45
    snapshot.setDuration = 0
    snapshot.setDeadline = nil

    SessionStore.save(snapshot)
    #expect(SessionStore.load() == snapshot)
    SessionStore.clear()
}

@MainActor
@Test("A v3 snapshot is discarded and the app starts at the gate")
func v3SnapshotIsDiscardedAndGateOpens() {
    let defaults = UserDefaults(suiteName: SessionStore.appGroup) ?? .standard
    SessionStore.clear()
    defaults.set(Data([1, 2, 3]), forKey: "restless.session.v3")

    let engine = SessionEngine(preset: timed)

    #expect(engine.snapshot.phase == .notStarted)
    #expect(engine.snapshot.doneSets == 0)
    #expect(defaults.object(forKey: "restless.session.v3") == nil)
    SessionStore.clear()
}

@Test("The v1, v2, v3, and v4 snapshot keys are discarded")
func legacySnapshotsAreDiscarded() {
    let defaults = UserDefaults(suiteName: SessionStore.appGroup) ?? .standard
    defaults.set(Data([1, 2, 3]), forKey: "restless.session.v4")
    defaults.set(Data([1, 2, 3]), forKey: "restless.session.v3")
    defaults.set(Data([1, 2, 3]), forKey: "restless.session.v2")
    defaults.set(Data([4, 5, 6]), forKey: "restless.session.v1")

    #expect(SessionStore.load() == nil)
    #expect(defaults.object(forKey: "restless.session.v4") == nil)
    #expect(defaults.object(forKey: "restless.session.v3") == nil)
    #expect(defaults.object(forKey: "restless.session.v2") == nil)
    #expect(defaults.object(forKey: "restless.session.v1") == nil)
}

@MainActor
@Test("A v4 run is cleared so the movement-major order opens at the gate")
func v4SnapshotOpensTheGate() throws {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let defaults = UserDefaults(suiteName: SessionStore.appGroup) ?? .standard

    // A v4 body that would decode: the count now points at a different set.
    var snapshot = SessionSnapshot.initial(timed, now: .now)
    snapshot.doneSets = 1
    snapshot.phase = .resting
    snapshot.restKind = .set
    snapshot.duration = 45
    snapshot.deadline = .now.addingTimeInterval(30)
    let encoded = try JSONEncoder().encode(snapshot)
    defaults.set(encoded, forKey: "restless.session.v4")

    #expect(SessionStore.load() == nil)
    #expect(defaults.object(forKey: "restless.session.v4") == nil)
}

@MainActor
@Test("A completed run bumps the completion event once")
func completionEventBumpsOnce() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let oneSet = WorkoutPreset(
        name: "One",
        blocks: [
            WorkoutBlock(
                name: "One",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
    let engine = SessionEngine(preset: oneSet)
    #expect(engine.completionEvent == 0)

    engine.perform(.startSession)
    engine.perform(.setDone)
    #expect(engine.snapshot.phase == .done)
    #expect(engine.completionEvent == 1)
}

@MainActor
@Test("A relaunch of a done snapshot does not bump the completion event")
func completionEventSurvivesRelaunch() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let oneSet = WorkoutPreset(
        name: "One",
        blocks: [
            WorkoutBlock(
                name: "One",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
    let engine = SessionEngine(preset: oneSet)
    engine.perform(.startSession)
    engine.perform(.setDone)
    #expect(engine.completionEvent == 1)

    let relaunched = SessionEngine(preset: oneSet)
    #expect(relaunched.snapshot.phase == .done)
    #expect(relaunched.completionEvent == 0)
}

@MainActor
@Test("A restart after done does not bump the completion event")
func completionEventIgnoresRestart() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let oneSet = WorkoutPreset(
        name: "One",
        blocks: [
            WorkoutBlock(
                name: "One",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
    let engine = SessionEngine(preset: oneSet)
    engine.perform(.startSession)
    engine.perform(.setDone)
    #expect(engine.completionEvent == 1)

    engine.perform(.restart)
    #expect(engine.snapshot.phase == .ready)
    #expect(engine.completionEvent == 1)
}

@MainActor
@Test("A store refresh into done bumps the completion event")
func completionEventFromStoreRefresh() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let oneSet = WorkoutPreset(
        name: "One",
        blocks: [
            WorkoutBlock(
                name: "One",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
    let engine = SessionEngine(preset: oneSet)
    engine.perform(.startSession)

    var done = engine.snapshot
    done.doneSets = done.totalSets
    done.phase = .done
    SessionStore.save(done)
    engine.refreshFromStore()

    #expect(engine.snapshot.phase == .done)
    #expect(engine.completionEvent == 1)
}

@MainActor
@Test("A saved running snapshot with a REPS row loads at the same position")
func storedRepsSnapshotLoads() throws {
    SessionStore.clear()
    defer { SessionStore.clear() }

    let preset = WorkoutPreset(
        name: "Full",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 1,
                setsPerRound: 2,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            ),
            WorkoutBlock(
                name: "Arms",
                rounds: 1,
                setsPerRound: 2,
                setRest: 30,
                roundRest: 90,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(preset, now: .now)
    snapshot.doneSets = 3
    snapshot.phase = .resting
    snapshot.restKind = .set
    snapshot.duration = 30
    snapshot.deadline = .now.addingTimeInterval(20)

    // Write the previous build's shape: the first movement carried REPS 10.
    let encoded = try JSONEncoder().encode(snapshot)
    var raw = try #require(String(bytes: encoded, encoding: .utf8))
    if let range = raw.range(of: "\"endCondition\":\"manual\"") {
        raw.replaceSubrange(range, with: "\"endCondition\":\"reps\",\"target\":10")
    }
    let defaults = UserDefaults(suiteName: SessionStore.appGroup) ?? .standard
    defaults.set(Data(raw.utf8), forKey: "restless.session.v5")

    let loaded = try #require(SessionStore.load())
    #expect(loaded.preset.id == preset.id)
    #expect(loaded.preset.blocks.count == 2)
    #expect(loaded.preset.blocks[0].movements[0].endCondition == .manual)
    #expect(loaded.preset.blocks[0].movements[0].target == nil)
    #expect(loaded.doneSets == 3)
    #expect(loaded.phase == .resting)

    let engine = SessionEngine(preset: preset)
    #expect(engine.snapshot.doneSets == 3)
    #expect(engine.snapshot.position.blockIndex == 1)
    #expect(engine.snapshot.position.set == 2)
}
