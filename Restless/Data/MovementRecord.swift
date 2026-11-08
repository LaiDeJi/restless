import Foundation
import SwiftData

/// A reusable movement in the library. The legacy muscle-group and profile
/// columns are kept for store compatibility; only the name is used.
@Model
final class MovementRecord {
    var id: UUID
    var name: String
    var group: String
    var axisRaw: String?
    var rise: Double?
    var fall: Double?
    var minPeriod: Double?
    var defaultConditionRaw: String
    var defaultTarget: Int?
    var createdAt: Date

    init(_ movement: Movement) {
        id = movement.id
        name = movement.name
        group = ""
        axisRaw = movement.profile?.axis.rawValue
        rise = movement.profile?.rise
        fall = movement.profile?.fall
        minPeriod = movement.profile?.minPeriod
        defaultConditionRaw = EndCondition.manual.rawValue
        defaultTarget = nil
        createdAt = .now
    }

    var movement: Movement {
        let profile: MovementProfile? = {
            guard let axisRaw,
                  let axis = MovementAxis(rawValue: axisRaw),
                  let rise,
                  let fall,
                  let minPeriod else { return nil }
            return MovementProfile(axis: axis, rise: rise, fall: fall, minPeriod: minPeriod).clamped()
        }()
        return Movement(
            id: id,
            name: name,
            profile: profile
        ).clamped()
    }

    func apply(_ movement: Movement) {
        let clean = movement.clamped()
        name = clean.name
        axisRaw = clean.profile?.axis.rawValue
        rise = clean.profile?.rise
        fall = clean.profile?.fall
        minPeriod = clean.profile?.minPeriod
    }
}

enum MovementDeleteError: Error, Equatable {
    case inUse([String])
}

@MainActor
enum MovementRepository {
    @discardableResult
    static func seedIfNeeded(in context: ModelContext) -> [Movement] {
        let records = fetchAll(context)
        guard records.isEmpty else { return records.map(\.movement) }
        let record = MovementRecord(.chest)
        context.insert(record)
        try? context.save()
        return [.chest]
    }

    static func fetchAll(_ context: ModelContext) -> [MovementRecord] {
        let descriptor = FetchDescriptor<MovementRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func find(_ id: UUID, in context: ModelContext) -> MovementRecord? {
        fetchAll(context).first { $0.id == id }
    }

    /// Names for the Live Activity attributes, which carry no library.
    static func names(in context: ModelContext) -> [UUID: String] {
        Dictionary(fetchAll(context).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// Creates a library entry for every block movement that has no record yet.
    /// This is the bridge for plans migrated from parts, whose movements carry
    /// only the old part name.
    static func ensureLibrary(for presets: [PresetRecord], in context: ModelContext) {
        var known = Set(fetchAll(context).map(\.id))
        for preset in presets {
            for block in preset.blocks {
                for blockMovement in block.movements where !known.contains(blockMovement.movementId) {
                    let movement = Movement(
                        id: blockMovement.movementId,
                        name: block.name
                    ).clamped()
                    context.insert(MovementRecord(movement))
                    known.insert(movement.id)
                }
            }
        }
    }

    @discardableResult
    static func add(_ movement: Movement, in context: ModelContext) -> Movement {
        let clean = movement.clamped()
        if let existing = find(clean.id, in: context) {
            existing.apply(clean)
        } else {
            context.insert(MovementRecord(clean))
        }
        try? context.save()
        return clean
    }

    /// Creates a library movement from a typed name, or returns the existing
    /// one whose name matches ignoring case. An empty name creates nothing.
    @discardableResult
    static func addOrReuse(name: String, in context: ModelContext) -> Movement? {
        let clean = WorkoutPreset.clampedName(name, fallback: "")
        guard !clean.isEmpty else { return nil }
        if let existing = fetchAll(context).first(where: {
            $0.name.caseInsensitiveCompare(clean) == .orderedSame
        }) {
            return existing.movement
        }
        let movement = Movement(name: clean)
        context.insert(MovementRecord(movement))
        try? context.save()
        return movement
    }

    @discardableResult
    static func rename(_ id: UUID, to name: String, in context: ModelContext) -> Movement? {
        guard let record = find(id, in: context) else { return nil }
        var movement = record.movement
        movement.name = WorkoutPreset.clampedName(name, fallback: "Untitled movement")
        record.apply(movement)
        try? context.save()
        return record.movement
    }

    @discardableResult
    static func reRecord(
        _ id: UUID,
        profile: MovementProfile,
        in context: ModelContext
    ) -> Movement? {
        guard let record = find(id, in: context) else { return nil }
        var movement = record.movement
        movement.profile = profile.clamped()
        record.apply(movement)
        try? context.save()
        return record.movement
    }

    /// The sessions that reference a movement. Empty means it is unused.
    static func usage(_ id: UUID, in context: ModelContext) -> [String] {
        var names: [String] = []
        for preset in PresetRepository.fetchAll(context) {
            let used = preset.blocks.contains { block in
                block.movements.contains { $0.movementId == id }
            }
            if used, !names.contains(preset.name) {
                names.append(preset.name)
            }
        }
        return names
    }

    static func delete(_ id: UUID, in context: ModelContext) throws {
        let used = usage(id, in: context)
        guard used.isEmpty else { throw MovementDeleteError.inUse(used) }
        guard let record = find(id, in: context) else { return }
        context.delete(record)
        try? context.save()
    }
}
