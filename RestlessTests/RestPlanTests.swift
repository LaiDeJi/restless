import Foundation
import Testing
@testable import Restless

private let benchID = UUID()
private let inclineID = UUID()
private let curlID = UUID()
private let pushdownID = UUID()

private func block(
    rounds: Int,
    setsPerRound: Int,
    setRest: Int,
    roundRest: Int,
    movements: [UUID],
    name: String = "Block"
) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: rounds,
        setsPerRound: setsPerRound,
        setRest: setRest,
        roundRest: roundRest,
        movements: movements.map { BlockMovement(movementId: $0, endCondition: .manual, target: nil) }
    )
}

private let fourByFour = WorkoutPreset(
    name: "Heavy",
    blocks: [
        block(rounds: 4, setsPerRound: 4, setRest: 60, roundRest: 120, movements: [benchID], name: "Bench")
    ]
)

private let superset = WorkoutPreset(
    name: "Arms",
    blocks: [
        block(
            rounds: 2,
            setsPerRound: 1,
            setRest: 30,
            roundRest: 120,
            movements: [curlID, pushdownID],
            name: "Arms"
        )
    ]
)

private let partsExample = WorkoutPreset(
    name: "Arms",
    blocks: [
        block(rounds: 3, setsPerRound: 3, setRest: 60, roundRest: 120, movements: [curlID], name: "Biceps"),
        block(rounds: 2, setsPerRound: 4, setRest: 45, roundRest: 90, movements: [pushdownID], name: "Triceps")
    ]
)

private let oneRound = WorkoutPreset(
    name: "Sets",
    blocks: [block(rounds: 1, setsPerRound: 3, setRest: 60, roundRest: 0, movements: [benchID], name: "Bench")]
)

private let manyRounds = WorkoutPreset(
    name: "Rounds",
    blocks: [block(rounds: 3, setsPerRound: 1, setRest: 60, roundRest: 180, movements: [benchID], name: "Bench")]
)

private let zeroSetRest = WorkoutPreset(
    name: "No set rest",
    blocks: [
        block(
            rounds: 2,
            setsPerRound: 1,
            setRest: 0,
            roundRest: 120,
            movements: [curlID, pushdownID],
            name: "Arms"
        )
    ]
)

private func rest(_ kind: RestKind, _ duration: Int, _ transition: RestTransition) -> RestOption {
    RestOption(kind: kind, duration: duration, transition: transition)
}

@Test("Default preset is one Chest block of rounds 1 and 9 sets per round with 60/120 rest")
func defaultPresetShape() {
    let chest = WorkoutPreset.chest
    #expect(chest.blocks.count == 1)
    #expect(chest.name == "Chest")
    let block = chest.blocks[0]
    #expect(block.name == "Chest")
    #expect(block.rounds == 1)
    #expect(block.setsPerRound == 9)
    #expect(block.setRest == 60)
    #expect(block.roundRest == 120)
    #expect(block.movements.count == 1)
    #expect(block.movements[0].movementId == Movement.chestID)
    #expect(block.movements[0].endCondition == .manual)
    #expect(chest.totalSets == 9)
}

@Test("The 9-set fallback has 8 set rests and no round rest")
func fallbackTotalRest() {
    #expect(WorkoutPreset.chest.totalRest == 480)
    #expect(WorkoutBlock.fallback.rounds == 1)
    #expect(WorkoutBlock.fallback.setsPerRound == 3)
}

@Test("Four rounds of four sets: set rest inside the round, round rest after it", arguments: 0...15)
func fourByFourRestSequence(index: Int) {
    let expected: RestOption? = switch index {
    case 15: nil
    case 3, 7, 11: rest(.round, 120, .round)
    default: rest(.set, 60, .set)
    }
    #expect(fourByFour.rest(after: index) == expected)
}

@Test("Four rounds of four sets totals 16 sets and 1080 seconds")
func fourByFourTotals() {
    #expect(fourByFour.totalSets == 16)
    // 12 set rests × 60 + 3 round rests × 120
    #expect(fourByFour.totalRest == 1080)
}

@Test("A 2 × 2 superset switches movement with set rest and rounds with round rest")
func supersetRestSequence() {
    #expect(superset.totalSets == 4)
    #expect(superset.rest(after: 0) == rest(.set, 30, .movement))
    #expect(superset.rest(after: 1) == rest(.round, 120, .round))
    #expect(superset.rest(after: 2) == rest(.set, 30, .movement))
    #expect(superset.rest(after: 3) == nil)
    #expect(superset.totalRest == 180)
}

@Test("One round of three sets has only set rest")
func oneRoundRestSequence() {
    #expect(oneRound.totalSets == 3)
    #expect(oneRound.rest(after: 0) == rest(.set, 60, .set))
    #expect(oneRound.rest(after: 1) == rest(.set, 60, .set))
    #expect(oneRound.rest(after: 2) == nil)
    #expect(oneRound.totalRest == 120)
}

