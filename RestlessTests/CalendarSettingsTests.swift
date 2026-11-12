import Foundation
import Testing
@testable import Restless

private let calendar = TestCalendar.calendar

private func dated(_ start: Date, _ end: Date, _ label: String = "") -> CalendarException {
    CalendarException(startDay: start, endDay: end, label: label, calendar: calendar)
}

private func weekday(_ number: Int, _ label: String = "") -> CalendarException {
    CalendarException(weekday: number, label: label)
}

private func makeDefaults() throws -> (UserDefaults, String) {
    let suite = "restless.calendar.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (defaults, suite)
}

// MARK: v2 document

@Test("Calendar settings round-trip through Codable")
func settingsRoundTrip() throws {
    let anchor = TestCalendar.day(2026, 11, 11)
    let skipped = TestCalendar.day(2026, 11, 13)
    let replaced = TestCalendar.day(2026, 11, 14)
    var settings = CalendarSettings(
        restDaysBetween: 2,
        exceptions: [
            dated(TestCalendar.day(2026, 11, 24), TestCalendar.day(2026, 11, 27), " Gym closed "),
            weekday(CalendarSettings.sunday, "Travel")
        ],
        skippedDays: [skipped.addingTimeInterval(9 * 3600)],
        dayChanges: [DayChange(day: replaced, presetID: UUID(), calendar: calendar)],
        rotationAnchor: anchor,
        calendar: calendar
    )
    settings.setRestDaysBetween(5)

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(CalendarSettings.self, from: data).sanitized(calendar: calendar)

    #expect(decoded == settings)
    #expect(decoded.restDaysBetween == 5)
    #expect(decoded.exceptions.first?.label == "Gym closed")
    #expect(decoded.exceptions.first?.startDay == TestCalendar.day(2026, 11, 24))
    #expect(decoded.exceptions.last?.weekday == CalendarSettings.sunday)
    #expect(decoded.isSkipped(skipped, calendar: calendar))
    #expect(decoded.skippedDays.contains(skipped.addingTimeInterval(9 * 3600)) == false)
    #expect(decoded.change(for: replaced, calendar: calendar)?.presetID == settings.dayChanges.first?.presetID)
    #expect(decoded.rotationAnchor == anchor)
}

@Test("The rest gap clamps at zero and six")
func restGapClamps() throws {
    #expect(CalendarSettings(restDaysBetween: -3).restDaysBetween == 0)
    #expect(CalendarSettings(restDaysBetween: 9).restDaysBetween == 6)

    var settings = CalendarSettings()
    settings.setRestDaysBetween(-2)
    #expect(settings.restDaysBetween == 0)
    settings.setRestDaysBetween(42)
    #expect(settings.restDaysBetween == 6)

    let json = #"{"restDaysBetween":12,"exceptions":[]}"#
    let decoded = try JSONDecoder().decode(CalendarSettings.self, from: Data(json.utf8))
    #expect(decoded.restDaysBetween == 12)
    #expect(decoded.sanitized(calendar: calendar).restDaysBetween == 6)
}

@Test("An exception with an end before its start is refused")
func reversedExceptionRefused() {
    var settings = CalendarSettings(calendar: calendar)

    let refused = settings.addException(
        startDay: TestCalendar.day(2026, 11, 27),
        endDay: TestCalendar.day(2026, 11, 24),
        label: "Gym closed",
        calendar: calendar
    )
    #expect(refused == false)
    #expect(settings.exceptions.isEmpty)

    let added = settings.addException(
        startDay: TestCalendar.day(2026, 11, 24),
        endDay: TestCalendar.day(2026, 11, 24),
        label: "Gym closed",
        calendar: calendar
    )
    #expect(added)
    #expect(settings.exceptions.count == 1)
    #expect(settings.exceptions[0].contains(TestCalendar.day(2026, 11, 24), calendar: calendar))
    #expect(settings.exceptions[0].contains(TestCalendar.day(2026, 11, 25), calendar: calendar) == false)
}

