import Foundation
import Testing
@testable import Restless

private let benchID = UUID(uuidString: "00000000-0000-0000-0000-00000000B3A1")!
private let inclineID = UUID(uuidString: "00000000-0000-0000-0000-00000000B3A2")!
private let blockID = UUID(uuidString: "00000000-0000-0000-0000-00000000B10C")!

private func decode(_ json: String) throws -> StoredBlock {
    try JSONDecoder().decode(StoredBlock.self, from: Data(json.utf8))
}

@Test("The new block keys decode as one block")
func newShapeDecodes() throws {
    let stored = try decode(#"""
    {
      "id": "00000000-0000-0000-0000-00000000B10C",
      "name": "Heavy",
      "rounds": 4,
      "setsPerRound": 4,
      "setRest": 60,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks.count == 1)
    #expect(blocks[0].id == blockID)
    #expect(blocks[0].name == "Heavy")
    #expect(blocks[0].rounds == 4)
    #expect(blocks[0].setsPerRound == 4)
    #expect(blocks[0].setRest == 60)
    #expect(blocks[0].roundRest == 120)
    #expect(blocks[0].totalSets == 16)
}

@Test("A legacy straight block with one movement becomes rounds 1 and sets per round count")
func legacyStraightDecodes() throws {
    let stored = try decode(#"""
    {
      "id": "00000000-0000-0000-0000-00000000B10C",
      "name": "Chest",
      "kind": "straight",
      "count": 9,
      "setRest": 60,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks.count == 1)
    #expect(blocks[0].rounds == 1)
    #expect(blocks[0].setsPerRound == 9)
    #expect(blocks[0].totalSets == 9)
}

@Test("A legacy straight block with two movements splits into one block per movement")
func legacyStraightSplits() throws {
    let stored = try decode(#"""
    {
      "id": "00000000-0000-0000-0000-00000000B10C",
      "name": "Chest",
      "kind": "straight",
      "count": 3,
      "setRest": 60,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
        {"movementId": "00000000-0000-0000-0000-00000000B3A2", "endCondition": "manual"}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks.count == 2)
    #expect(blocks.map(\.name) == ["Chest", "Chest"])
    #expect(blocks[0].id == blockID)
    #expect(blocks[0].id != blocks[1].id)
    #expect(blocks.map(\.rounds) == [1, 1])
    #expect(blocks.map(\.setsPerRound) == [3, 3])
    #expect(blocks.map { $0.movements.map(\.movementId) } == [[benchID], [inclineID]])
    #expect(blocks[0].totalRest(hasNextBlock: true) == 240)
}

@Test("A legacy circuit becomes rounds count and one set per round")
func legacyCircuitDecodes() throws {
    let stored = try decode(#"""
    {
      "name": "Arms",
      "kind": "circuit",
      "count": 3,
      "setRest": 30,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
        {"movementId": "00000000-0000-0000-0000-00000000B3A2", "endCondition": "manual"}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks.count == 1)
    #expect(blocks[0].rounds == 3)
    #expect(blocks[0].setsPerRound == 1)
    #expect(blocks[0].totalSets == 6)
    // Movement-major: no set rests at one set per round, 2 round rests per
    // movement plus the switch, all at 120.
    #expect(blocks[0].totalRest == 600)
}

@Test("Four adjacent duplicate circuit rows collapse to one movement with four sets per round")
func duplicateCircuitCollapses() throws {
    let movement = #"{"movementId":"00000000-0000-0000-0000-00000000B3A1","endCondition":"manual"}"#
    let stored = try decode(#"""
    {
      "name": "Curls",
      "kind": "circuit",
      "count": 4,
      "setRest": 30,
      "roundRest": 120,
      "movements": [
        \#(movement), \#(movement), \#(movement), \#(movement)
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks.count == 1)
    #expect(blocks[0].rounds == 4)
    #expect(blocks[0].setsPerRound == 4)
    #expect(blocks[0].movements.count == 1)
    #expect(blocks[0].totalSets == 16)
    #expect(blocks[0].totalRest == 720)
}

@Test("Adjacent duplicates with different end conditions stay separate")
func duplicateTargetsStaySeparate() throws {
    let stored = try decode(#"""
    {
      "name": "Curls",
      "kind": "circuit",
      "count": 2,
      "setRest": 30,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "time", "target": 45}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks[0].movements.count == 2)
    #expect(blocks[0].setsPerRound == 1)
    #expect(blocks[0].totalSets == 4)
}

@Test("Runs of different lengths are left alone")
func mixedDuplicateRunsStaySeparate() throws {
    let stored = try decode(#"""
    {
      "name": "Arms",
      "kind": "circuit",
      "count": 2,
      "setRest": 30,
      "roundRest": 120,
      "movements": [
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
        {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
        {"movementId": "00000000-0000-0000-0000-00000000B3A2", "endCondition": "manual"}
      ]
    }
    """#)
    let blocks = stored.migratedBlocks()
    #expect(blocks[0].movements.count == 3)
    #expect(blocks[0].setsPerRound == 1)
    #expect(blocks[0].totalSets == 6)
}

@Test("A legacy part keeps its rounds, sets per round, name, and rests")
func legacyPartKeepsShape() {
    let part = WorkoutPart(name: "Biceps", rounds: 3, setsPerRound: 3, setRest: 60, roundRest: 120)
    let block = WorkoutBlock(legacyPart: part)
    #expect(block.id == part.id)
    #expect(block.name == "Biceps")
    #expect(block.rounds == 3)
    #expect(block.setsPerRound == 3)
    #expect(block.setRest == 60)
    #expect(block.roundRest == 120)
    #expect(block.movements[0].movementId == part.id)
    #expect(block.movements[0].endCondition == .manual)
    #expect(block.totalSets == 9)
    #expect(block.totalRest == 600)
}

@Test("A stored preset with legacy blocks migrates at the plan boundary")
func presetMigratesLegacyBlocks() throws {
    let json = #"""
    {
      "name": "Chest",
      "blocks": [
        {
          "name": "Chest",
          "kind": "straight",
          "count": 3,
          "setRest": 60,
          "roundRest": 120,
          "movements": [
            {"movementId": "00000000-0000-0000-0000-00000000B3A1", "endCondition": "manual"},
            {"movementId": "00000000-0000-0000-0000-00000000B3A2", "endCondition": "manual"}
          ]
        }
      ]
    }
    """#
    let preset = try JSONDecoder().decode(WorkoutPreset.self, from: Data(json.utf8))
    #expect(preset.blocks.count == 2)
    #expect(preset.totalSets == 6)
    #expect(preset.blocks.map(\.setsPerRound) == [3, 3])
}

@Test("A current preset round-trips through JSON")
func presetRoundTrip() throws {
    let preset = WorkoutPreset(
        name: "Arms",
        blocks: [
            WorkoutBlock(
                name: "Arms",
                rounds: 2,
                setsPerRound: 1,
                setRest: 30,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: benchID, endCondition: .manual),
                    BlockMovement(movementId: inclineID, endCondition: .time, target: 45)
                ]
            )
        ]
    )
    let data = try JSONEncoder().encode(preset)
    let decoded = try JSONDecoder().decode(WorkoutPreset.self, from: data)
    #expect(decoded == preset)
}

@Test("A stored REPS row decodes as MANUAL with no target")
func storedRepsDecodesAsManual() throws {
    let json = #"""
    {"movementId":"00000000-0000-0000-0000-00000000B3A1","endCondition":"reps","target":10}
    """#
    let movement = try JSONDecoder().decode(BlockMovement.self, from: Data(json.utf8))
    #expect(movement.endCondition == .manual)
    #expect(movement.target == nil)
    #expect(movement.movementId == benchID)
}

@Test("An unknown stored end condition decodes as MANUAL")
func unknownConditionDecodesAsManual() throws {
    let json = #"""
    {"movementId":"00000000-0000-0000-0000-00000000B3A1","endCondition":"tempo","target":30}
    """#
    let movement = try JSONDecoder().decode(BlockMovement.self, from: Data(json.utf8))
    #expect(movement.endCondition == .manual)
    #expect(movement.target == nil)
}

@Test("Encoding writes only manual or time")
func endConditionEncodesRawValue() throws {
    let manual = try JSONEncoder().encode(BlockMovement(movementId: benchID, endCondition: .manual))
    #expect(try #require(String(bytes: manual, encoding: .utf8)).contains("\"manual\""))
    let timed = try JSONEncoder().encode(
        BlockMovement(movementId: benchID, endCondition: .time, target: 45)
    )
    #expect(try #require(String(bytes: timed, encoding: .utf8)).contains("\"time\""))
}

@Test("A multi-block plan with a stored REPS row keeps every block in order")
func storedMultiBlockWithRepsKeepsPlan() throws {
    let json = #"""
    {
      "id": "00000000-0000-0000-0000-00000000A11A",
      "name": "Full",
      "blocks": [
        {
          "id": "00000000-0000-0000-0000-00000000B10C",
          "name": "Chest",
          "rounds": 3,
          "setsPerRound": 4,
          "setRest": 60,
          "roundRest": 120,
          "movements": [
            {
            "id": "00000000-0000-0000-0000-00000000B3C1",
            "movementId": "00000000-0000-0000-0000-00000000B3A1",
            "endCondition": "manual"
          }
          ]
        },
        {
          "id": "00000000-0000-0000-0000-00000000B20C",
          "name": "Arms",
          "rounds": 2,
          "setsPerRound": 1,
          "setRest": 30,
          "roundRest": 90,
          "movements": [
            {
              "id": "00000000-0000-0000-0000-00000000B3C2",
              "movementId": "00000000-0000-0000-0000-00000000B3A2",
              "endCondition": "reps",
              "target": 10
            },
            {
              "id": "00000000-0000-0000-0000-00000000B3C3",
              "movementId": "00000000-0000-0000-0000-00000000B3A3",
              "endCondition": "manual"
            }
          ]
        }
      ]
    }
    """#
    let preset = try JSONDecoder().decode(WorkoutPreset.self, from: Data(json.utf8))
    #expect(preset.blocks.count == 2)
    #expect(preset.blocks.map(\.name) == ["Chest", "Arms"])
    #expect(preset.blocks.map(\.rounds) == [3, 2])
    #expect(preset.blocks.map(\.setsPerRound) == [4, 1])
    #expect(preset.blocks.map(\.setRest) == [60, 30])
    #expect(preset.blocks.map(\.roundRest) == [120, 90])
    #expect(preset.blocks[1].movements.map(\.id) == [
        UUID(uuidString: "00000000-0000-0000-0000-00000000B3C2")!,
        UUID(uuidString: "00000000-0000-0000-0000-00000000B3C3")!
    ])
    #expect(preset.blocks[1].movements[0].endCondition == .manual)
    #expect(preset.blocks[1].movements[0].target == nil)
    #expect(preset.totalSets == 16)
}
