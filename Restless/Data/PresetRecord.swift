import Foundation
import SwiftData

@Model
final class PresetRecord {
    var id: UUID
    var name: String
    // Legacy single-part columns, kept for reading old stores and rollback.
    var rounds: Int
    var setsPerRound: Int
    var setRest: Int
    var roundRest: Int
    // Ordered parts as JSON, written by the part-based version. Read-only now.
    var partsData: Data?
    // Ordered blocks as JSON. Nil means this record predates blocks.
    var blocksData: Data?
    var createdAt: Date

    init(_ preset: WorkoutPreset) {
        let firstBlock = preset.blocks.first ?? .fallback
        id = preset.id
        name = preset.name
        (rounds, setsPerRound) = Self.legacyShape(of: firstBlock)
        setRest = firstBlock.setRest
        roundRest = firstBlock.roundRest
        blocksData = try? JSONEncoder().encode(preset.blocks)
        partsData = nil
        createdAt = .now
    }

    /// The ordered blocks. A record without `blocksData` reads `partsData` as
    /// one block per part, or the legacy columns as one block.
    var blocks: [WorkoutBlock] {
        if let data = blocksData,
           let decoded = try? JSONDecoder().decode([StoredBlock].self, from: data) {
            let migrated = decoded.flatMap { $0.migratedBlocks() }
            let clamped = migrated.compactMap { $0.clamped() }
            if !clamped.isEmpty { return clamped }
        }
        if let data = partsData,
           let decoded = try? JSONDecoder().decode([WorkoutPart].self, from: data),
           !decoded.isEmpty {
            return decoded.map(WorkoutBlock.init(legacyPart:))
        }
        let part = WorkoutPart(
            id: id,
            name: name,
            rounds: rounds,
            setsPerRound: setsPerRound,
            setRest: setRest,
            roundRest: roundRest
        )
        return [WorkoutBlock(legacyPart: part)]
    }

    var preset: WorkoutPreset {
        WorkoutPreset(id: id, name: name, blocks: blocks)
    }

    func apply(_ preset: WorkoutPreset) {
        let firstBlock = preset.blocks.first ?? .fallback
        name = preset.name
        (rounds, setsPerRound) = Self.legacyShape(of: firstBlock)
        setRest = firstBlock.setRest
        roundRest = firstBlock.roundRest
        blocksData = try? JSONEncoder().encode(preset.blocks)
        // The old build reads these columns when partsData is nil. Never leave
        // stale part JSON behind for it.
        partsData = nil
    }

    /// The first block flattened into the old part columns: rounds, and sets per
    /// round across every movement, so an older build sees the same total sets.
    private static func legacyShape(of block: WorkoutBlock) -> (rounds: Int, setsPerRound: Int) {
        (
            max(block.rounds, 1),
            safeProduct(max(block.setsPerRound, 1), max(block.movements.count, 1))
        )
    }
}

@MainActor
enum PresetRepository {
    @discardableResult
    static func seedIfNeeded(in context: ModelContext) -> WorkoutPreset {
        let records = fetchAll(context)
        if let active = records.first(where: { $0.id == ActivePresetStore.id }) {
            MovementRepository.ensureLibrary(for: records, in: context)
            try? context.save()
            return active.preset
        }
        if let first = records.first {
            ActivePresetStore.id = first.id
            MovementRepository.ensureLibrary(for: records, in: context)
            try? context.save()
            return first.preset
        }
        let record = PresetRecord(.chest)
        context.insert(record)
        MovementRepository.seedIfNeeded(in: context)
        try? context.save()
        ActivePresetStore.id = record.id
        return record.preset
    }

    static func fetchAll(_ context: ModelContext) -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
