import Foundation
import Testing
@testable import Restless

private let benchID = UUID()
private let curlID = UUID()

private func block(
    name: String,
    rounds: Int = 1,
    setsPerRound: Int = 3,
    movementID: UUID = benchID
) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: rounds,
        setsPerRound: setsPerRound,
        setRest: 60,
        roundRest: 120,
        movements: [BlockMovement(movementId: movementID, endCondition: .manual)]
    )
}

private func snapshot(
    _ blocks: [WorkoutBlock],
    doneSets: Int = 0,
    phase: SessionPhase = .ready
) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(
        WorkoutPreset(name: "Session", blocks: blocks),
        now: Date(timeIntervalSince1970: 3_000_000)
    )
    snapshot.phase = phase
    snapshot.doneSets = doneSets
    return snapshot
}

private func groups(_ groups: [TimerPositionCopy.Group]) -> [String] {
    groups.map { $0.segments.map(\.text).joined(separator: " ") }
}

private func allText(_ copy: TimerPositionCopy) -> String {
    (groups(copy.leading) + groups(copy.trailing)).joined(separator: " · ")
}

@Test("A multi-block plan names the block only in the block strip")
func multiBlockOmitsTheBlockName() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([
            block(name: "Biceps", setsPerRound: 3),
            block(name: "Triceps", movementID: curlID)
        ]),
        movementName: "Bench press"
    )

    #expect(groups(copy.leading) == ["BENCH PRESS"])
    #expect(allText(copy).contains("BICEPS") == false)
    #expect(allText(copy).contains("BLOCK") == false)
}

@Test("A resting strip starts with UP NEXT and still omits the block")
func restingPrefixesUpNext() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([
            block(name: "Biceps", setsPerRound: 3),
            block(name: "Triceps", movementID: curlID)
        ], doneSets: 1, phase: .resting),
        movementName: "Bench press"
    )

    #expect(groups(copy.leading) == ["UP NEXT", "BENCH PRESS"])
    #expect(allText(copy).contains("BICEPS") == false)
}

@Test("A single block names itself when its name differs from the movement")
func singleBlockNamesItself() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([block(name: "Push", setsPerRound: 3)]),
        movementName: "Bench press"
    )

    #expect(groups(copy.leading) == ["PUSH", "BENCH PRESS"])
}

@Test("A block named like its movement is not repeated")
func singleBlockSameNameAppearsOnce() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([block(name: " Bench Press ", setsPerRound: 3)]),
        movementName: "Bench press"
    )

    #expect(groups(copy.leading) == ["BENCH PRESS"])
    #expect(allText(copy).components(separatedBy: "BENCH PRESS").count - 1 == 1)
}

@Test("A block with several rounds shows only the round group")
func roundOnly() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([block(name: "Push", rounds: 2, setsPerRound: 1)], doneSets: 1),
        movementName: "Bench press"
    )

    #expect(groups(copy.trailing) == ["ROUND 2 OF 2"])
}

@Test("A block with several sets per round shows only the set group")
func setOnly() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([block(name: "Push", rounds: 1, setsPerRound: 3)], doneSets: 2),
        movementName: "Bench press"
    )

    #expect(groups(copy.trailing) == ["SET 3 OF 3"])
}

@Test("A one-round one-set block has no position segments")
func oneByOne() {
    let copy = TimerPositionCopy(
        snapshot: snapshot([block(name: "Push", rounds: 1, setsPerRound: 1)]),
        movementName: "Bench press"
    )

    #expect(groups(copy.trailing).isEmpty)
    #expect(groups(copy.leading) == ["PUSH", "BENCH PRESS"])
}

@Test("A later movement names the movement and both segments")
func multiMovementPosition() {
    var multi = block(name: "Arms", rounds: 2, setsPerRound: 2)
    multi.movements.append(BlockMovement(movementId: curlID, endCondition: .manual))
    let copy = TimerPositionCopy(
        snapshot: snapshot([multi], doneSets: 4),
        movementName: "Curl"
    )

    #expect(groups(copy.leading) == ["ARMS", "CURL"])
    #expect(groups(copy.trailing) == ["ROUND 1 OF 2", "SET 1 OF 2"])
}
