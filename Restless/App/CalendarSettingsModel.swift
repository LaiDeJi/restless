import Foundation
import Observation

/// The one observable copy of the calendar settings. The calendar edits it, and
/// the SESSIONS order reset writes the anchor through it, so both surfaces see
/// the same values without a relaunch.
@MainActor
@Observable
final class CalendarSettingsModel {
    private(set) var settings: CalendarSettings

    @ObservationIgnored private let store: CalendarSettingsStore
    @ObservationIgnored private let calendar: Calendar

    init(store: CalendarSettingsStore = CalendarSettingsStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        settings = store.load()
    }

    /// The rest gap, clamped to 0...6.
    func setRestGap(_ value: Int) {
        var copy = settings
        copy.setRestDaysBetween(value)
        commit(copy)
    }

    /// Returns false when the end is before the start.
    @discardableResult
    func addException(startDay: Date, endDay: Date, label: String) -> Bool {
        var copy = settings
        guard copy.addException(
            startDay: startDay,
            endDay: endDay,
            label: label,
            calendar: calendar
        ) else { return false }
        commit(copy)
        return true
    }

    /// Returns false for a weekday already closed.
    @discardableResult
    func addWeekdayException(_ weekday: Int, label: String) -> Bool {
        var copy = settings
        guard copy.addWeekdayException(weekday, label: label) else { return false }
        commit(copy)
        return true
    }

    func removeException(_ id: UUID) {
        var copy = settings
        copy.removeException(id)
        commit(copy)
    }

    func skip(_ day: Date, sessions: [RotationSession]) {
        var rotation = TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)
        rotation.skip(day)
        commit(rotation.settings)
    }

    func unskip(_ day: Date) {
        var copy = settings
        copy.unskip(day, calendar: calendar)
        commit(copy)
    }

    /// The selected date becomes slot 0. Only a date on or after today that is
    /// not closed is accepted; skips and per-date changes are cleared.
    @discardableResult
    func startNewRound(on day: Date, today: Date) -> Bool {
        var rotation = TrainingRotation(settings: settings, sessions: [], calendar: calendar)
        guard rotation.startNewRound(on: day, today: today) else { return false }
        commit(rotation.settings)
        return true
    }

    func setDayChange(day: Date, presetID: UUID) {
        var copy = settings
        copy.setDayChange(day: day, presetID: presetID, calendar: calendar)
        commit(copy)
    }

    func clearDayChange(day: Date) {
        var copy = settings
        copy.clearDayChange(day: day, calendar: calendar)
        commit(copy)
    }

    /// A reorder restarts the upcoming sequence at the first session of the new
    /// order, from the next unstarted day.
    func restartRotation(
        today: Date,
        recordedDays: Set<Date>,
        sessions: [RotationSession]
    ) {
        var rotation = TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)
        rotation.restartRotation(today: today, recordedDays: recordedDays)
        commit(rotation.settings)
    }

    /// Sets the anchor the first time the calendar is opened, and leaves it
    /// alone afterwards: today when it is open, else the next open day. It does
    /// not consult records; a record on the anchor is simply drawn over it.
    func initializeRotation(today: Date) {
        guard settings.rotationAnchor == nil else { return }
        var copy = settings
        var cursor = calendar.startOfDay(for: today)
        for _ in 0..<3_660 {
            if !copy.isClosed(cursor, calendar: calendar) {
                copy.setRotationAnchor(cursor, calendar: calendar)
                commit(copy)
                return
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return }
            cursor = calendar.startOfDay(for: next)
        }
    }

    private func commit(_ value: CalendarSettings) {
        settings = value
        store.save(value)
    }
}
