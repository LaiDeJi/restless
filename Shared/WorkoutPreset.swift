import Foundation

/// A named session made of ordered blocks. Pure value type: no SwiftUI, no
/// persistence.
struct WorkoutPreset: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var blocks: [WorkoutBlock]

    init(id: UUID = UUID(), name: String, blocks: [WorkoutBlock]) {
        self.id = id
        self.name = name
        self.blocks = blocks.isEmpty ? [.fallback] : blocks
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, blocks
    }

    /// Reads the current block shape, migrating a plan written before blocks
    /// carried `rounds` and `setsPerRound`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        let stored = try container.decodeIfPresent([StoredBlock].self, forKey: .blocks) ?? []
        let migrated = stored.flatMap { $0.migratedBlocks() }
        blocks = migrated.isEmpty ? [.fallback] : migrated
    }

    static let chest = WorkoutPreset(
        name: "Chest",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 1,
                setsPerRound: 9,
                setRest: 60,
                roundRest: 120,
                movements: [
                    BlockMovement(movementId: Movement.chestID, endCondition: .manual, target: nil)
                ]
            )
        ]
    )

    static let bounds = Bounds()

    struct Bounds: Sendable {
        let rest = 15...600
        let setRest = 0...600
        let setDuration = 15...600
        let restStep = 15
        let nameLimit = 18
    }

    var totalSets: Int {
        blocks.reduce(0) { safeSum($0, $1.totalSets) }
    }

    /// Movement slots across every block, used by the done summary.
    var movementCount: Int {
        blocks.reduce(0) { safeSum($0, $1.movements.count) }
    }

    /// Every second of rest in the session, including each block's transition
    /// rest into the next block and excluding only the final set.
    var totalRest: Int {
        blocks.enumerated().reduce(0) { total, entry in
            safeSum(total, entry.element.totalRest(hasNextBlock: entry.offset < blocks.count - 1))
        }
    }

    /// Position of the set at `index` (0-based), clamped to the last set.
    func position(at index: Int) -> WorkoutPosition {
        var remaining = max(index, 0)

        for (blockIndex, block) in blocks.enumerated() {
            guard !block.movements.isEmpty else { continue }
            let setsInBlock = block.totalSets
            guard setsInBlock > 0 else { continue }
            if remaining < setsInBlock {
                return Self.position(in: block, blockIndex: blockIndex, indexInBlock: remaining)
            }
            remaining -= setsInBlock
        }

        for (blockIndex, block) in blocks.enumerated().reversed() where !block.movements.isEmpty {
            return Self.position(
                in: block,
                blockIndex: blockIndex,
                indexInBlock: max(block.totalSets - 1, 0)
            )
        }

        return WorkoutPosition(
            blockIndex: 0,
            blockName: name,
            movementIndex: 0,
            movementId: UUID(),
            round: 1,
            set: 1
        )
    }

    private static func position(
        in block: WorkoutBlock,
        blockIndex: Int,
        indexInBlock: Int
    ) -> WorkoutPosition {
        let sets = max(block.setsPerRound, 1)
        let perRound = max(block.perRoundSets, 1)
        let round = indexInBlock / perRound + 1
        let withinRound = indexInBlock % perRound
        let movementIndex = min(withinRound / sets, max(block.movements.count - 1, 0))
        let movement = block.movements.isEmpty
            ? BlockMovement(movementId: UUID())
            : block.movements[movementIndex]
        return WorkoutPosition(
            blockIndex: blockIndex,
            blockName: block.name,
            movementIndex: movementIndex,
            movementId: movement.movementId,
            round: round,
            set: withinRound % sets + 1
        )
    }

    /// Rest that follows the set at `doneSets`. `nil` means that was the last set.
    func rest(after doneSets: Int) -> RestOption? {
        guard doneSets < totalSets else { return nil }
        let position = position(at: doneSets)
        guard blocks.indices.contains(position.blockIndex) else { return nil }
        let block = blocks[position.blockIndex]
        guard !block.movements.isEmpty else { return nil }
        let sets = max(block.setsPerRound, 1)

        if position.set < sets {
            return RestOption(kind: .set, duration: block.setRest, transition: .set)
        }
        if position.movementIndex < block.movements.count - 1 {
            return RestOption(kind: .set, duration: block.setRest, transition: .movement)
        }
        if position.round < block.rounds {
            return RestOption(kind: .round, duration: block.roundRest, transition: .round)
        }
        guard position.blockIndex < blocks.count - 1 else { return nil }
        return RestOption(kind: .round, duration: block.roundRest, transition: .block)
    }

    func clamped() -> WorkoutPreset {
        var copy = self
        copy.name = Self.clampedName(name, fallback: "Untitled")
        copy.blocks = blocks.compactMap { $0.clamped() }
        if copy.blocks.isEmpty {
            copy.blocks = [.fallback]
        }
        return copy
    }

    static func clampedName(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(bounds.nameLimit))
    }

    static func clampedRest(_ seconds: Int) -> Int {
        let step = bounds.restStep
        let bounded = min(max(seconds, bounds.rest.lowerBound), bounds.rest.upperBound)
        let snapped = Int((Double(bounded) / Double(step)).rounded()) * step
        return min(max(snapped, bounds.rest.lowerBound), bounds.rest.upperBound)
    }

    /// A set rest goes down to zero; the first increase is one rest step.
    static func clampedSetRest(_ seconds: Int) -> Int {
        seconds <= 0 ? 0 : clampedRest(seconds)
    }

    static func clampedSetDuration(_ seconds: Int) -> Int {
        let step = bounds.restStep
        let bounded = min(max(seconds, bounds.setDuration.lowerBound), bounds.setDuration.upperBound)
        let snapped = Int((Double(bounded) / Double(step)).rounded()) * step
        return min(max(snapped, bounds.setDuration.lowerBound), bounds.setDuration.upperBound)
    }

    static func clampedTarget(_ condition: EndCondition, _ target: Int?) -> Int? {
        condition.clampedTarget(target)
    }
}

