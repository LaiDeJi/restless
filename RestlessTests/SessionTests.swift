import Foundation
import Testing
@testable import Restless

private let start = Date(timeIntervalSince1970: 1_000_000)
private let benchID = UUID()
private let inclineID = UUID()
private let curlID = UUID()
private let pushdownID = UUID()
private let plankID = UUID()
private let hangID = UUID()

private func block(
    rounds: Int,
    setsPerRound: Int,
    setRest: Int,
    roundRest: Int,
    movements: [BlockMovement],
    name: String = "Block"
) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: rounds,
        setsPerRound: setsPerRound,
        setRest: setRest,
        roundRest: roundRest,
        movements: movements
    )
}

private let superset = WorkoutPreset(
    name: "Superset",
    blocks: [
        block(rounds: 2, setsPerRound: 1, setRest: 30, roundRest: 120, movements: [
            BlockMovement(movementId: curlID, endCondition: .manual),
            BlockMovement(movementId: pushdownID, endCondition: .manual)
        ], name: "Arms")
    ]
)

private let twoBlocks = WorkoutPreset(
    name: "Pair",
    blocks: [
        block(rounds: 1, setsPerRound: 3, setRest: 60, roundRest: 120, movements: [
            BlockMovement(movementId: benchID, endCondition: .manual)
        ], name: "Biceps"),
        block(rounds: 1, setsPerRound: 1, setRest: 45, roundRest: 90, movements: [
            BlockMovement(movementId: curlID, endCondition: .manual)
        ], name: "Triceps")
    ]
)

private let timed = WorkoutPreset(
    name: "Timed",
    blocks: [
        block(rounds: 1, setsPerRound: 2, setRest: 45, roundRest: 60, movements: [
            BlockMovement(movementId: plankID, endCondition: .time, target: 60)
        ], name: "Core")
    ]
)

private let timedFinal = WorkoutPreset(
    name: "Timed final",
    blocks: [
        block(rounds: 1, setsPerRound: 1, setRest: 45, roundRest: 60, movements: [
            BlockMovement(movementId: plankID, endCondition: .time, target: 60)
        ], name: "Core")
    ]
)

private let manual = WorkoutPreset(
    name: "Manual",
    blocks: [
        block(rounds: 1, setsPerRound: 1, setRest: 45, roundRest: 60, movements: [
            BlockMovement(movementId: hangID, endCondition: .manual)
        ], name: "Back")
    ]
)

private let zeroRest = WorkoutPreset(
    name: "No rest",
    blocks: [
        block(rounds: 1, setsPerRound: 3, setRest: 0, roundRest: 120, movements: [
            BlockMovement(movementId: benchID, endCondition: .manual)
        ], name: "Push")
    ]
)

private func ready(_ preset: WorkoutPreset = .seeded) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    return snapshot
}

/// Completes `count` sets, ending their rests, and leaves the session ready.
private func completeSets(_ count: Int, in snapshot: inout SessionSnapshot) {
    for _ in 0..<count {
        snapshot.setDone(now: start)
        snapshot.finishRest()
    }
}

private func runToDone(_ snapshot: inout SessionSnapshot) {
    while snapshot.phase != .done {
        if snapshot.phase == .ready { snapshot.setDone(now: start) }
        if snapshot.phase == .resting { snapshot.finishRest() }
        if snapshot.phase == .performing { snapshot.setDone(now: start) }
    }
}

@Test("A fresh snapshot is not started")
func freshSnapshotIsGate() {
    let snapshot = SessionSnapshot.initial(twoBlocks, now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.kicker == "READY")
    #expect(snapshot.primaryTitle == "START SESSION")
    #expect(snapshot.primaryAction == .startSession)
    #expect(snapshot.subtitle == "2 BLOCKS · 4 SETS · 4:00 TOTAL REST")
}

@Test("START SESSION enters block 1 set 1 without completing a set")
func startSessionTransition() {
    var snapshot = SessionSnapshot.initial(twoBlocks, now: start)
    SessionTransitions.apply(.startSession, to: &snapshot, now: start)

    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.position.blockIndex == 0)
    #expect(snapshot.position.movementIndex == 0)
    #expect(snapshot.position.set == 1)
}