@Test("Three rounds of one set have only round rest")
func manyRoundsRestSequence() {
    #expect(manyRounds.totalSets == 3)
    #expect(manyRounds.rest(after: 0) == rest(.round, 180, .round))
    #expect(manyRounds.rest(after: 1) == rest(.round, 180, .round))
    #expect(manyRounds.rest(after: 2) == nil)
    #expect(manyRounds.totalRest == 360)
}

@Test("A zero set rest is a zero-duration set rest and never becomes a state")
func zeroSetRestSequence() {
    #expect(zeroSetRest.rest(after: 0) == rest(.set, 0, .movement))
    #expect(zeroSetRest.rest(after: 1) == rest(.round, 120, .round))
    #expect(zeroSetRest.rest(after: 2) == rest(.set, 0, .movement))
    #expect(zeroSetRest.totalRest == 120)
}

@Test("A block followed by another adds its block transition rest")
func blockTransitionRest() {
    #expect(partsExample.rest(after: 8) == rest(.round, 120, .block))
    #expect(partsExample.rest(after: 16) == nil)
    #expect(partsExample.totalSets == 17)
    // Biceps: 9 × 2 × 60 + 2 × 120; Triceps: 8 × 3 × 45 + 1 × 90; block transition 120.
    #expect(partsExample.totalRest == 1080)
}

@Test("A single set has no rest at all")
func singleSet() {
    let preset = WorkoutPreset(
        name: "One",
        blocks: [block(rounds: 1, setsPerRound: 1, setRest: 60, roundRest: 120, movements: [benchID], name: "One")]
    )
    #expect(preset.totalSets == 1)
    #expect(preset.totalRest == 0)
    #expect(preset.rest(after: 0) == nil)
}

@Test("A four-by-four position walks sets inside the round before the next round")
func fourByFourPositions() {
    let first = fourByFour.position(at: 0)
    #expect(first.blockIndex == 0)
    #expect(first.blockName == "Bench")
    #expect(first.movementIndex == 0)
    #expect(first.round == 1)
    #expect(first.set == 1)

    let lastOfRound = fourByFour.position(at: 3)
    #expect(lastOfRound.round == 1)
    #expect(lastOfRound.set == 4)

    let nextRound = fourByFour.position(at: 4)
    #expect(nextRound.round == 2)
    #expect(nextRound.set == 1)
}

@Test("A superset position walks movements inside the round before the next round")
func supersetPositions() {
    let first = superset.position(at: 0)
    #expect(first.movementIndex == 0)
    #expect(first.round == 1)
    #expect(first.set == 1)

    let second = superset.position(at: 1)
    #expect(second.movementIndex == 1)
    #expect(second.round == 1)
    #expect(second.set == 1)

    let nextRound = superset.position(at: 2)
    #expect(nextRound.movementIndex == 0)
    #expect(nextRound.round == 2)
    #expect(nextRound.set == 1)

    let last = superset.position(at: 3)
    #expect(last.movementIndex == 1)
    #expect(last.round == 2)
}

@Test("A second block starts at its first set")
func secondBlockPosition() {
    let position = partsExample.position(at: 9)
    #expect(position.blockIndex == 1)
    #expect(position.blockName == "Triceps")
    #expect(position.movementIndex == 0)
    #expect(position.round == 1)
    #expect(position.set == 1)
}

@Test("The final set of the last block has no rest")
func finalSetHasNoRest() {
    #expect(fourByFour.rest(after: 15) == nil)
    #expect(superset.rest(after: 3) == nil)
    #expect(partsExample.rest(after: 16) == nil)
}

@Test("Positions clamp to the last set")
func clampToLastSet() {
    let position = fourByFour.position(at: 99)
    #expect(position.blockIndex == 0)
    #expect(position.movementIndex == 0)
    #expect(position.round == 4)
    #expect(position.set == 4)
}

@Test("Rounds and sets per round are unbounded and only rests clamp")
func clamping() {
    let wild = WorkoutPreset(
        name: "Wild",
        blocks: [block(rounds: 0, setsPerRound: 0, setRest: 61, roundRest: 7, movements: [benchID], name: "Wild")]
    ).clamped()
    #expect(wild.blocks[0].rounds == 1)
    #expect(wild.blocks[0].setsPerRound == 1)
    #expect(wild.blocks[0].setRest == 60)
    #expect(wild.blocks[0].roundRest == 15)

    let big = WorkoutPreset(
        name: "Big",
        blocks: [block(rounds: 25, setsPerRound: 25, setRest: 60, roundRest: 120, movements: [benchID], name: "Big")]
    ).clamped()
    #expect(big.blocks[0].rounds == 25)
    #expect(big.blocks[0].setsPerRound == 25)
}

@Test("A zero set rest stays zero")
func zeroSetRestClamps() {
    let block = block(rounds: 1, setsPerRound: 3, setRest: 0, roundRest: 120, movements: [benchID], name: "Zero")
    #expect(block.clamped()?.setRest == 0)
}

