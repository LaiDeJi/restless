import Foundation
import SwiftData

/// The SwiftData implementation of the engine's history hook. It upserts one
/// record per run key and saves only when a recorded value changed.
@MainActor
final class WorkoutHistoryStore: WorkoutHistoryRecording {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Creates the record with the first completed set, then updates the same
    /// record for every later state change. A gate or a paused start with no
    /// completed set creates nothing.
    func record(_ snapshot: SessionSnapshot, now: Date) {
        let runKey = WorkoutRecord.runKey(for: snapshot)
        if let existing = WorkoutRepository.record(runKey: runKey, in: context) {
            guard existing.apply(snapshot, now: now) else { return }
        } else {
            guard snapshot.doneSets > 0 else { return }
            let record = WorkoutRecord(snapshot: snapshot, now: now, calendar: calendar)
            context.insert(record)
        }
        try? context.save()
    }

    func records(on day: Date) -> [WorkoutRecord] {
        WorkoutRepository.records(on: day, in: context, calendar: calendar)
    }

    func records(from start: Date, to end: Date) -> [WorkoutRecord] {
        WorkoutRepository.records(from: start, to: end, in: context)
    }

    /// Whether the day already holds a record, used by the next-unstarted
    /// boundary before the calendar has loaded a month.
    func hasRecord(on day: Date) -> Bool {
        !records(on: day).isEmpty
    }

    func delete(runKey: String) {
        WorkoutRepository.delete(runKey: runKey, in: context)
    }
}
