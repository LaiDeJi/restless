import Foundation
import SwiftData
import Testing
@testable import Restless

private func memoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: PresetRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
@Test("Blocks round-trip through JSON and keep block and movement ids")
func blocksRoundTrip() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let bench = UUID()
    let incline = UUID()
    let curl = UUID()
    let preset = WorkoutPreset(
        name: "Arms",
        blocks: [
            WorkoutBlock(
                name: "Push",
                rounds: 2,
                setsPerRound: 2,
                setRest: 60,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: bench, endCondition: .manual),
                    BlockMovement(movementId: incline, endCondition: .time, target: 45)
                ]
            ),
            WorkoutBlock(
                name: "Arms",
                rounds: 4,
                setsPerRound: 1,
                setRest: 0,
                roundRest: 90,
                movements: [
                    BlockMovement(movementId: curl, endCondition: .manual)
                ]
            )
        ]
    )
    let record = PresetRecord(preset)
    context.insert(record)
    try context.save()

    #expect(record.blocks == preset.blocks)
    #expect(record.blocks.map(\.id) == preset.blocks.map(\.id))
    #expect(record.blocks[0].movements.map(\.id) == preset.blocks[0].movements.map(\.id))
    #expect(record.blocks[0].movements.map(\.movementId) == [bench, incline])
    #expect(record.blocks[1].setRest == 0)

    let data = try #require(record.blocksData)
    let decoded = try JSONDecoder().decode([WorkoutBlock].self, from: data)
    #expect(decoded == preset.blocks)
    #expect(record.preset == WorkoutPreset(id: record.id, name: "Arms", blocks: preset.blocks))
}

@MainActor
@Test("apply replaces the blocks")
func applyReplacesBlocks() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let record = PresetRecord(.seeded)
    context.insert(record)

    let first = WorkoutBlock(
        name: "Push",
        rounds: 3,
        setsPerRound: 4,
        setRest: 30,
        roundRest: 75,
        movements: [
            BlockMovement(movementId: UUID(), endCondition: .manual),
            BlockMovement(movementId: UUID(), endCondition: .manual)
        ]
    )
    let second = WorkoutBlock(
        name: "Arms",
        rounds: 2,
        setsPerRound: 1,
        setRest: 15,
        roundRest: 90,
        movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
    )
    let preset = WorkoutPreset(name: "Arms", blocks: [first, second])
    record.apply(preset)
    try context.save()

    #expect(record.name == "Arms")
    #expect(record.blocks.map(\.id) == [first.id, second.id])
    #expect(record.preset.id == record.id)

    let fetched = try context.fetch(FetchDescriptor<PresetRecord>())
    #expect(fetched.count == 1)
    #expect(fetched[0].blocks.map(\.id) == [first.id, second.id])
}

@MainActor
@Test("Legacy rows with no sort index read in creation order and normalize to 0..<n")
func legacyOrderNormalizes() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let base = Date(timeIntervalSince1970: 1_000_000)
    var made: [PresetRecord] = []
    for (index, name) in ["Push", "Arms", "Core"].enumerated() {
        let record = PresetRecord(.seeded)
        record.name = name
        record.createdAt = base.addingTimeInterval(TimeInterval(index))
        record.sortIndex = nil
        context.insert(record)
        made.append(record)
    }
    try context.save()

    #expect(PresetRepository.fetchAll(context).map(\.name) == ["Push", "Arms", "Core"])

    PresetRepository.normalizeOrder(in: context)

    let ordered = PresetRepository.fetchAll(context)
    #expect(ordered.map(\.name) == ["Push", "Arms", "Core"])
    #expect(ordered.map(\.sortIndex) == [0, 1, 2])
}

@MainActor
@Test("A manual order survives a read and a gap normalizes back to 0..<n")
func manualOrderSurvivesRead() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    var made: [PresetRecord] = []
    for (index, name) in ["Push", "Arms", "Core"].enumerated() {
        let record = PresetRecord(.seeded)
        record.name = name
        record.createdAt = Date(timeIntervalSince1970: 1_000_000 + Double(index))
        record.sortIndex = index
        context.insert(record)
        made.append(record)
    }
    try context.save()

    made[2].sortIndex = -1
    try context.save()
    #expect(PresetRepository.fetchAll(context).map(\.name) == ["Core", "Push", "Arms"])

    made[2].sortIndex = 7
    try context.save()
    PresetRepository.normalizeOrder(in: context)

    let ordered = PresetRepository.fetchAll(context)
    #expect(ordered.map(\.name) == ["Push", "Arms", "Core"])
    #expect(ordered.map(\.sortIndex) == [0, 1, 2])
}

@MainActor
@Test("A new session appends after the existing ones")
func newSessionAppends() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    for (index, name) in ["Push", "Arms"].enumerated() {
        let record = PresetRecord(.seeded)
        record.name = name
        record.createdAt = Date(timeIntervalSince1970: 1_000_000 + Double(index))
        record.sortIndex = index
        context.insert(record)
    }
    try context.save()

    var draft = WorkoutPreset(name: "Core", blocks: [.fallback])
    draft.name = "Core"
    let saved = try #require(SessionDraftCommit.save(draft, usedNames: ["Push", "Arms"], in: context))

    let ordered = PresetRepository.fetchAll(context)
    #expect(ordered.map(\.name) == ["Push", "Arms", "Core"])
    #expect(ordered.last?.id == saved.id)
    #expect(saved.sortIndex == 2)
}
