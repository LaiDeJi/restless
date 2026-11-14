import Foundation
import Testing
@testable import Restless

private let calendar = TestCalendar.calendar

private func order(_ names: String...) -> [RotationSession] {
    names.map { RotationSession(id: UUID(), name: $0) }
}

private func dated(_ start: Date, _ end: Date, _ label: String = "") -> CalendarException {
    CalendarException(startDay: start, endDay: end, label: label, calendar: calendar)
}

private func weekday(_ number: Int, _ label: String = "") -> CalendarException {
    CalendarException(weekday: number, label: label)
}

private func rotation(
    _ sessions: [RotationSession],
    anchor: Date,
    restDaysBetween: Int = 0,
    exceptions: [CalendarException] = [],
    skips: [Date] = [],
    changes: [DayChange] = []
) -> TrainingRotation {
    var settings = CalendarSettings(
        restDaysBetween: restDaysBetween,
        exceptions: exceptions,
        skippedDays: Set(skips),
        dayChanges: changes,
        calendar: calendar
    )
    settings.setRotationAnchor(anchor, calendar: calendar)
    return TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)
}

private func store(
    _ settings: CalendarSettings,
    suite: String
) throws -> (CalendarSettingsStore, UserDefaults) {
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let store = CalendarSettingsStore(
        defaults: defaults,
        key: "calendar.test",
        calendar: calendar
    )
    store.save(settings)
    return (store, defaults)
}

// MARK: Cadence

@Test("Four consecutive days take the order at gap zero")
func fourDaysAtGapZero() {
    let plan = rotation(order("Chest", "Arms", "Legs"), anchor: TestCalendar.day(2026, 11, 9))

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 9))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12))?.name == "Chest")
}

@Test("A gap of one follows the whole round")
func gapOneFollowsTheRound() {
    let sessions = order("Chest", "Arms", "Legs")
    let plan = rotation(sessions, anchor: TestCalendar.day(2026, 11, 9), restDaysBetween: 1)
    let boundary = TestCalendar.day(2026, 11, 9)

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 9))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 14))?.name == "Arms")
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 11), boundary: boundary).session?.name == "Legs")
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 12), boundary: boundary) == .rest)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 13), boundary: boundary).session?.name == "Chest")
}

@Test("Two sessions with a gap of two take two rest days")
func twoSessionsTakeTwoRestDays() {
    let plan = rotation(
        order("Chest", "Arms"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 2
    )

    #expect(plan.roundIndex(for: TestCalendar.day(2026, 11, 9)) == 0)
    #expect(plan.dayInRound(for: TestCalendar.day(2026, 11, 9)) == 0)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 9))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Chest")
    #expect(plan.slotNumber(for: TestCalendar.day(2026, 11, 13)) == 2)
}

@Test("One session with a gap of one rests between repeats")
func oneSessionTakesTheGap() {
    let plan = rotation(
        order("Chest"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1
    )

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 9))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11))?.name == "Chest")
}

@Test("A single session repeats on every slot")
func oneSessionRepeats() {
    let plan = rotation(order("Chest"), anchor: TestCalendar.day(2026, 11, 9))

    for offset in 0..<7 {
        let day = calendar.date(byAdding: .day, value: offset, to: TestCalendar.day(2026, 11, 9))!
        #expect(plan.plan(for: day)?.name == "Chest")
    }
}

@Test("A closed slot drops its session and the next open day carries on")
func closedSlotDropsItsSession() {
    let sessions = order("Chest", "Arms", "Legs")
    let plan = rotation(
        sessions,
        anchor: TestCalendar.day(2026, 11, 9),
        exceptions: [dated(TestCalendar.day(2026, 11, 11), TestCalendar.day(2026, 11, 11), "Gym closed")]
    )

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11)) == nil)
    // The closed slot consumed Legs, so the next open day takes the following
    // session (Chest) rather than pausing the order.
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12))?.name == "Chest")
    #expect(plan.mark(
        for: TestCalendar.day(2026, 11, 11),
        boundary: TestCalendar.day(2026, 11, 9)
    ) == .closed("Gym closed"))
}

