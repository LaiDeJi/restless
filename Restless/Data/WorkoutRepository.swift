import Foundation
import SwiftData

/// The engine's history hook. The implementation owns SwiftData; the engine
/// only knows that a snapshot and a time can be recorded.
@MainActor
protocol WorkoutHistoryRecording: AnyObject {
    func record(_ snapshot: SessionSnapshot, now: Date)
}

/// Reads records by local day. Shared by the calendar grid, the day sheet, and
/// the order-reset path, so they cannot disagree about what a day contains.
@MainActor
enum WorkoutRepository {
    static func fetchAll(in context: ModelContext) -> [WorkoutRecord] {
        let descriptor = FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.startedAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func records(
        on day: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [WorkoutRecord] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return records(from: start, to: end, in: context)
    }

    /// Records whose stored start day is in `[start, end)`.
    static func records(
        from start: Date,
        to end: Date,
        in context: ModelContext
    ) -> [WorkoutRecord] {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { record in
                record.startDay >= start && record.startDay < end
            },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The local days that hold at least one record, in the given range.
    static func recordedDays(
        from start: Date,
        to end: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(records(from: start, to: end, in: context).map {
            calendar.startOfDay(for: $0.startDay)
        })
    }

    static func record(runKey: String, in context: ModelContext) -> WorkoutRecord? {
        fetchAll(in: context).first { $0.runKey == runKey }
    }

    /// Deletes one record. The session, the rotation, and every other record
    /// are untouched.
    static func delete(runKey: String, in context: ModelContext) {
        guard let record = record(runKey: runKey, in: context) else { return }
        context.delete(record)
        try? context.save()
    }
}