@Test("Dated ranges may overlap and normalize to the start of their days")
func datedRangesNormalizeAndOverlap() {
    var settings = CalendarSettings(calendar: calendar)
    let morning = TestCalendar.day(2026, 11, 24).addingTimeInterval(9 * 3600)
    let evening = TestCalendar.day(2026, 11, 26).addingTimeInterval(20 * 3600)

    let firstAdded = settings.addException(startDay: morning, endDay: evening, label: "Trip", calendar: calendar)
    let secondAdded = settings.addException(
        startDay: TestCalendar.day(2026, 11, 25),
        endDay: TestCalendar.day(2026, 11, 28),
        label: "Second",
        calendar: calendar
    )
    #expect(firstAdded)
    #expect(secondAdded)

    let range = settings.exceptions[0]
    #expect(range.startDay == TestCalendar.day(2026, 11, 24))
    #expect(range.endDay == TestCalendar.day(2026, 11, 26))
    #expect(range.contains(TestCalendar.day(2026, 11, 26), calendar: calendar))
    #expect(settings.exceptions.count == 2)
    #expect(settings.exception(containing: TestCalendar.day(2026, 11, 25), calendar: calendar)?.label == "Trip")
}

@Test("A weekday closes every week and refuses a repeat")
func weekdayExceptionRules() {
    var settings = CalendarSettings(calendar: calendar)

    let sundayAdded = settings.addWeekdayException(CalendarSettings.sunday, label: "Rest")
    let repeated = settings.addWeekdayException(CalendarSettings.sunday)
    let zero = settings.addWeekdayException(0)
    let eight = settings.addWeekdayException(8)
    #expect(sundayAdded)
    #expect(repeated == false)
    #expect(settings.exceptions.count == 1)
    #expect(zero == false)
    #expect(eight == false)
    #expect(settings.exceptions.count == 1)

    #expect(settings.isClosed(TestCalendar.day(2026, 11, 15), calendar: calendar))
    #expect(settings.isClosed(TestCalendar.day(2026, 11, 22), calendar: calendar))
    #expect(settings.isClosed(TestCalendar.day(2026, 11, 16), calendar: calendar) == false)
}

@Test("A dated range is preferred over a weekday when both cover a date")
func datedRangeWinsOverWeekday() {
    var settings = CalendarSettings(calendar: calendar)
    let sunday = TestCalendar.day(2026, 11, 15)

    let weeklyAdded = settings.addWeekdayException(CalendarSettings.sunday, label: "Weekly")
    let datedAdded = settings.addException(startDay: sunday, endDay: sunday, label: "Special", calendar: calendar)
    #expect(weeklyAdded)
    #expect(datedAdded)

    #expect(settings.exception(containing: sunday, calendar: calendar)?.label == "Special")
}

@Test("A skip is a local day, round-trips, and moves nothing else")
func skipRules() throws {
    let anchor = TestCalendar.day(2026, 11, 11)
    let skipped = TestCalendar.day(2026, 11, 13)
    var settings = CalendarSettings(
        restDaysBetween: 1,
        exceptions: [weekday(CalendarSettings.sunday)],
        rotationAnchor: anchor,
        calendar: calendar
    )
    let anchorBefore = settings.rotationAnchor
    let gapBefore = settings.restDaysBetween
    let exceptionsBefore = settings.exceptions

    settings.skip(skipped.addingTimeInterval(8 * 3600), calendar: calendar)
    #expect(settings.isSkipped(skipped, calendar: calendar))
    #expect(settings.skippedDays == Set([skipped]))
    #expect(settings.rotationAnchor == anchorBefore)
    #expect(settings.restDaysBetween == gapBefore)
    #expect(settings.exceptions == exceptionsBefore)

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(CalendarSettings.self, from: data)
    #expect(decoded.isSkipped(skipped, calendar: calendar))

    settings.unskip(skipped, calendar: calendar)
    #expect(settings.skippedDays.isEmpty)
}

