import Foundation
import Testing
@testable import Restless

@MainActor
@Test("Several rapid edits produce one commit")
func rapidEditsCoalesce() async throws {
    let store = SessionDraftStore(session: .chest, delay: .milliseconds(60))
    var commits: [WorkoutPreset] = []
    store.commit = { commits.append($0) }

    for _ in 0..<5 {
        store.edit { $0.blocks[0].setRest += 15 }
    }

    #expect(store.session.blocks[0].setRest == 135)
    #expect(commits.isEmpty)

    try await Task.sleep(for: .milliseconds(220))

    #expect(commits.count == 1)
    #expect(commits[0].blocks[0].setRest == 135)
    #expect(!store.isDirty)
}

@MainActor
@Test("flush commits immediately")
func flushCommitsImmediately() {
    let store = SessionDraftStore(session: .chest, delay: .seconds(10))
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.edit { $0.blocks[0].setsPerRound = 4 }
    store.flush()

    #expect(commits == 1)
    #expect(store.session.blocks[0].setsPerRound == 4)
    #expect(!store.isDirty)
}

@MainActor
@Test("A flushed draft does not commit again when its timer would have fired")
func cancelledDraftDoesNotCommit() async throws {
    let store = SessionDraftStore(session: .chest, delay: .milliseconds(60))
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.edit { $0.blocks[0].rounds = 5 }
    store.flush()
    #expect(commits == 1)

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits == 1)
}

@MainActor
@Test("Flushing a clean draft does nothing")
func cleanFlushDoesNothing() {
    let store = SessionDraftStore(session: .chest)
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.flush()
    #expect(commits == 0)
}

private func draftBlock(_ name: String, movementIDs: [UUID]) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: 1,
        setsPerRound: 3,
        setRest: 60,
        roundRest: 120,
        movements: movementIDs.map { BlockMovement(movementId: $0, endCondition: .manual) }
    )
}

@MainActor
@Test("Moving a block reorders down and up")
func moveBlockReorders() {
    let firstBlock = draftBlock("A", movementIDs: [UUID()])
    let secondBlock = draftBlock("B", movementIDs: [UUID()])
    let thirdBlock = draftBlock("C", movementIDs: [UUID()])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "Three", blocks: [firstBlock, secondBlock, thirdBlock])
    )

    #expect(store.moveBlock(firstBlock.id, onto: thirdBlock.id))
    #expect(store.session.blocks.map(\.name) == ["B", "C", "A"])

    #expect(store.moveBlock(firstBlock.id, onto: secondBlock.id))
    #expect(store.session.blocks.map(\.name) == ["A", "B", "C"])
}

@MainActor
@Test("Moving a movement reorders down and up within its block")
func moveMovementReorders() {
    let first = UUID()
    let second = UUID()
    let third = UUID()
    let block = draftBlock("Chest", movementIDs: [first, second, third])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))
    let firstID = block.movements[0].id
    let secondID = block.movements[1].id
    let thirdID = block.movements[2].id

    #expect(store.moveMovement(thirdID, inBlock: block.id, onto: firstID))
    #expect(store.session.blocks[0].movements.map(\.movementId) == [third, first, second])

    #expect(store.moveMovement(thirdID, inBlock: block.id, onto: secondID))
    #expect(store.session.blocks[0].movements.map(\.movementId) == [first, second, third])
}

@MainActor
@Test("A row delete removes the item and dirties the draft")
func rowDeleteRemoves() {
    let firstBlock = draftBlock("Chest", movementIDs: [UUID(), UUID()])
    let secondBlock = draftBlock("Arms", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "Two", blocks: [firstBlock, secondBlock]))

    #expect(store.removeMovement(firstBlock.movements[0].id, inBlock: firstBlock.id))
    #expect(store.session.blocks[0].movements.count == 1)

    #expect(store.removeBlock(firstBlock.id))
    #expect(store.session.blocks.map(\.name) == ["Arms"])
}

