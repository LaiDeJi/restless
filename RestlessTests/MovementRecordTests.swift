import Foundation
import SwiftData
import Testing
@testable import Restless

private func memoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: PresetRecord.self, MovementRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
@Test("Seeding creates the seeded movement once")
func seedCreatesSeeded() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    let first = MovementRepository.seedIfNeeded(in: context)
    let second = MovementRepository.seedIfNeeded(in: context)

    #expect(first.count == 1)
    #expect(second.count == 1)
    #expect(MovementRepository.fetchAll(context).count == 1)
    #expect(first[0].id == Movement.seededID)
    #expect(first[0].name == "Movement 1")
}

@MainActor
@Test("A movement is added, renamed, and keeps its name only")
func movementCRUD() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let added = MovementRepository.add(Movement(name: "Curl"), in: context)

    #expect(MovementRepository.fetchAll(context).count == 1)
    #expect(added.name == "Curl")

    let renamed = MovementRepository.rename(added.id, to: "Hammer curl", in: context)
    #expect(renamed?.name == "Hammer curl")
    #expect(MovementRepository.find(added.id, in: context)?.movement.name == "Hammer curl")
}

@MainActor
@Test("Deleting a movement used by a session is refused and names the session")
func deleteUsedMovementIsRefused() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    MovementRepository.seedIfNeeded(in: context)

    let preset = WorkoutPreset(
        name: "Push",
        blocks: [
            WorkoutBlock(
                name: "Push",
                rounds: 1,
                setsPerRound: 3,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: Movement.seededID, endCondition: .manual)]
            )
        ]
    )
    let record = PresetRecord(preset)
    context.insert(record)
    try context.save()

    #expect(throws: MovementDeleteError.inUse(["Push"])) {
        try MovementRepository.delete(Movement.seededID, in: context)
    }
    #expect(MovementRepository.find(Movement.seededID, in: context) != nil)
}

@MainActor
@Test("An unused movement is deleted")
func deleteUnusedMovement() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let movement = MovementRepository.add(Movement(name: "Face pull"), in: context)

    try MovementRepository.delete(movement.id, in: context)

    #expect(MovementRepository.find(movement.id, in: context) == nil)
    #expect(MovementRepository.fetchAll(context).isEmpty)
}

@MainActor
@Test("A typed movement name is trimmed, capped, and reused ignoring case")
func addOrReuseMovement() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    let created = try #require(MovementRepository.addOrReuse(name: "  Cable Fly  ", in: context))
    #expect(created.name == "Cable Fly")
    #expect(MovementRepository.fetchAll(context).count == 1)

    let reused = try #require(MovementRepository.addOrReuse(name: "cable fly", in: context))
    #expect(reused.id == created.id)
    #expect(MovementRepository.fetchAll(context).count == 1)

    let capped = try #require(
        MovementRepository.addOrReuse(name: "  Cable fly variation  ", in: context)
    )
    #expect(capped.name == "Cable fly variation")

    #expect(MovementRepository.addOrReuse(name: "   ", in: context) == nil)
    #expect(MovementRepository.fetchAll(context).count == 2)
}
