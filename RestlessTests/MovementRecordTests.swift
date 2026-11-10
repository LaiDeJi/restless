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
    let movement = MovementRepository.add(Movement(name: "Face pull"), in: context)

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

@MainActor
@Test("A legacy store with profile columns still opens name-only")
func legacyProfileColumnsAreDormant() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let legacy = MovementRecord(Movement(name: "Curl"))
    legacy.axisRaw = "Y"
    legacy.rise = 33
    legacy.fall = 27
    legacy.minPeriod = 0.9
    legacy.group = "Biceps"
    context.insert(legacy)
    try context.save()

    let opened = try #require(MovementRepository.find(legacy.id, in: context))
    #expect(opened.movement.name == "Curl")
    #expect(opened.axisRaw == "Y")

    let renamed = MovementRepository.rename(legacy.id, to: "Hammer curl", in: context)
    #expect(renamed?.name == "Hammer curl")
    // Legacy columns are never rewritten.
    #expect(opened.axisRaw == "Y")
    #expect(opened.rise == 33)
}
