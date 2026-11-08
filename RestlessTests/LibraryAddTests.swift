import Foundation
import Testing
@testable import Restless

private func block(name: String, movementIDs: [UUID], rounds: Int = 1) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: rounds,
        setsPerRound: 3,
        setRest: 60,
        roundRest: 120,
        movements: movementIDs.map {
            BlockMovement(movementId: $0, endCondition: .reps, target: 10)
        }
    )
}

private func addition(
    _ movement: Movement,
    condition: EndCondition = .manual,
    target: Int? = nil
) -> MovementAddition {
    MovementAddition(movement: movement, condition: condition, target: target)
}

@MainActor
@Test("A library tap appends one MANUAL movement without a target and flushes once")
func singleLibraryAddToSavedBlock() {
    let existing = Movement(name: "Chest")
    let added = Movement(name: "Bench press")
    let saved = block(name: "Chest", movementIDs: [existing.id])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [saved]),
        delay: .seconds(10)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }

    #expect(store.appendMovements([addition(added)], toBlock: saved.id))
    store.flush()

    #expect(store.session.blocks[0].movements.count == 2)
    #expect(store.session.blocks[0].movements[1].movementId == added.id)
    #expect(store.session.blocks[0].movements[1].endCondition == .manual)
    #expect(store.session.blocks[0].movements[1].target == nil)
    #expect(commits == 1)
}

@MainActor
@Test("A library tap leaves a staged block out of the session until DONE")
func singleLibraryAddToStagedBlock() {
    let existing = Movement(name: "Chest")
    let added = Movement(name: "Bench press")
    let saved = block(name: "Chest", movementIDs: [existing.id])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [saved]),
        delay: .seconds(10)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }
    store.beginStagedBlock(after: saved)

    #expect(store.appendMovements([addition(added)], to: .staged))
    store.flush()

    #expect(store.stagedBlock?.movements.count == 1)
    #expect(store.stagedBlock?.movements[0].movementId == added.id)
    #expect(store.stagedBlock?.movements[0].endCondition == .manual)
    #expect(store.stagedBlock?.movements[0].target == nil)
    #expect(store.session.blocks == [saved])
    #expect(!store.isDirty)
    #expect(commits == 0)
}

@MainActor
@Test("A second library movement raises a one-round block to two rounds")
func secondLibraryAddRaisesRounds() {
    let existing = Movement(name: "Chest")
    let added = Movement(name: "Bench press")
    let saved = block(name: "Chest", movementIDs: [existing.id], rounds: 1)
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [saved]))

    #expect(store.appendMovements([addition(added)], toBlock: saved.id))

    #expect(store.session.blocks[0].movements.count == 2)
    #expect(store.session.blocks[0].rounds == 2)
}

@MainActor
@Test("The single append clamps a manual target away and a reps target up")
func libraryAddClampsTargets() {
    let existing = Movement(name: "Chest")
    let manual = Movement(name: "Bench press")
    let reps = Movement(name: "Curl")
    let saved = block(name: "Chest", movementIDs: [existing.id])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [saved]))

    #expect(store.appendMovements([
        addition(manual, condition: .manual, target: 10),
        addition(reps, condition: .reps, target: 0)
    ], toBlock: saved.id))

    #expect(store.session.blocks[0].movements[1].target == nil)
    #expect(store.session.blocks[0].movements[2].target == 1)
}

@MainActor
@Test("An empty single append changes nothing and does not flush")
func emptyLibraryAdd() {
    let existing = Movement(name: "Chest")
    let saved = block(name: "Chest", movementIDs: [existing.id])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [saved]))
    var commits = 0
    store.commit = { _ in commits += 1 }

    #expect(!store.appendMovements([], toBlock: saved.id))
    store.flush()

    #expect(store.session.blocks[0].movements.count == 1)
    #expect(!store.isDirty)
    #expect(commits == 0)
}

@MainActor
@Test("A single append to a missing block or without a staged block is rejected")
func libraryAddInvalidTarget() {
    let added = Movement(name: "Bench press")
    let saved = block(name: "Chest", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "One", blocks: [saved]))

    #expect(!store.appendMovements([addition(added)], toBlock: UUID()))
    #expect(!store.appendMovements([addition(added)], to: .staged))
    #expect(!store.isDirty)
    #expect(store.session.blocks[0].movements.count == 1)
}
