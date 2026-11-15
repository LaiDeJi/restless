import Foundation
import Testing
@testable import Restless

// MARK: - Drag reorder

private func reorderBlock(_ name: String, movementIDs: [UUID]) -> WorkoutBlock {
    WorkoutBlock(
        name: name,
        rounds: 1,
        setsPerRound: 3,
        setRest: 60,
        roundRest: 120,
        movements: movementIDs.map { BlockMovement(movementId: $0, endCondition: .manual) }
    )
}

private func reorderAddition(_ name: String) -> MovementAddition {
    MovementAddition(movement: Movement(name: name), condition: .manual, target: nil)
}

@MainActor
@Test("A block reorder waits for endDrag and commits once")
func reorderBlocksCommitsOnce() async throws {
    let first = reorderBlock("A", movementIDs: [UUID()])
    let second = reorderBlock("B", movementIDs: [UUID()])
    let third = reorderBlock("C", movementIDs: [UUID()])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "Three", blocks: [first, second, third]),
        delay: .milliseconds(60)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.beginDrag()
    #expect(store.reorderBlocks(to: [third.id, first.id, second.id]))
    #expect(store.session.blocks.map(\.name) == ["C", "A", "B"])
    #expect(store.isDirty)

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits == 0)

    store.endDrag()
    #expect(commits == 1)
    #expect(!store.isDirty)
}

@MainActor
@Test("A saved movement reorder waits for endDrag and commits once")
func reorderSavedMovementsCommitsOnce() async throws {
    let first = UUID()
    let second = UUID()
    let third = UUID()
    let block = reorderBlock("Push", movementIDs: [first, second, third])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [block]),
        delay: .milliseconds(60)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }
    let ids = block.movements.map(\.id)

    store.beginDrag()
    #expect(store.reorderMovements(in: .saved(block.id), to: [ids[2], ids[0], ids[1]]))
    #expect(store.session.blocks[0].movements.map(\.movementId) == [third, first, second])

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits == 0)

    store.endDrag()
    #expect(commits == 1)
}

@MainActor
@Test("A staged movement reorder stays in the staged block and never commits")
func reorderStagedMovements() async throws {
    let previous = reorderBlock("Push", movementIDs: [UUID()])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "One", blocks: [previous]),
        delay: .milliseconds(60)
    )
    var commits = 0
    store.commit = { _ in commits += 1 }
    store.beginStagedBlock(after: previous)
    #expect(store.appendMovements(
        [reorderAddition("Curl"), reorderAddition("Pushdown"), reorderAddition("Row")],
        to: .staged
    ))
    let ids = try #require(store.stagedBlock?.movements.map(\.id))
    #expect(ids.count == 3)

    store.beginDrag()
    #expect(store.reorderMovements(in: .staged, to: [ids[2], ids[0], ids[1]]))
    #expect(store.stagedBlock?.movements.map(\.id) == [ids[2], ids[0], ids[1]])
    #expect(store.session.blocks == [previous])
    #expect(!store.isDirty)

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits == 0)
    store.endDrag()
    #expect(commits == 0)
}

@MainActor
@Test("A reorder that is not a permutation changes nothing")
func reorderRejectsNonPermutation() {
    let first = reorderBlock("A", movementIDs: [UUID(), UUID()])
    let second = reorderBlock("B", movementIDs: [UUID()])
    let store = SessionDraftStore(session: WorkoutPreset(name: "Two", blocks: [first, second]))
    let original = store.session
    let movementIDs = first.movements.map(\.id)

    // Missing an id.
    #expect(!store.reorderBlocks(to: [first.id]))
    // A duplicate id.
    #expect(!store.reorderBlocks(to: [first.id, first.id]))
    // An unknown id.
    #expect(!store.reorderBlocks(to: [first.id, UUID()]))

    #expect(!store.reorderMovements(in: .saved(first.id), to: [movementIDs[0]]))
    #expect(!store.reorderMovements(in: .saved(first.id), to: [movementIDs[0], movementIDs[0]]))
    #expect(!store.reorderMovements(in: .saved(first.id), to: [movementIDs[0], UUID()]))
    #expect(!store.reorderMovements(in: .saved(UUID()), to: movementIDs))
    #expect(!store.reorderMovements(in: .staged, to: movementIDs))

    #expect(store.session == original)
    #expect(!store.isDirty)
}

@MainActor
@Test("An edit waiting when a drag begins is saved once at endDrag")
func pendingEditWaitsForEndDrag() async throws {
    let store = SessionDraftStore(session: .seeded, delay: .milliseconds(60))
    var commits = 0
    store.commit = { _ in commits += 1 }

    store.edit { $0.name = "Push Day" }
    store.beginDrag()

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits == 0)
    #expect(store.isDirty)

    store.endDrag()
    #expect(commits == 1)
    #expect(!store.isDirty)
}

@MainActor
@Test("A pending name edit and a reorder commit together once")
func pendingEditAndReorderCommitTogether() async throws {
    let first = reorderBlock("A", movementIDs: [UUID()])
    let second = reorderBlock("B", movementIDs: [UUID()])
    let store = SessionDraftStore(
        session: WorkoutPreset(name: "Two", blocks: [first, second]),
        delay: .milliseconds(60)
    )
    var commits: [WorkoutPreset] = []
    store.commit = { commits.append($0) }

    store.edit { $0.name = "Two Day" }
    store.beginDrag()
    #expect(store.reorderBlocks(to: [second.id, first.id]))

    try await Task.sleep(for: .milliseconds(220))
    #expect(commits.isEmpty)

    store.endDrag()
    #expect(commits.count == 1)
    #expect(commits[0].name == "Two Day")
    #expect(commits[0].blocks.map(\.name) == ["B", "A"])
}