@MainActor
@Test("The last block and the last movement cannot be removed")
func lastItemGuard() {
    let onlyMovement = UUID()
    let onlyBlock = draftBlock("Core", movementIDs: [onlyMovement])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [onlyBlock]))

    #expect(!store.removeBlock(onlyBlock.id))
    #expect(!store.removeMovement(onlyMovement, inBlock: onlyBlock.id))
    #expect(!store.isDirty)
    #expect(store.session.blocks.count == 1)
    #expect(store.session.blocks[0].movements.count == 1)
}

@MainActor
@Test("Appending a movement bumps a one-round block to two")
func appendMovementBumpsRounds() {
    let first = Movement(name: "Chest")
    let second = Movement(name: "Cable Fly")
    let block = draftBlock("Chest", movementIDs: [first.id])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(store.appendMovement(second, toBlock: block.id, condition: .time, target: 10))
    #expect(store.session.blocks[0].rounds == 2)
    #expect(store.session.blocks[0].movements.count == 2)
    #expect(store.session.blocks[0].movements[1].movementId == second.id)
    #expect(store.session.blocks[0].movements[1].endCondition == .time)
    #expect(store.session.blocks[0].movements[1].target == 15)
}

@MainActor
@Test("Appending to a multi-movement block keeps its rounds")
func appendMovementKeepsRounds() {
    let first = Movement(name: "Chest")
    let second = Movement(name: "Curl")
    let third = Movement(name: "Pushdown")
    var block = draftBlock("Chest", movementIDs: [first.id, second.id])
    block.rounds = 3
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(store.appendMovement(third, toBlock: block.id, condition: .manual, target: nil))
    #expect(store.session.blocks[0].rounds == 3)
    #expect(store.session.blocks[0].movements.count == 3)
    #expect(store.session.blocks[0].movements[2].target == nil)
}

@MainActor
@Test("Appending to a missing block changes nothing")
func appendMovementMissingBlock() {
    let movement = Movement(name: "Cable Fly")
    let block = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(!store.appendMovement(movement, toBlock: UUID(), condition: .time, target: 45))
    #expect(!store.isDirty)
    #expect(store.session.blocks[0].movements.count == 1)
}

private func addition(
    _ name: String,
    condition: EndCondition = .manual,
    target: Int? = nil
) -> MovementAddition {
    MovementAddition(movement: Movement(name: name), condition: condition, target: target)
}

@MainActor
@Test("A batch append keeps the queued order and commits once")
func appendMovementsBatchOrder() {
    let first = Movement(name: "Cable Fly")
    let second = Movement(name: "Bench Press")
    let block = draftBlock("Chest", movementIDs: [])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [block]),
        delay: .seconds(10)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }

    #expect(store.appendMovements([
        MovementAddition(movement: first, condition: .manual, target: nil),
        MovementAddition(movement: second, condition: .time, target: 45)
    ], toBlock: block.id))
    #expect(store.session.blocks[0].movements.map(\.movementId) == [first.id, second.id])
    #expect(store.session.blocks[0].movements.map(\.endCondition) == [.manual, .time])
    #expect(store.session.blocks[0].movements[1].target == 45)
    #expect(commits == 0)

    store.flush()
    #expect(commits == 1)
}

@MainActor
@Test("A batch that brings an empty block to two movements raises rounds once")
func appendMovementsBumpsEmptyBlock() {
    let block = draftBlock("Chest", movementIDs: [])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(store.appendMovements(
        [addition("Cable Fly"), addition("Bench Press")],
        toBlock: block.id
    ))
    #expect(store.session.blocks[0].movements.count == 2)
    #expect(store.session.blocks[0].rounds == 2)
}

@MainActor
@Test("A batch that brings a one-movement block to two movements raises rounds once")
func appendMovementsBumpsSingleMovementBlock() {
    let block = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(store.appendMovements([addition("Cable Fly")], toBlock: block.id))
    #expect(store.session.blocks[0].movements.count == 2)
    #expect(store.session.blocks[0].rounds == 2)
}

