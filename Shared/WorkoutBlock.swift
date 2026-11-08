import Foundation

/// How a set ends. The condition belongs to the block movement, with a default
/// from the library movement.
enum EndCondition: String, Codable, Hashable, Sendable, CaseIterable {
    case reps
    case time
    case manual

    /// The order the editors list the choices in. MANUAL leads because a new
    /// movement has no profile yet and a manual set needs none.
    static let editorOrder: [EndCondition] = [.manual, .time, .reps]

    /// REPS needs a recorded profile for the watch to count; MANUAL and TIME
    /// end on the tap or the countdown.
    var requiresWatchProfile: Bool { self == .reps }

    var label: String {
        switch self {
        case .reps: "REPS"
        case .time: "TIME"
        case .manual: "MANUAL"
        }
    }
}

enum MovementAxis: String, Codable, Hashable, Sendable, CaseIterable {
    case x
    case y
    case z

    var label: String { rawValue.uppercased() }
}

/// The four numbers the watch applies to count a movement. The signal is the
/// forearm elevation: the angle between gravity and the watch's +Y axis, which
/// runs along the forearm. Rotating the watch face around the forearm does not
/// change it. `rise` and `fall` are degrees; `minPeriod` is seconds.
struct MovementProfile: Codable, Hashable, Sendable {
    var axis: MovementAxis
    var rise: Double
    var fall: Double
    var minPeriod: Double

    init(axis: MovementAxis, rise: Double, fall: Double, minPeriod: Double) {
        self.axis = axis
        self.rise = rise
        self.fall = fall
        self.minPeriod = minPeriod
    }

    func clamped() -> MovementProfile {
        var copy = self
        copy.rise = min(max(rise, 0), 180)
        copy.fall = min(max(fall, 0), 180)
        copy.minPeriod = min(max(minPeriod, 0.01), 10)
        return copy
    }

    var usesForearmSignal: Bool {
        rise >= 5 && fall >= 4
    }
}

/// A reusable library movement: a name and an optional recorded profile. The
/// end condition and target belong to the block that uses it, not to the
/// library entry.
struct Movement: Codable, Hashable, Identifiable, Sendable {
    /// Stable id of the seeded `Chest` movement, shared by the seeded session.
    static let chestID = UUID(uuidString: "00000000-0000-0000-0000-00000000C4E5")!

    var id: UUID
    var name: String
    var profile: MovementProfile?

    init(
        id: UUID = UUID(),
        name: String,
        profile: MovementProfile? = nil
    ) {
        self.id = id
        self.name = name
        self.profile = profile
    }

    static let chest = Movement(
        id: chestID,
        name: "Chest",
        profile: nil
    )

    func clamped() -> Movement {
        var copy = self
        copy.name = WorkoutPreset.clampedName(name, fallback: "Untitled movement")
        copy.profile = profile?.clamped()
        return copy
    }
}

/// A movement used by a block. The identity is `movementId`; the end condition
/// and target belong to this use, not to the library movement.
struct BlockMovement: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var movementId: UUID
    var endCondition: EndCondition
    var target: Int?

    init(
        id: UUID = UUID(),
        movementId: UUID,
        endCondition: EndCondition = .manual,
        target: Int? = nil
    ) {
        self.id = id
        self.movementId = movementId
        self.endCondition = endCondition
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case id, movementId, endCondition, target
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        movementId = try container.decode(UUID.self, forKey: .movementId)
        let condition = try container.decodeIfPresent(EndCondition.self, forKey: .endCondition) ?? .manual
        endCondition = condition
        target = WorkoutPreset.clampedTarget(condition, try container.decodeIfPresent(Int.self, forKey: .target))
    }

    func clamped() -> BlockMovement {
        var copy = self
        copy.endCondition = endCondition
        copy.target = WorkoutPreset.clampedTarget(endCondition, target)
        return copy
    }

    var isTimed: Bool { endCondition == .time }
    var isCounted: Bool { endCondition == .reps }
}