@Test("A closed session day keeps its place in the round")
func closedSessionDayKeepsItsPlace() {
    let sessions = order("Chest", "Arms", "Legs")
    let plan = rotation(
        sessions,
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1,
        exceptions: [dated(TestCalendar.day(2026, 11, 10), TestCalendar.day(2026, 11, 10), "Trip")]
    )

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 10)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Chest")
    #expect(plan.mark(
        for: TestCalendar.day(2026, 11, 10),
        boundary: TestCalendar.day(2026, 11, 9)
    ) == .closed("Trip"))
}

@Test("A weekday closure closes every week")
func weekdayClosureRecurs() {
    let sessions = order("Chest", "Arms", "Legs")
    let plan = rotation(
        sessions,
        anchor: TestCalendar.day(2026, 11, 9),
        exceptions: [weekday(CalendarSettings.sunday)]
    )

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 15)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 16))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 22)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 23))?.name == "Legs")
}

// MARK: Marks

@Test("Marks follow exception, skip, boundary, rest, plan")
func markPrecedence() {
    let skipExceptionDay = TestCalendar.day(2026, 11, 10)
    let plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1,
        exceptions: [dated(skipExceptionDay, skipExceptionDay, "Trip")],
        skips: [skipExceptionDay, TestCalendar.day(2026, 11, 14)]
    )
    let boundary = TestCalendar.day(2026, 11, 9)

    #expect(plan.mark(for: skipExceptionDay, boundary: boundary) == .closed("Trip"))
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 11), boundary: boundary).session?.name == "Legs")
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 12), boundary: boundary) == .rest)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 14), boundary: boundary) == .skipped)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 9), boundary: boundary).session?.name == "Chest")
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 13), boundary: boundary).session?.name == "Chest")
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 8), boundary: boundary) == .none)
}

@Test("No plan or rest word is drawn before the boundary")
func noPlanOrRestBeforeBoundary() {
    let plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1,
        exceptions: [dated(TestCalendar.day(2026, 11, 4), TestCalendar.day(2026, 11, 4), "Closed")]
    )
    let boundary = TestCalendar.day(2026, 11, 13)

    #expect(plan.mark(for: TestCalendar.day(2026, 11, 11), boundary: boundary) == .none)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 8), boundary: boundary) == .none)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 4), boundary: boundary) == .closed("Closed"))
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 12), boundary: boundary) == .none)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 16), boundary: boundary) == .rest)
    #expect(plan.mark(for: TestCalendar.day(2026, 11, 14), boundary: boundary).session?.name == "Arms")
    #expect(plan.mark(for: boundary, boundary: boundary).session?.name == "Chest")
}

@Test("A skipped slot is not the boundary")
func skippedSlotIsNotTheBoundary() {
    let today = TestCalendar.day(2026, 11, 9)
    let plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: today,
        skips: [today]
    )

    #expect(plan.plan(for: today) == nil)
    #expect(plan.nextUnstartedDay(today: today) == TestCalendar.day(2026, 11, 10))
}

@Test("A recorded slot is not the boundary")
func recordedSlotIsNotTheBoundary() {
    let today = TestCalendar.day(2026, 11, 9)
    let plan = rotation(order("Chest", "Arms", "Legs"), anchor: today)

    #expect(plan.nextUnstartedDay(
        today: today,
        recordedDays: [today]
    ) == TestCalendar.day(2026, 11, 10))
    #expect(plan.nextUnstartedDay(
        today: today,
        recordedDays: [today, TestCalendar.day(2026, 11, 10)]
    ) == TestCalendar.day(2026, 11, 11))
}

// MARK: New round

@Test("A new round starts on a rest day")
func newRoundOnRestDay() {
    var plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1
    )
    let restDay = TestCalendar.day(2026, 11, 12)

    #expect(plan.plan(for: restDay) == nil)
    let started = plan.startNewRound(on: restDay, today: restDay)
    #expect(started)
    #expect(plan.settings.rotationAnchor == restDay)
    #expect(plan.plan(for: restDay)?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 14))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 15)) == nil)
}