@MainActor
@Test("A batch on a multi-movement block keeps its rounds")
func appendMovementsKeepsMultiMovementRounds() {
    var block = draftBlock("Chest", movementIDs: [UUID(), UUID()])
    block.rounds = 3
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(store.appendMovements([addition("Cable Fly")], toBlock: block.id))
    #expect(store.session.blocks[0].movements.count == 3)
    #expect(store.session.blocks[0].rounds == 3)
}

@MainActor
@Test("An empty batch changes nothing")
func appendEmptyBatch() {
    let block = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(!store.appendMovements([], toBlock: block.id))
    #expect(!store.isDirty)
    #expect(store.session.blocks[0].movements.count == 1)
}

@MainActor
@Test("A batch for a missing block changes nothing")
func appendBatchMissingBlock() {
    let block = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [block]))

    #expect(!store.appendMovements([addition("Cable Fly")], toBlock: UUID()))
    #expect(!store.isDirty)
    #expect(store.session.blocks[0].movements.count == 1)
}

@MainActor
@Test("Appending a block keeps its settings and leaves the others untouched")
func appendBlockKeepsSettings() {
    let first = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "Two", blocks: [first]),
        delay: .seconds(10)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }
    let movement = Movement(name: "Cable Fly")
    let block = WorkoutBlock(
        name: "Fly",
        rounds: 1,
        setsPerRound: 4,
        setRest: 45,
        roundRest: 90,
        movements: [BlockMovement(movementId: movement.id, endCondition: .time, target: 60)]
    )

    #expect(store.appendBlock(block))
    #expect(store.session.blocks.count == 2)
    #expect(store.session.blocks[1].name == "Fly")
    #expect(store.session.blocks[1].setsPerRound == 4)
    #expect(store.session.blocks[1].setRest == 45)
    #expect(store.session.blocks[1].roundRest == 90)
    #expect(store.session.blocks[1].movements[0].endCondition == .time)
    #expect(store.session.blocks[1].movements[0].target == 60)
    #expect(store.session.blocks[0] == first)
    #expect(commits == 0)

    store.flush()
    #expect(commits == 1)
}

@MainActor
@Test("A two-movement block appended with one round rises to two")
func appendBlockBumpsRounds() {
    let first = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [first]))
    let block = draftBlock("Arms", movementIDs: [UUID(), UUID()])

    #expect(store.appendBlock(block))
    #expect(store.session.blocks[1].rounds == 2)
    #expect(store.session.blocks[1].movements.count == 2)
}

@MainActor
@Test("A block with no movements cannot be appended")
func appendEmptyBlock() {
    let first = draftBlock("Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [first]))
    let empty = draftBlock("Empty", movementIDs: [])

    #expect(!store.appendBlock(empty))
    #expect(!store.isDirty)
    #expect(store.session.blocks.count == 1)
}

// MARK: - Staged block

private func restedBlock(name: String, movementID: UUID = UUID()) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: 4,
        setsPerRound: 4,
        setRest: 45,
        roundRest: 90,
        movements: [BlockMovement(movementId: movementID, endCondition: .manual)]
    )
}

@MainActor
@Test("A staged block starts from the documented defaults and inherits the previous rests")
func stagedBlockDefaults() throws {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [previous]))
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.beginStagedBlock(after: previous)
    let staged = try #require(store.stagedBlock)

    #expect(staged.name == "Untitled block")
    #expect(staged.rounds == 1)
    #expect(staged.setsPerRound == 3)
    #expect(staged.setRest == 45)
    #expect(staged.roundRest == 90)
    #expect(staged.movements.isEmpty)
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)
    #expect(commits == 0)

    store.beginStagedBlock(after: previous)
    #expect(store.stagedBlock == staged)
}

@MainActor
@Test("Staged edits and appends never dirty the draft or commit a save")
func stagedEditsStayOutOfTheSession() async throws {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [previous]),
        delay: .milliseconds(60)
    )
    var persists = 0
    store.commit = { _ in persists += 1 }

    store.beginStagedBlock(after: previous)
    store.editBlock(.staged) { block in
        block.name = "Arms"
        block.rounds = 4
        block.setsPerRound = 2
        block.setRest = 30
    }

    let first = Movement(name: "Curl")
    let second = Movement(name: "Pushdown")
    #expect(store.appendMovements([
        MovementAddition(movement: first, condition: .manual, target: nil),
        MovementAddition(movement: second, condition: .time, target: 45)
    ], to: .staged))

    let staged = try #require(store.stagedBlock)
    #expect(staged.name == "Arms")
    #expect(staged.setRest == 30)
    #expect(staged.movements.map(\.movementId) == [first.id, second.id])
    #expect(staged.movements[1].target == 45)
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)

    try await Task.sleep(for: .milliseconds(180))
    #expect(persists == 0)
}