// MARK: - Position

struct WorkoutPosition: Hashable, Sendable {
    let blockIndex: Int
    let blockName: String
    let movementIndex: Int
    let movementId: UUID
    /// One-based round within the block.
    let round: Int
    /// One-based set within the movement's round.
    let set: Int
}

/// The round and set segments of a position. One helper so the timer and the
/// widget cannot drift.
struct RoundSetCopy: Hashable, Sendable {
    /// Non-nil only when the block has more than one round.
    let round: Int?
    let rounds: Int
    /// Non-nil only when the block has more than one set per round.
    let set: Int?
    let setsPerRound: Int

    var roundText: String? {
        guard let round else { return nil }
        return "ROUND \(round) OF \(rounds)"
    }

    var setText: String? {
        guard let set else { return nil }
        return "SET \(set) OF \(setsPerRound)"
    }

    var text: String {
        [roundText, setText].compactMap { $0 }.joined(separator: " · ")
    }
}

extension WorkoutPosition {
    func roundSetCopy(in block: WorkoutBlock) -> RoundSetCopy {
        RoundSetCopy(
            round: block.rounds > 1 ? round : nil,
            rounds: max(block.rounds, 1),
            set: block.setsPerRound > 1 ? set : nil,
            setsPerRound: max(block.setsPerRound, 1)
        )
    }
}

// MARK: - Rest

enum RestKind: String, Codable, Hashable, Sendable {
    case set
    case round

    var label: String {
        switch self {
        case .set: "SET REST"
        case .round: "ROUND REST"
        }
    }

    var shortLabel: String {
        switch self {
        case .set: "SET"
        case .round: "ROUND"
        }
    }
}

/// What a rest leads into. The duration kind decides the kicker; the transition
/// decides the copy and the accent.
enum RestTransition: String, Codable, Hashable, Sendable {
    case set
    case movement
    case round
    case block

    /// The accent is the set-rest green only for an inside-round set rest;
    /// every transition is the round-rest amber.
    var isSetAccent: Bool { self == .set }
}

enum RestAccent: Hashable, Sendable {
    case set
    case round
}

struct RestOption: Hashable, Sendable {
    let kind: RestKind
    let duration: Int
    let transition: RestTransition

    init(kind: RestKind, duration: Int, transition: RestTransition = .set) {
        self.kind = kind
        self.duration = duration
        self.transition = transition
    }

    var accent: RestAccent { transition.isSetAccent ? .set : .round }
    var isZero: Bool { duration <= 0 }
}