@Test("A new round re-phases a planned day")
func newRoundRePhases() {
    var plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 11),
        restDaysBetween: 1
    )
    let thursday = TestCalendar.day(2026, 11, 13)
    #expect(plan.plan(for: thursday)?.name == "Legs")

    let started = plan.startNewRound(on: thursday, today: thursday)
    #expect(started)
    #expect(plan.plan(for: thursday)?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 14))?.name == "Arms")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 15))?.name == "Legs")
}

@Test("A closed or past date refuses a new round")
func newRoundRefused() {
    var plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 11),
        exceptions: [dated(TestCalendar.day(2026, 11, 15), TestCalendar.day(2026, 11, 15), "Closed")]
    )
    let anchor = plan.settings.rotationAnchor

    let closedRefused = plan.startNewRound(on: TestCalendar.day(2026, 11, 15), today: TestCalendar.day(2026, 11, 12))
    let pastRefused = plan.startNewRound(on: TestCalendar.day(2026, 11, 8), today: TestCalendar.day(2026, 11, 12))
    #expect(closedRefused == false)
    #expect(pastRefused == false)
    #expect(plan.settings.rotationAnchor == anchor)
}

@Test("A new round clears skips and changes")
func newRoundClearsMarks() {
    let changeDay = TestCalendar.day(2026, 11, 13)
    var plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 11),
        restDaysBetween: 1,
        skips: [TestCalendar.day(2026, 11, 11)],
        changes: [DayChange(day: changeDay, presetID: UUID(), calendar: calendar)]
    )
    let restDay = TestCalendar.day(2026, 11, 14)

    let started = plan.startNewRound(on: restDay, today: restDay)
    #expect(started)
    #expect(plan.settings.skippedDays.isEmpty)
    #expect(plan.settings.dayChanges.isEmpty)
}

// MARK: Skip

@Test("Skipping keeps the next session")
func skipKeepsNextSession() {
    var plan = rotation(order("Chest", "Arms", "Legs"), anchor: TestCalendar.day(2026, 11, 11))
    let skippedDay = TestCalendar.day(2026, 11, 12)

    #expect(plan.plan(for: skippedDay)?.name == "Arms")
    plan.skip(skippedDay)
    #expect(plan.plan(for: skippedDay) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 14))?.name == "Chest")

    plan.unskip(skippedDay)
    #expect(plan.plan(for: skippedDay)?.name == "Arms")
}

@Test("A skipped session day keeps its place in the round")
func skippedSessionDayKeepsItsPlace() {
    var plan = rotation(
        order("Chest", "Arms", "Legs"),
        anchor: TestCalendar.day(2026, 11, 9),
        restDaysBetween: 1
    )
    let tuesday = TestCalendar.day(2026, 11, 10)

    #expect(plan.plan(for: tuesday)?.name == "Arms")
    plan.skip(tuesday)
    #expect(plan.plan(for: tuesday) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 11))?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 12)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Chest")

    plan.unskip(tuesday)
    #expect(plan.plan(for: tuesday)?.name == "Arms")
}

@Test("A skip persists across a store round trip")
func skipPersists() throws {
    var plan = rotation(order("Chest", "Arms", "Legs"), anchor: TestCalendar.day(2026, 11, 11))
    let skippedDay = TestCalendar.day(2026, 11, 12)
    plan.skip(skippedDay)

    let suite = "restless.rotation.skip.\(UUID().uuidString)"
    let (store, defaults) = try store(plan.settings, suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let loaded = store.load()
    #expect(loaded.isSkipped(skippedDay, calendar: calendar))
    let reloaded = TrainingRotation(settings: loaded, sessions: plan.sessions, calendar: calendar)
    #expect(reloaded.plan(for: skippedDay) == nil)
    #expect(reloaded.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Legs")
}

// MARK: Date change

@Test("A date change replaces only that date")
func changeReplacesOnlyTheDate() {
    let sessions = order("Chest", "Arms", "Legs")
    let saturday = TestCalendar.day(2026, 11, 14)
    let sunday = TestCalendar.day(2026, 11, 15)
    var settings = CalendarSettings(restDaysBetween: 2, calendar: calendar)
    settings.setRotationAnchor(TestCalendar.day(2026, 11, 13), calendar: calendar)
    settings.setDayChange(day: saturday, presetID: sessions[0].id, calendar: calendar)
    let plan = TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)

    #expect(plan.scheduledPlan(for: saturday)?.name == "Arms")
    #expect(plan.plan(for: saturday)?.name == "Chest")
    #expect(plan.isChanged(saturday))
    // The changed day still consumed Arms, so Sunday keeps the schedule's Legs.
    #expect(plan.plan(for: sunday)?.name == "Legs")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 16)) == nil)
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 18))?.name == "Chest")

    var cleared = settings
    cleared.clearDayChange(day: saturday, calendar: calendar)
    let back = TrainingRotation(settings: cleared, sessions: sessions, calendar: calendar)
    #expect(back.plan(for: saturday)?.name == "Arms")
    #expect(back.isChanged(saturday) == false)
}

