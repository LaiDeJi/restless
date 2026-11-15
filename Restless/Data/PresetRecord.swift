import Foundation
import SwiftData

@Model
final class PresetRecord {
    var id: UUID
    var name: String
    /// Ordered blocks as JSON.
    var blocksData: Data?
    var createdAt: Date
    /// Manual position in SESSIONS. Nil on a record whose index has not been
    /// assigned yet; `normalizeOrder` writes `0..<n` on the next launch.
    var sortIndex: Int?

    init(_ preset: WorkoutPreset) {
        id = preset.id
        name = preset.name
        blocksData = try? JSONEncoder().encode(preset.blocks)
        createdAt = .now
        sortIndex = nil
    }

    /// The ordered blocks. A record whose data cannot be read opens as one
    /// standard block.
    var blocks: [WorkoutBlock] {
        guard let blocksData,
              let decoded = try? JSONDecoder().decode([WorkoutBlock].self, from: blocksData)
        else { return [.fallback] }
        let clamped = decoded.compactMap { $0.clamped() }
        return clamped.isEmpty ? [.fallback] : clamped
    }

    var preset: WorkoutPreset {
        WorkoutPreset(id: id, name: name, blocks: blocks)
    }

    func apply(_ preset: WorkoutPreset) {
        name = preset.name
        blocksData = try? JSONEncoder().encode(preset.blocks)
    }
}

@MainActor
enum PresetRepository {
    @discardableResult
    static func seedIfNeeded(in context: ModelContext) -> WorkoutPreset {
        normalizeOrder(in: context)
        let records = fetchAll(context)
        if let active = records.first(where: { $0.id == ActivePresetStore.id }) {
            return active.preset
        }
        if let first = records.first {
            ActivePresetStore.id = first.id
            return first.preset
        }
        let record = PresetRecord(.seeded)
        record.sortIndex = 0
        context.insert(record)
        MovementRepository.seedIfNeeded(in: context)
        try? context.save()
        ActivePresetStore.id = record.id
        return record.preset
    }

    /// The manual order, with creation time as the fallback for a record whose
    /// index has not been assigned yet.
    static func ordered(_ records: [PresetRecord]) -> [PresetRecord] {
        records.sorted { lhs, rhs in
            let left = lhs.sortIndex ?? Int.max
            let right = rhs.sortIndex ?? Int.max
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// Rewrites the ordered rows to `0..<n` when any index is missing or the
    /// sequence has a gap.
    static func normalizeOrder(in context: ModelContext) {
        let ordered = ordered(fetchRaw(context))
        let needsRewrite = ordered.enumerated().contains { index, record in
            record.sortIndex != index
        }
        guard needsRewrite else { return }
        for (index, record) in ordered.enumerated() {
            record.sortIndex = index
        }
        try? context.save()
    }

    static func fetchAll(_ context: ModelContext) -> [PresetRecord] {
        ordered(fetchRaw(context))
    }

    private static func fetchRaw(_ context: ModelContext) -> [PresetRecord] {
        let descriptor = FetchDescriptor<PresetRecord>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