/// One ordered block in a session. A schedule is two numbers: `rounds` and
/// `setsPerRound`, run across the block's ordered movements. Pure value type:
/// no SwiftUI, no persistence.
struct WorkoutBlock: Codable, Hashable, Identifiable, Sendable {
    static let defaultRounds = 1
    static let defaultSetsPerRound = 3
    static let defaultSetRest = 60
    static let defaultRoundRest = 120

    var id: UUID
    var name: String
    /// 1 or more.
    var rounds: Int
    /// 1 or more.
    var setsPerRound: Int
    /// Seconds. The set rest may be 0; everything else is 15–600.
    var setRest: Int
    var roundRest: Int
    var movements: [BlockMovement]

    init(
        id: UUID = UUID(),
        name: String = "Untitled block",
        rounds: Int = WorkoutBlock.defaultRounds,
        setsPerRound: Int = WorkoutBlock.defaultSetsPerRound,
        setRest: Int = WorkoutBlock.defaultSetRest,
        roundRest: Int = WorkoutBlock.defaultRoundRest,
        movements: [BlockMovement] = []
    ) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.setsPerRound = setsPerRound
        self.setRest = setRest
        self.roundRest = roundRest
        self.movements = movements
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, rounds, setsPerRound, setRest, roundRest, movements
        // Legacy keys, read only. A plan-level decode uses `StoredBlock` so a
        // straight multi-movement block can split.
        case kind, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled block"
        let legacyCount = try container.decodeIfPresent(Int.self, forKey: .count)
        rounds = max(
            try container.decodeIfPresent(Int.self, forKey: .rounds) ?? WorkoutBlock.defaultRounds,
            1
        )
        setsPerRound = max(
            try container.decodeIfPresent(Int.self, forKey: .setsPerRound)
                ?? legacyCount
                ?? WorkoutBlock.defaultSetsPerRound,
            1
        )
        setRest = try container.decodeIfPresent(Int.self, forKey: .setRest) ?? WorkoutBlock.defaultSetRest
        roundRest = try container.decodeIfPresent(Int.self, forKey: .roundRest) ?? WorkoutBlock.defaultRoundRest
        movements = try container.decodeIfPresent([BlockMovement].self, forKey: .movements) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rounds, forKey: .rounds)
        try container.encode(setsPerRound, forKey: .setsPerRound)
        try container.encode(setRest, forKey: .setRest)
        try container.encode(roundRest, forKey: .roundRest)
        try container.encode(movements, forKey: .movements)
    }

    /// Sets in one round across every movement.
    var perRoundSets: Int {
        guard !movements.isEmpty else { return 0 }
        return safeProduct(max(setsPerRound, 1), movements.count)
    }

    var totalSets: Int {
        guard !movements.isEmpty else { return 0 }
        return safeProduct(max(rounds, 1), perRoundSets)
    }

    /// Rest the block contributes, including its transition to the next block.
    func totalRest(hasNextBlock: Bool) -> Int {
        guard !movements.isEmpty else { return 0 }
        let setRests = safeProduct(
            safeProduct(max(rounds, 1), max(perRoundSets - 1, 0)),
            setRest
        )
        let roundRests = safeProduct(
            safeSum(max(rounds - 1, 0), hasNextBlock ? 1 : 0),
            roundRest
        )
        return safeSum(setRests, roundRests)
    }

    var totalRest: Int { totalRest(hasNextBlock: false) }

    func clamped() -> WorkoutBlock? {
        var copy = self
        copy.name = WorkoutPreset.clampedName(name, fallback: "Untitled block")
        copy.rounds = max(rounds, 1)
        copy.setsPerRound = max(setsPerRound, 1)
        copy.setRest = WorkoutPreset.clampedSetRest(setRest)
        copy.roundRest = WorkoutPreset.clampedRest(roundRest)
        copy.movements = movements.map { $0.clamped() }
        guard !copy.movements.isEmpty else { return nil }
        return copy
    }

    static var fallback: WorkoutBlock {
        WorkoutBlock(
            name: "Untitled block",
            rounds: WorkoutBlock.defaultRounds,
            setsPerRound: WorkoutBlock.defaultSetsPerRound,
            setRest: WorkoutBlock.defaultSetRest,
            roundRest: WorkoutBlock.defaultRoundRest,
            movements: [
                BlockMovement(movementId: Movement.chestID, endCondition: .manual, target: nil)
            ]
        )
    }
}

