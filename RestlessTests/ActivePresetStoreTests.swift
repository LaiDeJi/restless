import Foundation
import Testing
@testable import Restless

/// A private defaults suite per test, so nothing touches the live app defaults.
private struct TestStorage {
    let value: ActivePresetStorage
    let defaults: UserDefaults
    let suite: String

    init() {
        let suite = "restless.tests.activePreset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        self.suite = suite
        self.defaults = defaults
        self.value = ActivePresetStorage(defaults: defaults)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suite)
    }
}

@Test("Activating writes the id and its local day together")
func activePresetActivateWritesBoth() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let id = UUID()
    let today = TestCalendar.day(2026, 11, 15)

    value.activate(id: id, on: today)

    #expect(value.id == id)
    #expect(value.day == today)
    #expect(value.marks(today, calendar: TestCalendar.calendar))
    #expect(!value.marks(TestCalendar.day(2026, 11, 16), calendar: TestCalendar.calendar))
}

@Test("Replacing an activation replaces both values")
func activePresetReplacesBoth() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let first = UUID()
    let second = UUID()
    let dayOne = TestCalendar.day(2026, 11, 15)
    let dayTwo = TestCalendar.day(2026, 11, 16)

    value.activate(id: first, on: dayOne)
    value.activate(id: second, on: dayTwo)

    #expect(value.id == second)
    #expect(value.day == dayTwo)
    #expect(value.marks(dayTwo, calendar: TestCalendar.calendar))
    #expect(!value.marks(dayOne, calendar: TestCalendar.calendar))
}

@Test("A missing day marker is stale")
func activePresetMissingDayIsStale() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let legacyID = UUID()

    // The id an older build left behind, with no day attached.
    value.id = legacyID

    #expect(value.id == legacyID)
    #expect(value.day == nil)
    #expect(!value.marks(TestCalendar.day(2026, 11, 15), calendar: TestCalendar.calendar))
}

@Test("The day marker compares local days, not instants")
func activePresetMarkerUsesLocalDays() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let id = UUID()
    let calendar = TestCalendar.calendar
    let morning = TestCalendar.day(2026, 11, 15)
    let evening = morning.addingTimeInterval(20 * 3_600)

    value.activate(id: id, on: morning)

    #expect(value.marks(evening, calendar: calendar))
}

@Test("Writing the active id alone leaves the day marker alone")
func activePresetIDOnlyWriteKeepsDay() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let yesterday = TestCalendar.day(2026, 11, 14)
    let today = TestCalendar.day(2026, 11, 15)
    let active = UUID()
    let edited = UUID()

    // Editing and restarting the active session rewrite the plan and call
    // `engine.use`, not the store; the marker keeps the day of the manual pick.
    value.activate(id: active, on: yesterday)
    value.id = edited

    #expect(value.id == edited)
    #expect(value.day == yesterday)
    #expect(!value.marks(today, calendar: TestCalendar.calendar))
}

@Test("The fallback after a delete holds the same day")
func activePresetFallbackHoldsTheDay() {
    let fixture = TestStorage()
    defer { fixture.cleanUp() }
    let value = fixture.value
    let yesterday = TestCalendar.day(2026, 11, 14)
    let today = TestCalendar.day(2026, 11, 15)
    let deleted = UUID()
    let fallback = UUID()

    value.activate(id: deleted, on: yesterday)
    // Deleting the active session activates the next record on the same day.
    value.activate(id: fallback, on: today)

    #expect(value.id == fallback)
    #expect(value.marks(today, calendar: TestCalendar.calendar))
    #expect(!value.marks(yesterday, calendar: TestCalendar.calendar))
}