@Test("Set done and a second start are ignored in the gate")
func gateGuards() {
    var snapshot = SessionSnapshot.initial(.seeded, now: start)
    SessionTransitions.apply(.setDone, to: &snapshot, now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)

    SessionTransitions.apply(.startSession, to: &snapshot, now: start)
    SessionTransitions.apply(.startSession, to: &snapshot, now: start)

    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 0)
}

@Test("Set done starts set rest with a deadline")
func setDoneStartsSetRest() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.restKind == .set)
    #expect(snapshot.duration == 60)
    #expect(snapshot.deadline == start.addingTimeInterval(60))
    #expect(snapshot.restTransition == .set)
}

@Test("Tapping set done twice consumes one set")
func setDoneIsIdempotent() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 1)
}

@Test("Pausing freezes the remaining time and resuming moves the deadline")
func pauseAndResume() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)

    snapshot.pause(now: start.addingTimeInterval(10))
    #expect(snapshot.phase == .paused)
    #expect(snapshot.pausedRemaining == 50)
    #expect(snapshot.deadline == nil)

    snapshot.resume(now: start.addingTimeInterval(10_000))
    #expect(snapshot.phase == .resting)
    #expect(snapshot.remaining(at: start.addingTimeInterval(10_000)) == 50)
    #expect(snapshot.deadline == start.addingTimeInterval(10_050))
}

@Test("Skipping a rest keeps the completed set and returns to ready")
func skipRest() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)
    snapshot.skipRest()

    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 1)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.deadline == nil)
}

@Test("A rest that reaches its deadline ends itself")
func restEndsAtDeadline() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)

    let changed = snapshot.reconcile(now: start.addingTimeInterval(60))
    #expect(changed)
    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 1)
}

@Test("A movement switch is a round rest")
func movementTransition() {
    var snapshot = ready(superset)
    completeSets(1, in: &snapshot)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 2)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.restKind == .round)
    #expect(snapshot.duration == 120)
    #expect(snapshot.restTransition == .movement)
    #expect(snapshot.restContext { id in
        id == curlID ? "Curl" : "Pushdown"
    } == "NEXT · PUSHDOWN")
}

@Test("A round rest follows a movement's earlier round")
func firstRoundRest() {
    var snapshot = ready(superset)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.restKind == .round)
    #expect(snapshot.duration == 120)
    #expect(snapshot.restTransition == .round)
    #expect(snapshot.restContext == "AFTER ROUND 1")
}

@Test("A block transition follows the last set of a block")
func blockTransition() {
    var snapshot = ready(twoBlocks)
    completeSets(2, in: &snapshot)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 3)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.restKind == .round)
    #expect(snapshot.duration == 120)
    #expect(snapshot.restTransition == .block)
    #expect(snapshot.isBlockTransition)
    #expect(snapshot.subtitle == "NEXT · TRICEPS")
}

@Test("The final set of the last block ends the session with no rest")
func finalSetEndsSession() {
    var snapshot = ready(.seeded)
    runToDone(&snapshot)

    #expect(snapshot.phase == .done)
    #expect(snapshot.doneSets == snapshot.totalSets)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.deadline == nil)
}

@Test("The next block is ready when the transition rest ends")
func nextBlockAfterTransition() {
    var snapshot = ready(twoBlocks)
    completeSets(2, in: &snapshot)
    snapshot.setDone(now: start)
    snapshot.finishRest()

    #expect(snapshot.phase == .ready)
    #expect(snapshot.position.blockIndex == 1)
    #expect(snapshot.position.blockName == "Triceps")
    #expect(snapshot.position.movementIndex == 0)
    #expect(snapshot.position.set == 1)
    #expect(snapshot.upcomingRest == nil)
}

@Test("A double tap at a block boundary still consumes one set")
func doubleTapAtBlockBoundary() {
    var snapshot = ready(twoBlocks)
    completeSets(2, in: &snapshot)
    snapshot.setDone(now: start)
    snapshot.setDone(now: start)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 3)
}

@Test("Skipping a transition rest lands on the next block's first set")
func skipTransitionRest() {
    var snapshot = ready(twoBlocks)
    completeSets(2, in: &snapshot)
    snapshot.setDone(now: start)
    snapshot.skipRest()

    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 3)
    #expect(snapshot.position.blockIndex == 1)
    #expect(snapshot.position.set == 1)
}