@Test("A deleted preset falls back to the schedule")
func deletedPresetFallsBack() {
    let sessions = order("Chest", "Arms", "Legs")
    let saturday = TestCalendar.day(2026, 11, 14)
    var settings = CalendarSettings(restDaysBetween: 2, calendar: calendar)
    settings.setRotationAnchor(TestCalendar.day(2026, 11, 13), calendar: calendar)
    settings.setDayChange(day: saturday, presetID: UUID(), calendar: calendar)
    let plan = TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)

    #expect(plan.plan(for: saturday)?.name == "Arms")
    #expect(plan.isChanged(saturday) == false)
}

@Test("A new round clears a date change")
func newRoundClearsChange() {
    let sessions = order("Chest", "Arms", "Legs")
    let changedDay = TestCalendar.day(2026, 11, 14)
    var settings = CalendarSettings(calendar: calendar)
    settings.setRotationAnchor(TestCalendar.day(2026, 11, 12), calendar: calendar)
    settings.setDayChange(day: changedDay, presetID: sessions[0].id, calendar: calendar)
    var plan = TrainingRotation(settings: settings, sessions: sessions, calendar: calendar)
    #expect(plan.plan(for: changedDay)?.name == "Chest")

    let started = plan.startNewRound(on: TestCalendar.day(2026, 11, 12), today: TestCalendar.day(2026, 11, 12))
    #expect(started)
    #expect(plan.settings.dayChanges.isEmpty)
    #expect(plan.plan(for: changedDay)?.name == "Legs")
}

// MARK: Reorder and empty order

@Test("A reorder restarts at the next unstarted slot")
func reorderRestartsSequence() {
    var plan = rotation(order("Chest", "Arms", "Legs"), anchor: TestCalendar.day(2026, 11, 9))
    let today = TestCalendar.day(2026, 11, 12)

    plan.restartRotation(today: today, recordedDays: [today])
    #expect(plan.settings.rotationAnchor == TestCalendar.day(2026, 11, 13))
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 13))?.name == "Chest")
    #expect(plan.plan(for: TestCalendar.day(2026, 11, 14))?.name == "Arms")
}

@Test("An empty order draws no plan")
func emptyOrderDrawsNothing() {
    let plan = TrainingRotation(
        settings: {
            var settings = CalendarSettings(calendar: calendar)
            settings.setRotationAnchor(TestCalendar.day(2026, 11, 9), calendar: calendar)
            return settings
        }(),
        sessions: [],
        calendar: calendar
    )

    #expect(plan.plan(for: TestCalendar.day(2026, 11, 9)) == nil)
    #expect(plan.scheduledPlan(for: TestCalendar.day(2026, 11, 9)) == nil)
    #expect(plan.isSessionSlot(TestCalendar.day(2026, 11, 9)) == false)
    #expect(plan.roundIndex(for: TestCalendar.day(2026, 11, 9)) == nil)
    #expect(plan.mark(
        for: TestCalendar.day(2026, 11, 9),
        boundary: TestCalendar.day(2026, 11, 9)
    ) == .none)
}