@Test("A date change replaces one day and can be cleared")
func dayChangeRules() {
    let preset = UUID()
    let day = TestCalendar.day(2026, 11, 14)
    var settings = CalendarSettings(calendar: calendar)

    settings.setDayChange(day: day, presetID: preset, calendar: calendar)
    #expect(settings.change(for: day, calendar: calendar)?.presetID == preset)

    let replacement = UUID()
    settings.setDayChange(day: day, presetID: replacement, calendar: calendar)
    #expect(settings.dayChanges.count == 1)
    #expect(settings.change(for: day, calendar: calendar)?.presetID == replacement)

    settings.clearDayChange(day: day, calendar: calendar)
    #expect(settings.change(for: day, calendar: calendar) == nil)
    #expect(settings.dayChanges.isEmpty)
}

// MARK: Store and migration

@Test("A missing document loads the defaults")
func missingDocumentLoadsDefaults() throws {
    let (defaults, suite) = try makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = CalendarSettingsStore(
        defaults: defaults,
        key: "calendar.v2.test",
        legacyKey: "calendar.v1.test",
        calendar: calendar
    )

    let missing = store.load()
    #expect(missing == CalendarSettings())
    #expect(missing.restDaysBetween == 0)
    #expect(missing.exceptions.isEmpty)
    #expect(missing.skippedDays.isEmpty)
    #expect(missing.dayChanges.isEmpty)
    #expect(missing.rotationAnchor == nil)
}