// MARK: - Stored shape and migration

/// The persisted block shape, new or legacy. `WorkoutBlock` writes only
/// `rounds` and `setsPerRound`; this type also reads the old `kind`/`count`
/// pair so a stored plan can be migrated at the plan boundary, where a straight
/// multi-movement block can split into several blocks.
struct StoredBlock: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case straight
        case circuit
    }

    var id: UUID?
    var name: String?
    var rounds: Int?
    var setsPerRound: Int?
    var kind: Kind?
    var count: Int?
    var setRest: Int?
    var roundRest: Int?
    var movements: [BlockMovement]?

    private enum CodingKeys: String, CodingKey {
        case id, name, rounds, setsPerRound, kind, count, setRest, roundRest, movements
    }

    /// Emits one or more blocks in the current shape.
    func migratedBlocks() -> [WorkoutBlock] {
        let movements = self.movements ?? []
        if rounds != nil || setsPerRound != nil {
            return [
                block(
                    rounds: rounds ?? WorkoutBlock.defaultRounds,
                    setsPerRound: setsPerRound ?? count ?? WorkoutBlock.defaultSetsPerRound,
                    movements: movements
                )
            ]
        }

        switch kind {
        case .circuit:
            return [circuitBlock(movements)]
        case .straight, nil:
            if kind == .straight, movements.count > 1 {
                let storedID = id
                return movements.enumerated().map { index, movement in
                    block(
                        id: index == 0 ? storedID : UUID(),
                        rounds: 1,
                        setsPerRound: count ?? WorkoutBlock.defaultSetsPerRound,
                        movements: [movement]
                    )
                }
            }
            return [
                block(
                    rounds: 1,
                    setsPerRound: count ?? WorkoutBlock.defaultSetsPerRound,
                    movements: movements
                )
            ]
        }
    }

    private func circuitBlock(_ movements: [BlockMovement]) -> WorkoutBlock {
        let runs = Self.adjacentRuns(movements)
        let lengths = Set(runs.map(\.count))
        guard runs.count < movements.count, lengths.count == 1, let perRound = lengths.first else {
            return block(
                rounds: count ?? WorkoutBlock.defaultRounds,
                setsPerRound: 1,
                movements: movements
            )
        }
        return block(
            rounds: count ?? WorkoutBlock.defaultRounds,
            setsPerRound: perRound,
            movements: runs.compactMap(\.first)
        )
    }

    private func block(
        id: UUID? = nil,
        rounds: Int,
        setsPerRound: Int,
        movements: [BlockMovement]
    ) -> WorkoutBlock {
        WorkoutBlock(
            id: id ?? self.id ?? UUID(),
            name: name ?? "Untitled block",
            rounds: max(rounds, 1),
            setsPerRound: max(setsPerRound, 1),
            setRest: setRest ?? WorkoutBlock.defaultSetRest,
            roundRest: roundRest ?? WorkoutBlock.defaultRoundRest,
            movements: movements
        )
    }

    /// Groups adjacent movements that match on library movement, end condition,
    /// and target. Non-adjacent or differing rows stay separate.
    private static func adjacentRuns(_ movements: [BlockMovement]) -> [[BlockMovement]] {
        var runs: [[BlockMovement]] = []
        for movement in movements {
            if let last = runs.last?.last,
               last.movementId == movement.movementId,
               last.endCondition == movement.endCondition,
               last.target == movement.target {
                runs[runs.count - 1].append(movement)
            } else {
                runs.append([movement])
            }
        }
        return runs
    }
}

extension EndCondition {
    /// The target a condition needs. A manual set carries no target.
    func clampedTarget(_ target: Int?) -> Int? {
        switch self {
        case .manual: nil
        case .reps: max(target ?? 1, 1)
        case .time: WorkoutPreset.clampedSetDuration(target ?? 60)
        }
    }
}
