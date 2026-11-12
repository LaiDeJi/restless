import Foundation
import SwiftData

/// A durable record of one run: the plan snapshot it started with, how far it
/// got, and when it last changed. Later edits and deletes of the source session
/// never reach it.
@Model
final class WorkoutRecord {
    /// `presetID|startedAt`, unique, so the island refresh path is idempotent.
    @Attribute(.unique) var runKey: String
    var presetID: UUID
    var sessionName: String
    /// The run's own `[WorkoutBlock]` snapshot as JSON.
    var blocksData: Data?
    var totalSets: Int
    var startedAt: Date
    /// The local start of day of `startedAt`, stored so a timezone change does
    /// not move a run to another date.
    var startDay: Date
    var lastActivityAt: Date
    var finishedAt: Date?
    var doneSets: Int
    var phaseRaw: String

    init(
        snapshot: SessionSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) {
        runKey = Self.runKey(for: snapshot)
        presetID = snapshot.preset.id
        sessionName = snapshot.preset.name
        blocksData = try? JSONEncoder().encode(snapshot.preset.blocks)
        totalSets = snapshot.totalSets
        startedAt = snapshot.startedAt
        startDay = calendar.startOfDay(for: snapshot.startedAt)
        lastActivityAt = now
        finishedAt = snapshot.phase == .done ? now : nil
        doneSets = snapshot.doneSets
        phaseRaw = snapshot.phase.rawValue
    }

    static func runKey(for snapshot: SessionSnapshot) -> String {
        "\(snapshot.preset.id.uuidString)|\(snapshot.startedAt.timeIntervalSinceReferenceDate)"
    }

    /// The decoded plan. A snapshot that cannot be read falls back to an empty
    /// plan, which `preset` turns into the standard block.
    var blocks: [WorkoutBlock] {
        guard let blocksData,
              let stored = try? JSONDecoder().decode([StoredBlock].self, from: blocksData)
        else { return [] }
        return stored.flatMap { $0.migratedBlocks() }.compactMap { $0.clamped() }
    }

    /// The day sheet's read-only session, built from the record alone.
    var preset: WorkoutPreset {
        WorkoutPreset(id: presetID, name: sessionName, blocks: blocks)
    }

    var phase: SessionPhase {
        SessionPhase(rawValue: phaseRaw) ?? .ready
    }

    var isFinished: Bool { phase == .done }

    /// Copies the run's progress. Returns false when nothing a reader sees
    /// changed, so a repeated path does not save the context again.
    @discardableResult
    func apply(_ snapshot: SessionSnapshot, now: Date) -> Bool {
        let phase = snapshot.phase
        let finish = phase == .done ? (finishedAt ?? now) : finishedAt
        let changed = doneSets != snapshot.doneSets
            || phaseRaw != phase.rawValue
            || finishedAt != finish
        guard changed else { return false }
        doneSets = snapshot.doneSets
        phaseRaw = phase.rawValue
        lastActivityAt = now
        finishedAt = finish
        return true
    }
}
