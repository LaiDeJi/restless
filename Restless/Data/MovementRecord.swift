import Foundation
import SwiftData

/// A reusable movement in the library: a name. The end condition and target
/// belong to a block that uses it, not to the library entry.
@Model
final class MovementRecord {
    var id: UUID
    var name: String
    var createdAt: Date

    init(_ movement: Movement) {
        id = movement.id
        name = movement.name
        createdAt = .now
    }

    var movement: Movement {
        Movement(
            id: id,
            name: name
        ).clamped()
    }

    func apply(_ movement: Movement) {
        let clean = movement.clamped()
        name = clean.name
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
        let movement = Movement.seeded
        context.insert(MovementRecord(movement))
        try? context.save()
        return [movement]
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