@Test("Pausing and resuming across a block boundary keeps the rest")
func pauseAcrossBlockBoundary() {
    var snapshot = ready(twoBlocks)
    completeSets(2, in: &snapshot)
    snapshot.setDone(now: start)

    snapshot.pause(now: start.addingTimeInterval(30))
    #expect(snapshot.pausedRemaining == 90)
    #expect(snapshot.position.blockIndex == 1)

    snapshot.resume(now: start.addingTimeInterval(600))
    #expect(snapshot.remaining(at: start.addingTimeInterval(600)) == 90)
}

@Test("Restarting from progress returns to the start gate at the first block")
func restart() {
    var snapshot = ready(twoBlocks)
    completeSets(3, in: &snapshot)
    snapshot.restart(now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.position.blockIndex == 0)
    #expect(snapshot.position.blockName == "Biceps")
    #expect(snapshot.preset == twoBlocks)
}

@Test("A completed two-block session summarizes blocks and total rest")
func doneSummary() {
    var snapshot = ready(twoBlocks)
    runToDone(&snapshot)

    #expect(snapshot.phase == .done)
    #expect(snapshot.doneSets == 4)
    #expect(snapshot.kicker == "4 OF 4 SETS")
    #expect(snapshot.subtitle == "2 BLOCKS · 2 MOVEMENTS · 4:00 TOTAL REST")
    #expect(snapshot.primarySubtitle == "4 SETS · 4:00 TOTAL REST")
}

@Test("A one-block session keeps the familiar rest copy")
func oneBlockCopy() {
    var snapshot = ready(.seeded)
    #expect(snapshot.subtitle == "AFTER THIS SET")

    snapshot.setDone(now: start)
    #expect(snapshot.restContext == "AFTER SET 1")
    snapshot.finishRest()

    snapshot.setDone(now: start)
    #expect(snapshot.restContext == "AFTER SET 2")

    runToDone(&snapshot)
    #expect(snapshot.subtitle == "1 BLOCK · 1 MOVEMENT · 8:00 TOTAL REST")
}

@Test("A movement switch falls back to the block when names are unavailable")
func movementSwitchFallback() {
    var snapshot = ready(superset)
    completeSets(1, in: &snapshot)
    snapshot.setDone(now: start)

    #expect(snapshot.restContext == "NEXT · MOVEMENT")
}

@Test("Progress runs from zero to one across a rest")
func progress() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)

    #expect(snapshot.progress(at: start) == 0)
    #expect(snapshot.progress(at: start.addingTimeInterval(30)) == 0.5)
    #expect(snapshot.progress(at: start.addingTimeInterval(60)) == 1)
}

@Test("Replacing the preset resets the session to the gate")
func replacePreset() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)

    snapshot.replacePreset(twoBlocks, now: start)

    #expect(snapshot.preset == twoBlocks)
    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.doneSets == 0)
    #expect(snapshot.position.blockName == "Biceps")
}

@Test("A zero set rest never becomes a rest state")
func zeroSetRestSkipsRest() {
    var snapshot = ready(zeroRest)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .ready)
    #expect(snapshot.restKind == nil)
    #expect(snapshot.duration == 0)
    #expect(snapshot.position.set == 2)
}

@Test("Start set runs a timed set with its own deadline")
func timedSetStarts() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)

    #expect(snapshot.phase == .performing)
    #expect(snapshot.setDuration == 60)
    #expect(snapshot.setDeadline == start.addingTimeInterval(60))
    #expect(snapshot.restKind == nil)
    #expect(snapshot.duration == 0)
}

@Test("SET DONE during a timed set ends it early and starts its rest")
func timedSetEndsEarly() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)
    snapshot.setDone(now: start.addingTimeInterval(10))

    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.restKind == .set)
    #expect(snapshot.duration == 45)
    #expect(snapshot.setDuration == 0)
    #expect(snapshot.setDeadline == nil)
}

@Test("A timed set expires into the same rest")
func timedSetExpires() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)
    let changed = snapshot.reconcile(now: start.addingTimeInterval(60))

    #expect(changed)
    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .resting)
    #expect(snapshot.duration == 45)
}