@Test("A block with no movements is dropped and the session falls back")
func emptyBlockFallsBack() {
    let empty = WorkoutBlock(name: "Empty", rounds: 1, setsPerRound: 3, setRest: 60, roundRest: 120, movements: [])
    #expect(empty.clamped() == nil)

    let preset = WorkoutPreset(name: "Empty", blocks: [empty]).clamped()
    #expect(preset.blocks.count == 1)
    #expect(preset.blocks[0].movements.count == 1)
}

@Test("Movements clamp their name and profile")
func movementClamping() {
    let movement = Movement(
        name: "   ",
        profile: MovementProfile(axis: .x, rise: -2, fall: 400, minPeriod: 0)
    ).clamped()
    #expect(movement.name == "Untitled movement")
    #expect(movement.profile?.rise == 0)
    #expect(movement.profile?.fall == 180)
    #expect(movement.profile?.minPeriod == 0.01)

    let counted = BlockMovement(movementId: benchID, endCondition: .reps, target: 0)
    #expect(counted.clamped().target == 1)

    let manual = BlockMovement(movementId: benchID, endCondition: .manual, target: 10)
    #expect(manual.clamped().target == nil)
}

@Test("Block movements decode with defaults")
func blockMovementCodableDefaults() throws {
    let json = #"{"movementId":"00000000-0000-0000-0000-00000000C4E5"}"#
    let decoded = try JSONDecoder().decode(BlockMovement.self, from: Data(json.utf8))
    #expect(decoded.endCondition == .manual)
    #expect(decoded.target == nil)
}

@Test("A 40-round block of 25 sets totals 1000 sets without overflow")
func largeBlockTotals() {
    let preset = WorkoutPreset(
        name: "Large",
        blocks: [block(rounds: 40, setsPerRound: 25, setRest: 60, roundRest: 120, movements: [benchID], name: "Large")]
    )
    #expect(preset.totalSets == 1000)
    // 40 rounds × 24 set rests × 60 + 39 round rests × 120
    #expect(preset.totalRest == 62_280)
    #expect(preset.position(at: 999).round == 40)
    #expect(preset.position(at: 999).set == 25)
}

@Test("Absurd plans clamp their totals instead of trapping")
func overflowSafeTotals() {
    let preset = WorkoutPreset(
        name: "Absurd",
        blocks: [
            block(
                rounds: 40,
                setsPerRound: Int.max,
                setRest: 60,
                roundRest: 120,
                movements: [benchID, inclineID],
                name: "Absurd"
            )
        ]
    )
    #expect(preset.totalSets == Int.max)
    #expect(preset.totalRest == Int.max)
}

@Test("Round and set copy hides a segment when its count is one")
func roundSetCopyStates() {
    #expect(fourByFour.position(at: 5).roundSetCopy(in: fourByFour.blocks[0]).text == "ROUND 2 OF 4 · SET 2 OF 4")

    #expect(superset.position(at: 1).roundSetCopy(in: superset.blocks[0]).text == "ROUND 1 OF 2")
    #expect(oneRound.position(at: 1).roundSetCopy(in: oneRound.blocks[0]).text == "SET 2 OF 3")

    let single = WorkoutPreset(
        name: "Single",
        blocks: [block(rounds: 1, setsPerRound: 1, setRest: 60, roundRest: 120, movements: [benchID])]
    )
    #expect(single.position(at: 0).roundSetCopy(in: single.blocks[0]).text.isEmpty)
}

@Test("Block copy is numeric and carries both rests")
func blockCopy() {
    let twoMovements = superset.blocks[0]
    #expect(blockNumbers(twoMovements) == "2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS")
    #expect(blockMeta(twoMovements).hasPrefix("2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS · SET 0:30 · ROUND 2:00"))
    #expect(blockSummary(twoMovements) == "2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS · 3:00 REST")
    #expect(blockRoundSetCopy(twoMovements) == "2 ROUNDS · 1 SET EACH")

    let heavy = fourByFour.blocks[0]
    #expect(blockNumbers(heavy) == "1 MOVEMENT · 4 ROUNDS · 4 SETS EACH · 16 SETS")
}

@Test("Duration strings gain hours only once the total reaches one")
func durationStrings() {
    #expect(durationString(0) == "0:00")
    #expect(durationString(600) == "10:00")
    #expect(durationString(1080) == "18:00")
    #expect(durationString(3600) == "1:00:00")
    #expect(durationString(3720) == "1:02:00")
}

@Test("Plural keeps one block from reading as 1 BLOCKS")
func plurals() {
    #expect(plural(1, "BLOCK", "BLOCKS") == "1 BLOCK")
    #expect(plural(2, "BLOCK", "BLOCKS") == "2 BLOCKS")
    #expect(plural(1, "SET", "SETS") == "1 SET")
}
