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
@Test("Seeding creates the Chest movement once")
func seedCreatesChest() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    let first = MovementRepository.seedIfNeeded(in: context)
    let second = MovementRepository.seedIfNeeded(in: context)

    #expect(first.count == 1)
    #expect(second.count == 1)
    #expect(MovementRepository.fetchAll(context).count == 1)
    #expect(first[0].id == Movement.chestID)
    #expect(first[0].name == "Chest")
    #expect(first[0].profile == nil)
}

@MainActor
@Test("A movement can be added and renamed")
func movementCRUD() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let profile = MovementProfile(axis: .y, rise: 33, fall: 27, minPeriod: 0.9)
    let added = MovementRepository.add(
        Movement(name: "Curl", profile: profile),
        in: context
    )

    #expect(MovementRepository.fetchAll(context).count == 1)
    #expect(added.name == "Curl")
    #expect(added.profile == profile)

    let renamed = MovementRepository.rename(added.id, to: "Hammer curl", in: context)
    #expect(renamed?.name == "Hammer curl")

    let updated = MovementProfile(axis: .y, rise: 40, fall: 30, minPeriod: 1.1)
    let recorded = MovementRepository.reRecord(added.id, profile: updated, in: context)
    #expect(recorded?.profile == updated)
    #expect(recorded?.name == "Hammer curl")
}

@MainActor
@Test("Deleting a movement used by a session is refused and names the session")
func deleteUsedMovementIsRefused() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    MovementRepository.seedIfNeeded(in: context)

    let preset = WorkoutPreset(
        name: "Chest",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 1,
                setsPerRound: 3,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: Movement.chestID, endCondition: .manual)]
            )
        ]
    )
    let record = PresetRecord(preset)
    context.insert(record)
    try context.save()

    #expect(throws: MovementDeleteError.inUse(["Chest"])) {
        try MovementRepository.delete(Movement.chestID, in: context)
    }
    #expect(MovementRepository.find(Movement.chestID, in: context) != nil)
}

@MainActor
@Test("An unused movement is deleted")
func deleteUnusedMovement() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let profile = MovementProfile(axis: .y, rise: 30, fall: 25, minPeriod: 1.0)
    let movement = MovementRepository.add(
        Movement(name: "Face pull", profile: profile),
        in: context
    )

    try MovementRepository.delete(movement.id, in: context)

    #expect(MovementRepository.find(movement.id, in: context) == nil)
    #expect(MovementRepository.fetchAll(context).isEmpty)
}

@MainActor
@Test("Migrated parts get library entries and a usage check")
func ensureLibraryForMigratedParts() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let biceps = WorkoutPart(name: "Biceps", rounds: 3, setsPerRound: 3, setRest: 60, roundRest: 120)
    let record = PresetRecord(.chest)
    record.name = "Arms"
    record.blocksData = nil
    record.partsData = try JSONEncoder().encode([biceps])
    context.insert(record)
    try context.save()

    MovementRepository.ensureLibrary(for: [record], in: context)
    try context.save()

    let movementRecord = try #require(MovementRepository.find(biceps.id, in: context))
    let movement = movementRecord.movement
    #expect(movement.name == "Biceps")
    #expect(MovementRepository.usage(biceps.id, in: context) == ["Arms"])
    #expect(throws: MovementDeleteError.inUse(["Arms"])) {
        try MovementRepository.delete(biceps.id, in: context)
    }
}

@MainActor
@Test("A typed movement name is trimmed, capped, and reused ignoring case")
func addOrReuseMovement() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    let created = try #require(MovementRepository.addOrReuse(name: "  Cable Fly  ", in: context))
    #expect(created.name == "Cable Fly")
    #expect(created.profile == nil)
    #expect(MovementRepository.fetchAll(context).count == 1)

    let reused = try #require(MovementRepository.addOrReuse(name: "cable fly", in: context))
    #expect(reused.id == created.id)
    #expect(MovementRepository.fetchAll(context).count == 1)

    let capped = try #require(
        MovementRepository.addOrReuse(name: "  Cable fly variation  ", in: context)
    )
    #expect(capped.name == "Cable fly variatio")
    #expect(capped.profile == nil)

    #expect(MovementRepository.addOrReuse(name: "   ", in: context) == nil)
    #expect(MovementRepository.fetchAll(context).count == 2)
}
