import Foundation

/// Date and settings copy shared by the calendar screen, its day sheet, and the
/// settings editors, so the three cannot format a range differently.
enum CalendarCopy {
    static func weekdayName(_ weekday: Int, calendar: Calendar = .current) -> String {
        let index = (weekday - 1 + 7) % 7
        guard calendar.shortWeekdaySymbols.indices.contains(index) else { return "" }
        return calendar.shortWeekdaySymbols[index].uppercased()
    }

    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated)).uppercased()
    }

    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased()
    }

    /// A dated range, or the weekday every week.
    static func exceptionWhen(_ exception: CalendarException, calendar: Calendar = .current) -> String {
        if let weekday = exception.weekday {
            let names = calendar.weekdaySymbols
            let index = (weekday - 1 + 7) % 7
            guard names.indices.contains(index) else { return "" }
            return "EVERY \(names[index].uppercased())"
        }
        guard let start = exception.startDay, let end = exception.endDay else { return "" }
        let first = dayMonth(start)
        if calendar.isDate(start, inSameDayAs: end) { return first }
        return "\(first)–\(dayMonth(end))"
    }

    static func exceptionSummary(_ exception: CalendarException, calendar: Calendar = .current) -> String {
        let label = exception.label.isEmpty ? "CLOSED" : exception.label.uppercased()
        return "\(label) · \(exceptionWhen(exception, calendar: calendar))"
    }

    static func exceptionsSummary(
        _ exceptions: [CalendarException],
        calendar: Calendar = .current
    ) -> String {
        guard let first = exceptions.first else { return "NONE" }
        var text = exceptionSummary(first, calendar: calendar)
        if exceptions.count > 1 { text += " +\(exceptions.count - 1)" }
        return text
    }

    /// The gap's own words on the calendar row. The number lives in the stepper.
    static let restGapRowValue = "BETWEEN SESSIONS"

    static func gapSummary(_ gap: Int) -> String {
        guard gap > 0 else { return "SESSIONS EVERY DAY" }
        return "\(plural(gap, "REST DAY", "REST DAYS")) BETWEEN SESSIONS"
    }

    static func blockRestSummary(_ block: WorkoutBlock) -> String {
        "\(durationString(block.setRest)) SET REST · \(durationString(block.roundRest)) ROUND REST"
    }

    static func recordWhen(_ record: WorkoutRecord) -> String {
        let start = record.startedAt
            .formatted(date: .omitted, time: .shortened)
            .uppercased()
        guard let finishedAt = record.finishedAt else {
            return "STARTED \(start) · NOT FINISHED"
        }
        let minutes = max(0, Int(finishedAt.timeIntervalSince(record.startedAt) / 60))
        return "STARTED \(start) · \(plural(minutes, "MINUTE", "MINUTES"))"
    }

    static func nextSummary(_ session: RotationSession, day: Date, calendar: Calendar = .current) -> String {
        let when: String
        if calendar.isDateInToday(day) {
            when = "TODAY"
        } else if calendar.isDateInTomorrow(day) {
            when = "TOMORROW"
        } else {
            when = day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased()
        }
        return "\(session.name.uppercased()) · \(when)"
    }

    static func sessionSummary(_ preset: WorkoutPreset) -> String {
        "\(plural(preset.blocks.count, "BLOCK", "BLOCKS")) · \(plural(preset.totalSets, "SET", "SETS")) · \(durationString(preset.totalRest)) TOTAL REST"
    }
}