@Test("The final timed set expires into done with no rest")
func timedFinalSetEndsSession() {
    var snapshot = ready(timedFinal)
    snapshot.startSet(now: start)
    _ = snapshot.reconcile(now: start.addingTimeInterval(60))

    #expect(snapshot.phase == .done)
    #expect(snapshot.doneSets == 1)
    #expect(snapshot.restKind == nil)
}

@Test("A timed set is never paused")
func timedSetCannotPause() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)
    snapshot.pause(now: start.addingTimeInterval(10))

    #expect(snapshot.phase == .performing)
}

@Test("Start set only applies to a ready timed set")
func startSetOnlyForTimed() {
    var manualSnapshot = ready(manual)
    manualSnapshot.startSet(now: start)
    #expect(manualSnapshot.phase == .ready)

    var seededSnapshot = ready(.seeded)
    seededSnapshot.startSet(now: start)
    #expect(seededSnapshot.phase == .ready)
}

@Test("Starting a timed set twice does not restart its deadline")
func startTwice() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)
    snapshot.startSet(now: start.addingTimeInterval(10))

    #expect(snapshot.setDeadline == start.addingTimeInterval(60))
}

@Test("Set done during a rest is ignored")
func setDoneDuringRestIgnored() {
    var snapshot = ready(.seeded)
    snapshot.setDone(now: start)
    snapshot.setDone(now: start)

    #expect(snapshot.doneSets == 1)
    #expect(snapshot.phase == .resting)
}

@Test("Restart clears a running timed set")
func restartClearsTimedSet() {
    var snapshot = ready(timed)
    snapshot.startSet(now: start)
    snapshot.restart(now: start)

    #expect(snapshot.phase == .notStarted)
    #expect(snapshot.setDuration == 0)
    #expect(snapshot.setDeadline == nil)
}

@Test("The editors list MANUAL, TIME in that order")
func endConditionEditorOrder() {
    #expect(EndCondition.editorOrder == [.manual, .time])
    #expect(EndCondition.editorOrder.map(\.label) == ["MANUAL", "TIME"])
}

// MARK: - Block progress

private let evenBlocks = WorkoutPreset(
    name: "Even",
    blocks: [
        block(rounds: 1, setsPerRound: 5, setRest: 60, roundRest: 120, movements: [
            BlockMovement(movementId: benchID, endCondition: .manual)
        ], name: "First"),
        block(rounds: 1, setsPerRound: 5, setRest: 60, roundRest: 120, movements: [
            BlockMovement(movementId: curlID, endCondition: .manual)
        ], name: "Second")
    ]
)

@Test("Block progress starts the first block at zero")
func blockProgressFirstBlock() {
    var snapshot = ready(evenBlocks)
    var progress = snapshot.blockProgress
    #expect(progress.blockIndex == 0)
    #expect(progress.done == 0)
    #expect(progress.total == 5)
    #expect(progress.fraction == 0)

    snapshot.doneSets = 3
    progress = snapshot.blockProgress
    #expect(progress.blockIndex == 0)
    #expect(progress.done == 3)
    #expect(progress.total == 5)
    #expect(progress.fraction == 0.6)
}

@Test("Block progress counts only the current block in a later block")
func blockProgressLaterBlock() {
    var snapshot = ready(evenBlocks)
    snapshot.doneSets = 8

    let progress = snapshot.blockProgress

    #expect(progress.blockIndex == 1)
    #expect(progress.done == 3)
    #expect(progress.total == 5)
}

@Test("A done session fills the last block")
func blockProgressDone() {
    var snapshot = ready(evenBlocks)
    runToDone(&snapshot)

    let progress = snapshot.blockProgress

    #expect(progress.blockIndex == 1)
    #expect(progress.done == progress.total)
    #expect(progress.total == 5)
}

@Test("Block progress clamps past either end")
func blockProgressClamps() {
    var snapshot = ready(evenBlocks)

    snapshot.doneSets = -3
    #expect(snapshot.blockProgress.blockIndex == 0)
    #expect(snapshot.blockProgress.done == 0)

    snapshot.doneSets = evenBlocks.totalSets + 10
    #expect(snapshot.blockProgress.blockIndex == 1)
    #expect(snapshot.blockProgress.done == 5)
    #expect(snapshot.blockProgress.total == 5)
}
