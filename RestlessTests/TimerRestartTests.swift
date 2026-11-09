import Foundation
import Testing
@testable import Restless

private let start = Date(timeIntervalSince1970: 2_000_000)
private let benchID = UUID()
private let plankID = UUID()

private func block(
    rounds: Int,
    setsPerRound: Int,
    movements: [BlockMovement],
    name: String
) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: rounds,
        setsPerRound: setsPerRound,
        setRest: 30,
        roundRest: 60,
        movements: movements
    )
}

private let pair = WorkoutPreset(
    name: "Pair",
    blocks: [
        block(
            rounds: 1,
            setsPerRound: 2,
            movements: [BlockMovement(movementId: benchID, endCondition: .manual)],
            name: "Chest"
        ),
        block(
            rounds: 1,
            setsPerRound: 1,
            movements: [BlockMovement(movementId: benchID, endCondition: .manual)],
            name: "Back"
        )
    ]
)

private let timed = WorkoutPreset(
    name: "Timed",
    blocks: [
        block(
            rounds: 1,
            setsPerRound: 2,
            movements: [BlockMovement(movementId: plankID, endCondition: .time, target: 60)],
            name: "Core"
        )
    ]
)

private func ready(_ preset: WorkoutPreset) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    return snapshot
}

private func runToDone(_ snapshot: inout SessionSnapshot) {
    while snapshot.phase != .done {
        if snapshot.phase == .ready { snapshot.setDone(now: start) }
        if snapshot.phase == .resting { snapshot.finishRest() }
        if snapshot.phase == .performing { snapshot.setDone(now: start) }
    }
}

@Test("Restart is hidden at the gate and before the first set")
func restartHiddenEarly() {
    let gate = SessionSnapshot.initial(pair, now: start)
    #expect(!gate.canRestart)

    let firstSet = ready(pair)
    #expect(!firstSet.canRestart)
}

@Test("Restart appears in ready, performing, resting, and paused after a set")
func restartAppearsAfterASet() {
    var resting = ready(pair)
    resting.setDone(now: start)
    #expect(resting.canRestart)

    var paused = resting
    paused.pause(now: start)
    #expect(paused.canRestart)

    var readyAgain = resting
    readyAgain.finishRest()
    #expect(readyAgain.phase == .ready)
    #expect(readyAgain.doneSets == 1)
    #expect(readyAgain.canRestart)

    var performing = ready(timed)
    performing.setDone(now: start)
    performing.finishRest()
    performing.startSet(now: start)
    #expect(performing.phase == .performing)
    #expect(performing.doneSets == 1)
    #expect(performing.canRestart)
}

@Test("A timed first set does not offer restart yet")
func restartHiddenDuringFirstTimedSet() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)

    #expect(snapshot.phase == .performing)
    #expect(snapshot.doneSets == 0)
    #expect(!snapshot.canRestart)
}

@Test("Restart is hidden in done, where START AGAIN is the primary action")
func restartHiddenWhenDone() {
    var snapshot = ready(pair)
    runToDone(&snapshot)

    #expect(snapshot.phase == .done)
    #expect(!snapshot.canRestart)
    #expect(snapshot.primaryAction == .restart)
}

@Test("START AGAIN from done starts directly at block 1")
func startAgainStartsDirectly() {
    var snapshot = ready(pair)
    runToDone(&snapshot)
    #expect(snapshot.phase == .done)

    SessionTransitions.apply(.restart, to: &snapshot, now: start)

    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 0)
    #expect(!snapshot.canRestart)
}

@Test("The restart transition lands at the start gate at block 1 set 1 with zero sets")
func restartLandsOnTheFirstSet() {
    var snapshot = ready(pair)
    snapshot.setDone(now: start)
    snapshot.setDone(now: start)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.canRestart)

    SessionTransitions.apply(.restart, to: &snapshot, now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.position.blockIndex == 0)
    #expect(snapshot.position.round == 1)
    #expect(snapshot.position.set == 1)
    #expect(!snapshot.canRestart)
}

@Test("Restart from a paused rest clears the rest and the timed set")
func restartClearsAPausedRest() {
    var snapshot = ready(pair)
    snapshot.setDone(now: start)
    snapshot.pause(now: start)
    #expect(snapshot.phase == .paused)

    snapshot.restart(now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.deadline == nil)
    #expect(snapshot.pausedRemaining == 0)
}
