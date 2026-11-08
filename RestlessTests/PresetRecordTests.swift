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
@Test("A legacy record with no plan data reads one block from the old columns")
func legacyRecordReadsOneBlock() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let record = PresetRecord(.chest)
    record.blocksData = nil
    record.partsData = nil
    record.name = "Legacy"
    record.rounds = 4
    record.setsPerRound = 2
    record.setRest = 45
    record.roundRest = 90
    context.insert(record)
    try context.save()

    #expect(record.blocks.count == 1)
    let block = record.blocks[0]
    #expect(block.id == record.id)
    #expect(block.name == "Legacy")
    #expect(block.rounds == 4)
    #expect(block.setsPerRound == 2)
    #expect(block.setRest == 45)
    #expect(block.roundRest == 90)
    #expect(block.movements.count == 1)
    #expect(block.movements[0].movementId == record.id)
    #expect(block.movements[0].endCondition == .manual)
    #expect(block.movements[0].target == nil)
    #expect(record.preset.totalSets == 8)
    // 4 rounds × 1 set rest × 45 + 3 round rests × 90; the old rhythm survives.
    #expect(record.preset.totalRest == 450)
    #expect(record.preset.id == record.id)
}

@MainActor
@Test("partsData reads as one block per part with its rounds and sets per round")
func partsDataFallback() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let biceps = WorkoutPart(name: "Biceps", rounds: 3, setsPerRound: 3, setRest: 60, roundRest: 120)
    let triceps = WorkoutPart(name: "Triceps", rounds: 2, setsPerRound: 4, setRest: 45, roundRest: 90)
    let record = PresetRecord(.chest)
    record.name = "Arms"
    record.blocksData = nil
    record.partsData = try JSONEncoder().encode([biceps, triceps])
    context.insert(record)
    try context.save()

    #expect(record.blocks.count == 2)
    #expect(record.blocks[0].name == "Biceps")
    #expect(record.blocks[0].rounds == 3)
    #expect(record.blocks[0].setsPerRound == 3)
    #expect(record.blocks[0].movements[0].movementId == biceps.id)
    #expect(record.blocks[0].movements[0].endCondition == .manual)
    #expect(record.blocks[1].name == "Triceps")
    #expect(record.blocks[1].rounds == 2)
    #expect(record.blocks[1].setsPerRound == 4)
    #expect(record.preset.totalSets == 17)
    // Biceps: 6 set rests × 60 + 2 round rests × 120; Triceps: 6 × 45 + 90; Biceps transition 120.
    #expect(record.preset.totalRest == 1080)
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
                name: "Chest",
                rounds: 2,
                setsPerRound: 2,
                setRest: 60,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: bench, endCondition: .reps, target: 10),
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

    #expect(record.partsData == nil)
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
@Test("apply replaces the blocks and mirrors rounds and total sets per round")
func applyMirrorsFirstBlock() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let record = PresetRecord(.chest)
    context.insert(record)

    let first = WorkoutBlock(
        name: "Chest",
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
    #expect(record.rounds == 3)
    #expect(record.setsPerRound == 8)
    #expect(record.setRest == 30)
    #expect(record.roundRest == 75)
    #expect(record.partsData == nil)
    #expect(record.blocks.map(\.id) == [first.id, second.id])
    #expect(record.preset.id == record.id)

    let fetched = try context.fetch(FetchDescriptor<PresetRecord>())
    #expect(fetched.count == 1)
    #expect(fetched[0].blocks.map(\.id) == [first.id, second.id])
}

@MainActor
@Test("A legacy circuit in blocksData collapses duplicate rows on read")
func duplicateRowsCollapseOnRead() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let movement = #"{"movementId":"00000000-0000-0000-0000-00000000B3A1","endCondition":"manual"}"#
    let json = #"""
    [{
      "name": "Curls",
      "kind": "circuit",
      "count": 4,
      "setRest": 30,
      "roundRest": 120,
      "movements": [\#(movement), \#(movement), \#(movement), \#(movement)]
    }]
    """#
    let record = PresetRecord(.chest)
    record.blocksData = Data(json.utf8)
    context.insert(record)
    try context.save()

    #expect(record.blocks.count == 1)
    #expect(record.blocks[0].rounds == 4)
    #expect(record.blocks[0].setsPerRound == 4)
    #expect(record.blocks[0].movements.count == 1)
    #expect(record.preset.totalSets == 16)
    #expect(record.preset.totalRest == 720)
}