@MainActor
@Test("DONE appends a staged block with its edited values and flushes once")
func commitStagedBlock() throws {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [previous]),
        delay: .seconds(10)
    )
    var persists = 0
    store.commit = { _ in persists += 1 }

    store.beginStagedBlock(after: previous)
    store.editBlock(.staged) { block in
        block.name = "Arms"
        block.rounds = 4
        block.setsPerRound = 2
        block.setRest = 30
        block.roundRest = 60
    }
    #expect(store.appendMovements(
        [MovementAddition(movement: Movement(name: "Curl"), condition: .time, target: 60)],
        to: .staged
    ))

    #expect(store.commitStagedBlock())
    #expect(store.stagedBlock == nil)
    #expect(store.session.blocks.count == 2)

    let committed = try #require(store.session.blocks.last)
    #expect(committed.name == "Arms")
    #expect(committed.rounds == 4)
    #expect(committed.setsPerRound == 2)
    #expect(committed.setRest == 30)
    #expect(committed.roundRest == 60)
    #expect(committed.movements.count == 1)
    #expect(committed.movements[0].endCondition == .time)
    #expect(committed.movements[0].target == 60)
    #expect(store.isDirty)

    store.flush()
    #expect(persists == 1)
}

@MainActor
@Test("A staged block with no movements cannot be committed")
func stagedBlockNeedsAMovement() {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [previous]))
    store.beginStagedBlock(after: previous)

    #expect(!store.commitStagedBlock())
    #expect(store.stagedBlock != nil)
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)
}

@MainActor
@Test("Discarding a staged block leaves the session clean")
func discardStagedBlock() {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [previous]))
    store.beginStagedBlock(after: previous)
    store.editBlock(.staged) { $0.name = "Arms" }
    #expect(store.appendMovements([addition("Curl")], to: .staged))

    store.discardStagedBlock()
    #expect(store.stagedBlock == nil)
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)
}

@MainActor
@Test("A staged movement edit and removal leave the session unchanged")
func stagedMovementEditsStayOutOfTheSession() throws {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [previous]))
    store.beginStagedBlock(after: previous)
    #expect(store.appendMovements([addition("Curl"), addition("Pushdown")], to: .staged))
    let firstID = try #require(store.stagedBlock?.movements.first?.id)
    let secondID = try #require(store.stagedBlock?.movements.last?.id)

    store.editBlock(.staged) { block in
        block.movements[0].endCondition = .time
        block.movements[0].target = 45
    }
    #expect(store.stagedBlock?.movements[0].endCondition == .time)
    #expect(store.stagedBlock?.movements[0].target == 45)
    #expect(store.moveMovement(firstID, in: .staged, onto: secondID))
    #expect(store.stagedBlock?.movements.last?.id == firstID)
    #expect(store.stagedBlock?.movements.count == 2)
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)

    #expect(store.removeMovement(firstID, in: .staged))
    #expect(store.stagedBlock?.movements.count == 1)
    #expect(store.session.blocks == [previous])
}

@MainActor
@Test("A staged block that gains a second movement commits at two rounds")
func stagedBlockRisesToTwoRounds() {
    let previous = restedBlock(name: "Chest")
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [previous]))
    store.beginStagedBlock(after: previous)
    #expect(store.appendMovements([addition("Curl"), addition("Pushdown")], to: .staged))
    #expect(store.stagedBlock?.rounds == 2)

    #expect(store.commitStagedBlock())
    #expect(store.session.blocks.last?.rounds == 2)
    #expect(store.session.blocks.last?.movements.count == 2)
}