@Test("The v2 store reads back a fresh document and prunes old changes")
func storeRoundTripAndPrune() throws {
    let (defaults, suite) = try makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = CalendarSettingsStore(
        defaults: defaults,
        key: "calendar.v2.test",
        legacyKey: "calendar.v1.test",
        calendar: calendar
    )
    let today = calendar.startOfDay(for: .now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    let preset = UUID()

    var settings = CalendarSettings(
        restDaysBetween: 3,
        exceptions: [dated(today, tomorrow, "Gym closed"), weekday(CalendarSettings.sunday, "Travel")],
        skippedDays: [tomorrow],
        dayChanges: [
            DayChange(day: yesterday, presetID: UUID(), calendar: calendar),
            DayChange(day: tomorrow, presetID: preset, calendar: calendar)
        ],
        rotationAnchor: today,
        calendar: calendar
    )
    settings.setRestDaysBetween(4)
    store.save(settings)

    let fresh = store.load()
    #expect(fresh.restDaysBetween == 4)
    #expect(fresh.rotationAnchor == today)
    #expect(fresh.exceptions.count == 2)
    #expect(fresh.isSkipped(tomorrow, calendar: calendar))
    #expect(fresh.change(for: yesterday, calendar: calendar) == nil)
    #expect(fresh.change(for: tomorrow, calendar: calendar)?.presetID == preset)
}

@Test("A hand-written v1 document migrates to v2 and keeps its facts")
func legacyDocumentMigrates() throws {
    let (defaults, suite) = try makeDefaults()
    defer { defaults.removePersistentDomain(forName: suite) }
    let v1Key = "calendar.v1.test"
    let v2Key = "calendar.v2.test"
    let anchor = TestCalendar.day(2026, 11, 11)
    let start = TestCalendar.day(2026, 11, 24)
    let end = TestCalendar.day(2026, 11, 27)
    let identifier = UUID().uuidString

    let json = """
    {"weekStart":1,"restWeekdays":[1,7],
     "exceptions":[{"id":"\(identifier)","startDay":\(start.timeIntervalSinceReferenceDate),
     "endDay":\(end.timeIntervalSinceReferenceDate),"label":"Gym closed"}],
     "rotationAnchor":\(anchor.timeIntervalSinceReferenceDate)}
    """
    let data = Data(json.utf8)
    defaults.set(data, forKey: v1Key)

    let store = CalendarSettingsStore(
        defaults: defaults,
        key: v2Key,
        legacyKey: v1Key,
        calendar: calendar
    )
    let migrated = store.load()

    #expect(migrated.rotationAnchor == anchor)
    #expect(migrated.restDaysBetween == 0)
    #expect(migrated.skippedDays.isEmpty)
    #expect(migrated.dayChanges.isEmpty)
    #expect(migrated.exceptions.count == 3)
    #expect(migrated.exceptions[0].label == "Gym closed")
    #expect(migrated.exceptions[0].startDay == start)
    #expect(migrated.exceptions[0].endDay == end)
    #expect(migrated.exceptions[1].weekday == 1)
    #expect(migrated.exceptions[2].weekday == 7)
    #expect(migrated.isClosed(TestCalendar.day(2026, 11, 29), calendar: calendar))

    // v1 is left in place for a rollback build, and v2 is written.
    #expect(defaults.data(forKey: v1Key) == data)
    #expect(defaults.data(forKey: v2Key) != nil)
    let reloaded = store.load()
    #expect(reloaded == migrated)
}

@Test("A v1 build-shaped document decodes and ignores its week start")
func legacyBuildShapeMigrates() throws {
    struct LegacyRange: Encodable {
        var id: UUID
        var startDay: Date
        var endDay: Date
        var label: String
    }
    struct LegacyDocument: Encodable {
        var weekStart: Int?
        var restWeekdays: Set<Int>
        var exceptions: [LegacyRange]
        var rotationAnchor: Date?
    }

    let anchor = TestCalendar.day(2026, 11, 11)
    let range = LegacyRange(
        id: UUID(),
        startDay: TestCalendar.day(2026, 11, 24),
        endDay: TestCalendar.day(2026, 11, 24),
        label: "Trip"
    )

    func load(weekStart: Int) throws -> CalendarSettings {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let document = LegacyDocument(
            weekStart: weekStart,
            restWeekdays: [CalendarSettings.sunday],
            exceptions: [range],
            rotationAnchor: anchor
        )
        defaults.set(try JSONEncoder().encode(document), forKey: "calendar.v1.test")
        return CalendarSettingsStore(
            defaults: defaults,
            key: "calendar.v2.test",
            legacyKey: "calendar.v1.test",
            calendar: calendar
        ).load()
    }

    let sundayFirst = try load(weekStart: 1)
    let mondayFirst = try load(weekStart: 2)

    #expect(sundayFirst.rotationAnchor == mondayFirst.rotationAnchor)
    #expect(sundayFirst.restDaysBetween == mondayFirst.restDaysBetween)
    #expect(sundayFirst.exceptions.map(\.weekday) == mondayFirst.exceptions.map(\.weekday))
    #expect(sundayFirst.exceptions.map(\.label) == mondayFirst.exceptions.map(\.label))
    #expect(sundayFirst.exceptions.map(\.startDay) == mondayFirst.exceptions.map(\.startDay))
    #expect(sundayFirst.rotationAnchor == anchor)
    #expect(sundayFirst.exceptions.count == 2)
    #expect(sundayFirst.exceptions[0].label == "Trip")
    #expect(sundayFirst.exceptions[1].weekday == CalendarSettings.sunday)
}

// MARK: Sanitizing

@Test("The sanitizer drops inverted ranges and duplicate weekdays")
func sanitizerDropsInvalidExceptions() {
    let settings = CalendarSettings(
        exceptions: [
            weekday(CalendarSettings.sunday, "First"),
            weekday(CalendarSettings.sunday, "Second"),
            dated(TestCalendar.day(2026, 11, 27), TestCalendar.day(2026, 11, 24), "Inverted"),
            weekday(8)
        ],
        calendar: calendar
    )

    let clean = settings.sanitized(calendar: calendar)

    #expect(clean.exceptions.count == 1)
    #expect(clean.exceptions[0].label == "First")
    #expect(clean.exceptions[0].weekday == CalendarSettings.sunday)
}

@Test("The sanitizer keeps one change per day")
func sanitizerKeepsOneChangePerDay() {
    let day = TestCalendar.day(2026, 11, 14)
    let first = UUID()
    let second = UUID()
    let settings = CalendarSettings(
        dayChanges: [
            DayChange(day: day, presetID: first, calendar: calendar),
            DayChange(day: day.addingTimeInterval(6 * 3600), presetID: second, calendar: calendar)
        ],
        calendar: calendar
    )

    let clean = settings.sanitized(calendar: calendar)
    #expect(clean.dayChanges.count == 1)
    #expect(clean.change(for: day, calendar: calendar)?.presetID == second)
}
