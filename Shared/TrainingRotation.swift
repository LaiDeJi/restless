import Foundation

/// One entry of the ordered rotation. Only an id and a name, so `Shared` stays
/// SwiftData-free and `PresetRepository.ordered` remains the one ordering.
struct RotationSession: Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
}

/// What a day draws before a record replaces it.
enum TrainingDayMark: Hashable, Sendable {
    case none
    case planned(RotationSession)
    case rest
    case skipped
    case closed(String)

    var session: RotationSession? {
        if case .planned(let session) = self { return session }
        return nil
    }
}

/// Projects the persisted session order onto a fixed cadence:
///
/// ```
/// offset = whole local days from the anchor
/// slot   = offset % (restGap + 1) == 0
/// index  = offset / (restGap + 1) % sessions.count
/// ```
///
/// A slot is a session day unless an exception closes it or the user skipped
/// it. Because the index comes from the offset, a closed or skipped slot keeps
/// its index: the session it would have taken is dropped for that lap, and no
/// other date moves. A per-date change replaces only the session drawn on that
/// date; the slot still consumes the scheduled session.
struct TrainingRotation: Sendable {
    var settings: CalendarSettings
    let sessions: [RotationSession]
    var calendar: Calendar

    init(
        settings: CalendarSettings,
        sessions: [RotationSession],
        calendar: Calendar = .current
    ) {
        self.settings = settings
        self.sessions = sessions
        self.calendar = calendar
    }

    private var step: Int { settings.restDaysBetween + 1 }

    /// Whole local days from one date to another, DST-safe.
    func dayOffset(from anchor: Date, to day: Date) -> Int {
        let start = calendar.startOfDay(for: anchor)
        let end = calendar.startOfDay(for: day)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// A day whose offset from the anchor is a multiple of the gap plus one.
    func isSessionSlot(_ day: Date) -> Bool {
        guard let anchor = settings.rotationAnchor else { return false }
        let offset = dayOffset(from: anchor, to: day)
        guard offset >= 0 else { return false }
        return offset % step == 0
    }

    /// The slot number from the anchor, or nil when the day is not a slot.
    func slotNumber(for day: Date) -> Int? {
        guard let anchor = settings.rotationAnchor else { return nil }
        let offset = dayOffset(from: anchor, to: day)
        guard offset >= 0, offset % step == 0 else { return nil }
        return offset / step
    }

    /// The schedule's session on a slot, before a closure, a skip or a change.
    func scheduledPlan(for day: Date) -> RotationSession? {
        guard !sessions.isEmpty, let slot = slotNumber(for: day) else { return nil }
        return sessions[slot % sessions.count]
    }

    /// The chosen session for a date, when the preset still exists. A deleted
    /// preset leaves the entry inert and the schedule shows through.
    func change(for day: Date) -> RotationSession? {
        guard let change = settings.change(for: day, calendar: calendar) else { return nil }
        return sessions.first { $0.id == change.presetID }
    }

    /// True only while the chosen preset still exists.
    func isChanged(_ day: Date) -> Bool {
        change(for: day) != nil
    }

    /// The scheduled session with the date change resolved, ignoring a skip.
    /// A skipped day's sheet still names the session it is skipping.
    func plannedSession(for day: Date) -> RotationSession? {
        let target = calendar.startOfDay(for: day)
        guard let scheduled = scheduledPlan(for: target) else { return nil }
        return change(for: target) ?? scheduled
    }

    /// The session planned on `day`, or nil before the anchor, on a rest day,
    /// on a closed or skipped day, or when the order is empty.
    func plan(for day: Date) -> RotationSession? {
        let target = calendar.startOfDay(for: day)
        guard !settings.isClosed(target, calendar: calendar) else { return nil }
        guard !settings.isSkipped(target, calendar: calendar) else { return nil }
        return plannedSession(for: target)
    }

    /// The mark a month cell shows before a record is considered:
    /// exception, then skip, then the boundary, then rest, then plan.
    func mark(for day: Date, boundary: Date?) -> TrainingDayMark {
        let target = calendar.startOfDay(for: day)
        if let exception = settings.exception(containing: target, calendar: calendar) {
            return .closed(exception.label)
        }
        if settings.isSkipped(target, calendar: calendar) { return .skipped }
        guard let boundary else { return .none }
        guard target >= calendar.startOfDay(for: boundary) else { return .none }
        guard isSessionSlot(target) else { return .rest }
        guard let plan = plan(for: target) else { return .none }
        return .planned(plan)
    }

    /// The first open slot at or after today with no record and no skip. Rest
    /// days, closures, skips and recorded slots are passed over.
    func nextUnstartedDay(today: Date, recordedDays: Set<Date> = []) -> Date? {
        let start = calendar.startOfDay(for: today)
        let recorded = Set(recordedDays.map { calendar.startOfDay(for: $0) })
        for offset in 0..<3_660 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let target = calendar.startOfDay(for: candidate)
            if settings.isClosed(target, calendar: calendar) { continue }
            if settings.isSkipped(target, calendar: calendar) { continue }
            if recorded.contains(target) { continue }
            if isSessionSlot(target) { return target }
        }
        return nil
    }

    // MARK: Edits

    /// A reorder restarts the upcoming sequence at the first session.
    mutating func restartRotation(today: Date, recordedDays: Set<Date> = []) {
        settings.setRotationAnchor(
            nextUnstartedDay(today: today, recordedDays: recordedDays),
            calendar: calendar
        )
    }

    /// The selected date becomes slot 0, so every upcoming slot re-phases
    /// around it. A closed or past date is refused. Records and a running
    /// session are untouched.
    @discardableResult
    mutating func startNewRound(on day: Date, today: Date) -> Bool {
        let target = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: today)
        guard target >= start else { return false }
        guard !settings.isClosed(target, calendar: calendar) else { return false }
        settings.setRotationAnchor(target, calendar: calendar)
        settings.clearSkips()
        settings.clearDayChanges()
        return true
    }

    /// Only a planned session can be skipped; the day keeps its slot.
    mutating func skip(_ day: Date) {
        let target = calendar.startOfDay(for: day)
        guard plan(for: target) != nil else { return }
        settings.skip(target, calendar: calendar)
    }

    mutating func unskip(_ day: Date) {
        settings.unskip(day, calendar: calendar)
    }
}
