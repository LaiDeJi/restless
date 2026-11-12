import Foundation
import Testing
@testable import Restless

private let calendar = TestCalendar.calendar

private struct TestDays {
    let today: Date
    let tomorrow: Date
    let dayAfter: Date
    let yesterday: Date
}

@MainActor
private func makeModel(defaults: UserDefaults) -> CalendarSettingsModel {
    let store = CalendarSettingsStore(
        defaults: defaults,
        key: "calendar.v2.test",
        legacyKey: "calendar.v1.test",
        calendar: calendar
    )
    return CalendarSettingsModel(store: store, calendar: calendar)
}

@MainActor
private func makeStore(defaults: UserDefaults) -> CalendarSettingsStore {
    CalendarSettingsStore(
        defaults: defaults,
        key: "calendar.v2.test",
        legacyKey: "calendar.v1.test",
        calendar: calendar
    )
}

private func days() -> TestDays {
    let today = calendar.startOfDay(for: .now)
    return TestDays(
        today: today,
        tomorrow: calendar.date(byAdding: .day, value: 1, to: today)!,
        dayAfter: calendar.date(byAdding: .day, value: 2, to: today)!,
        yesterday: calendar.date(byAdding: .day, value: -1, to: today)!
    )
}

@Test("The anchor starts on today when today is open")
@MainActor
func initializationUsesTodayWhenOpen() throws {
    let suite = "restless.model.init.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)
    let today = days().today

    model.initializeRotation(today: today)
    #expect(model.settings.rotationAnchor == today)

    model.initializeRotation(today: days().tomorrow)
    #expect(model.settings.rotationAnchor == today)
}

@Test("The anchor starts on the next open day when today is closed")
@MainActor
func initializationSkipsAClosedToday() throws {
    let suite = "restless.model.init.closed.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = makeStore(defaults: defaults)
    let dates = days()
    var settings = CalendarSettings(calendar: calendar)
    let added = settings.addException(startDay: dates.today, endDay: dates.today, calendar: calendar)
    #expect(added)
    store.save(settings)

    let model = CalendarSettingsModel(store: store, calendar: calendar)
    model.initializeRotation(today: dates.today)
    #expect(model.settings.rotationAnchor == dates.tomorrow)
}

@Test("The rest gap saves and clamps")
@MainActor
func restGapSavesAndClamps() throws {
    let suite = "restless.model.gap.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)

    model.setRestGap(9)
    #expect(model.settings.restDaysBetween == 6)
    #expect(makeModel(defaults: defaults).settings.restDaysBetween == 6)

    model.setRestGap(-3)
    #expect(model.settings.restDaysBetween == 0)
    #expect(makeModel(defaults: defaults).settings.restDaysBetween == 0)
}

@Test("A new round clears skips and changes and saves the anchor")
@MainActor
func newRoundClearsMarksAndSaves() throws {
    let suite = "restless.model.round.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)
    let dates = days()
    let preset = UUID()
    let sessions = [RotationSession(id: preset, name: "Chest")]

    model.initializeRotation(today: dates.today)
    model.skip(dates.tomorrow, sessions: sessions)
    model.setDayChange(day: dates.dayAfter, presetID: preset)
    #expect(model.settings.isSkipped(dates.tomorrow, calendar: calendar))
    #expect(model.settings.change(for: dates.dayAfter, calendar: calendar) != nil)

    let started = model.startNewRound(on: dates.tomorrow, today: dates.today)
    #expect(started)
    #expect(model.settings.rotationAnchor == dates.tomorrow)
    #expect(model.settings.skippedDays.isEmpty)
    #expect(model.settings.dayChanges.isEmpty)

    let fresh = makeModel(defaults: defaults)
    #expect(fresh.settings.rotationAnchor == dates.tomorrow)
    #expect(fresh.settings.skippedDays.isEmpty)
    #expect(fresh.settings.dayChanges.isEmpty)
}

@Test("A past date refuses a new round and keeps the anchor")
@MainActor
func pastRoundRefused() throws {
    let suite = "restless.model.round.past.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)
    let dates = days()

    model.initializeRotation(today: dates.today)
    let refused = model.startNewRound(on: dates.yesterday, today: dates.today)
    #expect(refused == false)
    #expect(model.settings.rotationAnchor == dates.today)
}

@Test("Skip and unskip persist across a fresh model")
@MainActor
func skipAndUnskipPersist() throws {
    let suite = "restless.model.skip.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)
    let dates = days()
    let sessions = [RotationSession(id: UUID(), name: "Chest")]

    model.initializeRotation(today: dates.today)
    model.skip(dates.tomorrow, sessions: sessions)
    #expect(makeModel(defaults: defaults).settings.isSkipped(dates.tomorrow, calendar: calendar))

    model.unskip(dates.tomorrow)
    #expect(makeModel(defaults: defaults).settings.isSkipped(dates.tomorrow, calendar: calendar) == false)
}

@Test("A date change saves, clears, and persists across a fresh model")
@MainActor
func dayChangePersists() throws {
    let suite = "restless.model.change.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = makeModel(defaults: defaults)
    let dates = days()
    let preset = UUID()

    model.setDayChange(day: dates.tomorrow, presetID: preset)
    #expect(model.settings.change(for: dates.tomorrow, calendar: calendar)?.presetID == preset)
    #expect(makeModel(defaults: defaults)
        .settings.change(for: dates.tomorrow, calendar: calendar)?.presetID == preset)

    model.clearDayChange(day: dates.tomorrow)
    #expect(model.settings.change(for: dates.tomorrow, calendar: calendar) == nil)
    #expect(makeModel(defaults: defaults)
        .settings.change(for: dates.tomorrow, calendar: calendar) == nil)
}
