import Foundation
import Testing
@testable import Restless

private let start = Date(timeIntervalSince1970: 2_000_000)
private let benchID = UUID()
private let curlID = UUID()
private let pushdownID = UUID()
private let plankID = UUID()
private let armID = UUID()

private let benchNames: [UUID: String] = [benchID: "Bench press"]
private let curlNames: [UUID: String] = [
    curlID: "Curl",
    pushdownID: "Pushdown"
]

private func fourByFour() -> WorkoutPreset {
    WorkoutPreset(
        name: "Chest",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 4,
                setsPerRound: 4,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: benchID, endCondition: .manual)]
            )
        ]
    )
}

private func ready(_ preset: WorkoutPreset, doneSets: Int) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    snapshot.doneSets = doneSets
    return snapshot
}

@Test("A set rest names the finished set and the next set and round")
func setRestCopy() {
    let alert = CompletionAlertCopy.restFinished(
        ready(fourByFour(), doneSets: 1),
        movementNames: benchNames
    )
    #expect(alert.title == "SET REST OVER")
    #expect(alert.body == "AFTER SET 1 · NEXT ROUND 1 OF 4 · NEXT SET 2 OF 4")
}

@Test("A round rest names the finished round")
func roundRestCopy() {
    let alert = CompletionAlertCopy.restFinished(
        ready(fourByFour(), doneSets: 4),
        movementNames: benchNames
    )
    #expect(alert.title == "ROUND REST OVER")
    #expect(alert.body == "AFTER ROUND 1 · NEXT ROUND 2 OF 4 · NEXT SET 1 OF 4")
}

@Test("A movement switch names both movements")
func movementSwitchCopy() {
    let preset = WorkoutPreset(
        name: "Arms",
        blocks: [
            WorkoutBlock(
                name: "Arms",
                rounds: 2,
                setsPerRound: 1,
                setRest: 30,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: curlID, endCondition: .manual),
                    BlockMovement(movementId: pushdownID, endCondition: .manual)
                ]
            )
        ]
    )
    let alert = CompletionAlertCopy.restFinished(ready(preset, doneSets: 2), movementNames: curlNames)
    #expect(alert.title == "ROUND REST OVER")
    #expect(alert.body == "AFTER CURL · NEXT PUSHDOWN · NEXT ROUND 1 OF 2")
}

@Test("A block transition names both blocks")
func blockTransitionCopy() {
    let preset = WorkoutPreset(
        name: "Pair",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: benchID, endCondition: .manual)]
            ),
            WorkoutBlock(
                name: "Arms",
                rounds: 1,
                setsPerRound: 1,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: armID, endCondition: .manual)]
            )
        ]
    )
    let names = [benchID: "Bench press", armID: "Curl"]
    let alert = CompletionAlertCopy.restFinished(ready(preset, doneSets: 1), movementNames: names)
    #expect(alert.title == "ROUND REST OVER")
    #expect(alert.body == "AFTER CHEST · NEXT ARMS")
}

@Test("A finished timed set names the rest that follows")
func timedWorkCopy() {
    let preset = WorkoutPreset(
        name: "Core",
        blocks: [
            WorkoutBlock(
                name: "Core",
                rounds: 1,
                setsPerRound: 2,
                setRest: 30,
                roundRest: 60,
                movements: [BlockMovement(movementId: plankID, endCondition: .time, target: 60)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    snapshot.startSet(now: start)
    snapshot.setDone(now: start)

    let alert = CompletionAlertCopy.workFinished(snapshot, movementNames: [plankID: "Plank"])
    #expect(alert.title == "WORK SET OVER")
    #expect(alert.body == "REST 0:30 AFTER")
}

@Test("A timed set with no rest says the next set is immediate")
func timedWorkNoRestCopy() {
    let preset = WorkoutPreset(
        name: "Core",
        blocks: [
            WorkoutBlock(
                name: "Core",
                rounds: 1,
                setsPerRound: 2,
                setRest: 0,
                roundRest: 60,
                movements: [BlockMovement(movementId: plankID, endCondition: .time, target: 60)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    snapshot.startSet(now: start)
    snapshot.setDone(now: start)

    #expect(snapshot.phase == .ready)
    let alert = CompletionAlertCopy.workFinished(snapshot, movementNames: [plankID: "Plank"])
    #expect(alert.body == "NEXT SET IMMEDIATELY")
}

@Test("The final timed set names the completed session and its totals")
func finalTimedSetCopy() {
    let preset = WorkoutPreset(
        name: "Core",
        blocks: [
            WorkoutBlock(
                name: "Core",
                rounds: 1,
                setsPerRound: 1,
                setRest: 30,
                roundRest: 60,
                movements: [BlockMovement(movementId: plankID, endCondition: .time, target: 60)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(preset, now: start)
    snapshot.startSession()
    snapshot.startSet(now: start)
    snapshot.setDone(now: start)

    let alert = CompletionAlertCopy.workFinished(snapshot, movementNames: [plankID: "Plank"])
    #expect(snapshot.phase == .done)
    #expect(alert.title == "SESSION COMPLETE")
    #expect(alert.body == "1 OF 1 SET · 1 BLOCK · 0:00 TOTAL REST")
}

@Test("A forty-character movement name is carried whole")
func longMovementNameCopy() {
    let longID = UUID()
    let name = "Single-arm cable lateral raise for the r"
    let preset = WorkoutPreset(
        name: "Arms",
        blocks: [
            WorkoutBlock(
                name: "Arms",
                rounds: 2,
                setsPerRound: 1,
                setRest: 30,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: longID, endCondition: .manual),
                    BlockMovement(movementId: pushdownID, endCondition: .manual)
                ]
            )
        ]
    )
    let alert = CompletionAlertCopy.restFinished(
        ready(preset, doneSets: 2),
        movementNames: [longID: name, pushdownID: "Pushdown"]
    )
    #expect(alert.body.contains(name.uppercased()))
}

@Test("The pending alert matches the transition that will happen")
func pendingAlertCopy() {
    let preset = fourByFour()
    var resting = SessionSnapshot.initial(preset, now: start)
    resting.startSession()
    resting.setDone(now: start)
    #expect(resting.phase == .resting)

    let alert = CompletionAlertCopy.pending(for: resting, movementNames: benchNames)
    #expect(alert?.title == "SET REST OVER")
    #expect(alert?.body == "AFTER SET 1 · NEXT ROUND 1 OF 4 · NEXT SET 2 OF 4")

    #expect(CompletionAlertCopy.pending(for: ready(preset, doneSets: 1)) == nil)
}
