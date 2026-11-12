import Foundation
import SwiftData
import Testing
@testable import Restless

private let calendar = TestCalendar.calendar
private let now = TestCalendar.day(2026, 11, 11)

private func memoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: PresetRecord.self, MovementRecord.self, WorkoutRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

private func runSnapshot(
    _ preset: WorkoutPreset,
    doneSets: Int,
    phase: SessionPhase,
    startedAt: Date = now
) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset, now: startedAt)
    snapshot.doneSets = doneSets
    snapshot.phase = phase
    return snapshot
}

@MainActor
@Test("The store opens with the preset, movement, and history entities")
func containerOpensWithHistory() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    context.insert(PresetRecord(.chest))
    context.insert(MovementRecord(.chest))
    context.insert(WorkoutRecord(
        snapshot: runSnapshot(.chest, doneSets: 1, phase: .resting),
        now: now,
        calendar: calendar
    ))
    try context.save()

    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<MovementRecord>()).count == 1)
    let records = try context.fetch(FetchDescriptor<WorkoutRecord>())
    #expect(records.count == 1)
    #expect(records[0].sessionName == "Chest")
    #expect(records[0].doneSets == 1)
    #expect(records[0].runKey.contains(WorkoutPreset.chest.id.uuidString))
}

@MainActor
@Test("The gate creates nothing, the first set creates one record, done finishes once")
func recordLifecycle() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let store = WorkoutHistoryStore(context: context, calendar: calendar)
    let preset = WorkoutPreset.chest

    var snapshot = SessionSnapshot.initial(preset, now: now)
    store.record(snapshot, now: now)
    #expect(WorkoutRepository.fetchAll(in: context).isEmpty)

    snapshot.phase = .ready
    snapshot.doneSets = 1
    store.record(snapshot, now: now.addingTimeInterval(1))
    var records = WorkoutRepository.fetchAll(in: context)
    #expect(records.count == 1)
    #expect(records[0].doneSets == 1)
    #expect(records[0].finishedAt == nil)
    #expect(records[0].totalSets == preset.totalSets)

    snapshot.phase = .resting
    snapshot.doneSets = 2
    store.record(snapshot, now: now.addingTimeInterval(2))
    records = WorkoutRepository.fetchAll(in: context)
    #expect(records.count == 1)
    #expect(records[0].doneSets == 2)
    #expect(records[0].phase == .resting)
    #expect(records[0].lastActivityAt == now.addingTimeInterval(2))

    snapshot.phase = .done
    snapshot.doneSets = preset.totalSets
    store.record(snapshot, now: now.addingTimeInterval(3))
    records = WorkoutRepository.fetchAll(in: context)
    #expect(records.count == 1)
    #expect(records[0].doneSets == preset.totalSets)
    #expect(records[0].phase == .done)
    #expect(records[0].finishedAt == now.addingTimeInterval(3))

    store.record(snapshot, now: now.addingTimeInterval(30))
    records = WorkoutRepository.fetchAll(in: context)
    #expect(records.count == 1)
    #expect(records[0].finishedAt == now.addingTimeInterval(3))
    #expect(records[0].lastActivityAt == now.addingTimeInterval(3))
}

@MainActor
@Test("The record keeps its own snapshot after the session is edited and deleted")
func recordKeepsItsSnapshot() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let store = WorkoutHistoryStore(context: context, calendar: calendar)
    let bench = UUID()
    let curl = UUID()
    let preset = WorkoutPreset(
        name: "Chest",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 2,
                setsPerRound: 3,
                setRest: 45,
                roundRest: 90,
                movements: [
                    BlockMovement(movementId: bench, endCondition: .manual),
                    BlockMovement(movementId: curl, endCondition: .time, target: 60)
                ]
            )
        ]
    )
    let source = PresetRecord(preset)
    context.insert(source)
    try context.save()

    let snapshot = runSnapshot(preset, doneSets: 1, phase: .ready)
    store.record(snapshot, now: now)

    source.name = "Renamed"
    source.apply(WorkoutPreset(
        id: preset.id,
        name: "Renamed",
        blocks: [
            WorkoutBlock(
                name: "Changed",
                rounds: 1,
                setsPerRound: 1,
                setRest: 15,
                roundRest: 15,
                movements: [BlockMovement(movementId: bench)]
            )
        ]
    ))
    try context.save()
    context.delete(source)
    try context.save()

    let record = try #require(WorkoutRepository.fetchAll(in: context).first)
    #expect(record.sessionName == "Chest")
    #expect(record.preset.name == "Chest")
    #expect(record.preset.blocks == preset.blocks)
    #expect(record.preset.blocks[0].setRest == 45)
    #expect(record.preset.blocks[0].roundRest == 90)
    #expect(record.totalSets == preset.totalSets)
}

@MainActor
@Test("A run that crosses midnight belongs to its start date")
func recordBelongsToStartDate() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let store = WorkoutHistoryStore(context: context, calendar: calendar)
    let preset = WorkoutPreset.chest
    let start = calendar.date(
        from: DateComponents(year: 2026, month: 11, day: 10, hour: 23, minute: 50)
    )!
    let finish = calendar.date(
        from: DateComponents(year: 2026, month: 11, day: 11, hour: 0, minute: 20)
    )!

    let snapshot = runSnapshot(
        preset,
        doneSets: preset.totalSets,
        phase: .done,
        startedAt: start
    )
    store.record(snapshot, now: finish)

    let record = try #require(WorkoutRepository.fetchAll(in: context).first)
    #expect(record.startDay == TestCalendar.day(2026, 11, 10))
    #expect(WorkoutRepository.records(on: start, in: context, calendar: calendar).count == 1)
    #expect(WorkoutRepository.records(on: finish, in: context, calendar: calendar).isEmpty)
    #expect(WorkoutRepository.records(on: TestCalendar.day(2026, 11, 11), in: context, calendar: calendar).isEmpty)
}

@MainActor
@Test("Deleting a record leaves the session and other records alone")
func deleteRecordOnly() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let store = WorkoutHistoryStore(context: context, calendar: calendar)
    let preset = WorkoutPreset.chest
    context.insert(PresetRecord(preset))

    store.record(runSnapshot(preset, doneSets: 1, phase: .ready), now: now)
    let secondStart = now.addingTimeInterval(3_600)
    store.record(
        runSnapshot(preset, doneSets: 1, phase: .ready, startedAt: secondStart),
        now: secondStart
    )
    #expect(WorkoutRepository.fetchAll(in: context).count == 2)

    let first = try #require(WorkoutRepository.fetchAll(in: context).first)
    store.delete(runKey: first.runKey)

    #expect(WorkoutRepository.fetchAll(in: context).count == 1)
    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).count == 1)
}