// MARK: - Legacy part bridge

/// The part shape the first version of the app used. It remains only for
/// reading `partsData` written by that version. New code uses `WorkoutBlock`.
struct WorkoutPart: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var rounds: Int
    var setsPerRound: Int
    var setRest: Int
    var roundRest: Int

    init(
        id: UUID = UUID(),
        name: String,
        rounds: Int,
        setsPerRound: Int,
        setRest: Int,
        roundRest: Int
    ) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.setsPerRound = setsPerRound
        self.setRest = setRest
        self.roundRest = roundRest
    }

    var totalSets: Int { safeProduct(rounds, setsPerRound) }
    var totalRest: Int { totalRest(hasNextPart: false) }

    func totalRest(hasNextPart: Bool) -> Int {
        let setRests = safeProduct(safeProduct(rounds, max(0, setsPerRound - 1)), setRest)
        let roundRests = max(0, rounds - 1) + (hasNextPart ? 1 : 0)
        return safeSum(setRests, safeProduct(roundRests, roundRest))
    }

    func clamped() -> WorkoutPart {
        var copy = self
        copy.name = WorkoutPreset.clampedName(name, fallback: "Untitled block")
        copy.rounds = max(rounds, 1)
        copy.setsPerRound = max(setsPerRound, 1)
        copy.setRest = WorkoutPreset.clampedRest(setRest)
        copy.roundRest = WorkoutPreset.clampedRest(roundRest)
        return copy
    }
}

extension WorkoutBlock {
    init(legacyPart part: WorkoutPart) {
        self.init(
            id: part.id,
            name: part.name,
            rounds: max(part.rounds, 1),
            setsPerRound: max(part.setsPerRound, 1),
            setRest: part.setRest,
            roundRest: part.roundRest,
            movements: [
                BlockMovement(
                    id: part.id,
                    movementId: part.id,
                    endCondition: .manual,
                    target: nil
                )
            ]
        )
    }
}

// MARK: - Display

/// `m:ss` for durations shown as a timer.
func clockString(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    return "\(clamped / 60):\(String(format: "%02d", clamped % 60))"
}

/// `m:ss` below an hour, `h:mm:ss` above it, for totals and summaries.
func durationString(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    let remainder = clamped % 60
    guard hours > 0 else { return "\(minutes):\(String(format: "%02d", remainder))" }
    return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remainder))"
}

/// `1 BLOCK`, `2 BLOCKS` — keeps a count and its noun in step.
func plural(_ count: Int, _ singular: String, _ plural: String) -> String {
    "\(count) \(count == 1 ? singular : plural)"
}

/// `2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS`.
func blockNumbers(_ block: WorkoutBlock) -> String {
    [
        plural(block.movements.count, "MOVEMENT", "MOVEMENTS"),
        plural(max(block.rounds, 1), "ROUND", "ROUNDS"),
        plural(max(block.setsPerRound, 1), "SET", "SETS") + " EACH",
        plural(block.totalSets, "SET", "SETS")
    ].joined(separator: " · ")
}

/// The session-editor row: the numbers and both rests.
func blockMeta(_ block: WorkoutBlock) -> String {
    blockNumbers(block)
        + " · SET \(clockString(block.setRest)) · ROUND \(clockString(block.roundRest))"
}

/// The block-editor summary: the numbers and the block's own rest total.
func blockSummary(_ block: WorkoutBlock) -> String {
    blockNumbers(block) + " · \(durationString(block.totalRest)) REST"
}

/// `2 ROUNDS · 1 SET EACH`, for the movement editor subtitle.
func blockRoundSetCopy(_ block: WorkoutBlock) -> String {
    plural(max(block.rounds, 1), "ROUND", "ROUNDS")
        + " · "
        + plural(max(block.setsPerRound, 1), "SET", "SETS")
        + " EACH"
}

// MARK: - Overflow-safe arithmetic

/// Counts are unbounded, so products and sums clamp at `Int.max` rather than
/// trapping.
func safeProduct(_ lhs: Int, _ rhs: Int) -> Int {
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    return overflow ? Int.max : max(0, result)
}

func safeSum(_ lhs: Int, _ rhs: Int) -> Int {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? Int.max : max(0, result)
}
