import Foundation
import SwiftData
import Testing
@testable import Restless

private let dayOne = TestCalendar.day(2026, 11, 15)
private let dayTwo = TestCalendar.day(2026, 11, 16)
private let calendar = TestCalendar.calendar

private func session(id: UUID, name: String) -> WorkoutPreset {
    WorkoutPreset(
        id: id,
        name: name,
        blocks: [
            WorkoutBlock(
                name: name,
                rounds: 1,
                setsPerRound: 3,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
}

@MainActor
private struct FollowerFixture {
    let container: ModelContainer
    let context: ModelContext
    let calendarSettings: CalendarSettingsModel
    let storage: ActivePresetStorage
    let defaults: UserDefaults
    let suite: String
    let chest: WorkoutPreset
    let arms: WorkoutPreset

    init() throws {
        let suite = "restless.tests.follower.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let container = try ModelContainer(
            for: PresetRecord.self,
            MovementRecord.self,
            WorkoutRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let chest = session(id: UUID(), name: "Chest")
        let arms = session(id: UUID(), name: "Arms")
        let chestRecord = PresetRecord(chest)
        chestRecord.sortIndex = 0
        let armsRecord = PresetRecord(arms)
        armsRecord.sortIndex = 1
        context.insert(chestRecord)
        context.insert(armsRecord)
        try context.save()

        self.container = container
        self.context = context
        self.suite = suite
        self.defaults = defaults
        self.chest = chest
        self.arms = arms
        self.storage = ActivePresetStorage(defaults: defaults)
        self.calendarSettings = CalendarSettingsModel(
            store: CalendarSettingsStore(defaults: defaults, calendar: calendar),
            calendar: calendar
        )
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suite)
        SessionStore.clear()
    }
}

@MainActor
@Test("Tomorrow's plan replaces an idle Chest")
func tomorrowsPlanReplacesIdleChest() throws {
    SessionStore.clear()
    let fixture = try FollowerFixture()
    defer { fixture.cleanUp() }

    fixture.calendarSettings.initializeRotation(today: dayOne)
    fixture.storage.activate(id: fixture.chest.id, on: dayOne)
    let engine = SessionEngine(preset: fixture.chest)

    let decision = ActiveSessionFollower.follow(
        today: dayTwo,
        calendar: calendar,
        context: fixture.context,
        calendarSettings: fixture.calendarSettings,
        engine: engine,
        storage: fixture.storage
    )

    #expect(decision == .switchTo(RotationSession(id: fixture.arms.id, name: fixture.arms.name)))
    #expect(engine.snapshot.preset.id == fixture.arms.id)
    #expect(engine.snapshot.phase == .notStarted)
    #expect(fixture.storage.id == fixture.arms.id)
    #expect(fixture.storage.marks(dayTwo, calendar: calendar))
}

@MainActor
@Test("A manual pick on the same day holds")
func manualPickHoldsForTheDay() throws {
    SessionStore.clear()
    let fixture = try FollowerFixture()
    defer { fixture.cleanUp() }

    fixture.calendarSettings.initializeRotation(today: dayOne)
    fixture.storage.activate(id: fixture.arms.id, on: dayOne)
    let engine = SessionEngine(preset: fixture.arms)

    let decision = ActiveSessionFollower.follow(
        today: dayOne,
        calendar: calendar,
        context: fixture.context,
        calendarSettings: fixture.calendarSettings,
        engine: engine,
        storage: fixture.storage
    )

    #expect(decision == .keep)
    #expect(engine.snapshot.preset.id == fixture.arms.id)
    #expect(fixture.storage.id == fixture.arms.id)
    #expect(fixture.storage.marks(dayOne, calendar: calendar))
}

@MainActor
@Test("A session with a completed set is not replaced")
func completedSetIsNotReplaced() throws {
    SessionStore.clear()
    let fixture = try FollowerFixture()
    defer { fixture.cleanUp() }

    fixture.calendarSettings.initializeRotation(today: dayOne)
    fixture.storage.activate(id: fixture.chest.id, on: dayOne)
    let engine = SessionEngine(preset: fixture.chest)
    engine.perform(.startSession)
    engine.perform(.setDone)
    #expect(engine.snapshot.doneSets == 1)

    let decision = ActiveSessionFollower.follow(
        today: dayTwo,
        calendar: calendar,
        context: fixture.context,
        calendarSettings: fixture.calendarSettings,
        engine: engine,
        storage: fixture.storage
    )

    #expect(decision == .keep)
    #expect(engine.snapshot.preset.id == fixture.chest.id)
    #expect(engine.snapshot.doneSets == 1)
    #expect(engine.snapshot.phase == .resting)
    #expect(fixture.storage.id == fixture.chest.id)
    #expect(fixture.storage.marks(dayOne, calendar: calendar))
}

@MainActor
@Test("The same plan at the gate records the day without resetting")
func samePlanRecordsDay() throws {
    SessionStore.clear()
    let fixture = try FollowerFixture()
    defer { fixture.cleanUp() }

    fixture.calendarSettings.initializeRotation(today: dayTwo)
    fixture.storage.id = fixture.chest.id
    let engine = SessionEngine(preset: fixture.chest)

    let decision = ActiveSessionFollower.follow(
        today: dayTwo,
        calendar: calendar,
        context: fixture.context,
        calendarSettings: fixture.calendarSettings,
        engine: engine,
        storage: fixture.storage
    )

    #expect(decision == .recordDay)
    #expect(engine.snapshot.preset.id == fixture.chest.id)
    #expect(engine.snapshot.phase == .notStarted)
    #expect(fixture.storage.id == fixture.chest.id)
    #expect(fixture.storage.marks(dayTwo, calendar: calendar))
}
