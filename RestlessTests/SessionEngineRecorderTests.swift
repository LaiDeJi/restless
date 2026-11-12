import Foundation
import SwiftData
import Testing
@testable import Restless

private let manualPreset = WorkoutPreset(
    name: "Chest",
    blocks: [
        WorkoutBlock(
            name: "Chest",
            rounds: 1,
            setsPerRound: 3,
            setRest: 60,
            roundRest: 120,
            movements: [BlockMovement(movementId: UUID())]
        )
    ]
)

private let timedPreset = WorkoutPreset(
    name: "Timed",
    blocks: [
        WorkoutBlock(
            name: "Core",
            rounds: 1,
            setsPerRound: 2,
            setRest: 45,
            roundRest: 60,
            movements: [BlockMovement(movementId: UUID(), endCondition: .time, target: 60)]
        )
    ]
)

@MainActor
private final class FakeRecorder: WorkoutHistoryRecording {
    private(set) var snapshots: [SessionSnapshot] = []

    func record(_ snapshot: SessionSnapshot, now: Date) {
        snapshots.append(snapshot)
    }
}

@MainActor
@Test("A completed set reaches the recorder, and every call shares one run key")
func completedSetIsRecorded() {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let engine = SessionEngine(preset: manualPreset)
    let recorder = FakeRecorder()
    engine.historyRecorder = recorder

    engine.perform(.startSession)
    engine.perform(.setDone)

    let keys = Set(recorder.snapshots.map { WorkoutRecord.runKey(for: $0) })
    #expect(keys.count == 1)
    #expect(recorder.snapshots.contains { $0.doneSets == 1 && $0.phase == .resting })
}

@MainActor
@Test("A timed set that expired before launch is recorded on restore")
func expiredBeforeLaunchIsRecorded() {
    SessionStore.clear()
    defer { SessionStore.clear() }

    var saved = SessionSnapshot.initial(timedPreset, now: Date.now.addingTimeInterval(-120))
    saved.phase = .performing
    saved.setDuration = 60
    saved.setDeadline = Date.now.addingTimeInterval(-1)
    SessionStore.save(saved)

    let engine = SessionEngine(preset: timedPreset)
    #expect(engine.snapshot.doneSets == 1)

    let recorder = FakeRecorder()
    engine.historyRecorder = recorder

    #expect(recorder.snapshots.contains { $0.doneSets == 1 && $0.phase == .resting })
    #expect(recorder.snapshots.allSatisfy {
        WorkoutRecord.runKey(for: $0) == WorkoutRecord.runKey(for: saved)
    })
}

@MainActor
@Test("An island action applied while away is recorded by the refresh path")
func islandActionWhileAwayIsRecorded() {
    SessionStore.clear()
    defer { SessionStore.clear() }

    let engine = SessionEngine(preset: manualPreset)
    let recorder = FakeRecorder()
    engine.historyRecorder = recorder
    engine.perform(.startSession)
    engine.perform(.setDone)

    // The island's intent already applied a set and wrote the snapshot; the app
    // was away, so refreshFromStore is the path that sees it.
    var away = engine.snapshot
    away.doneSets = 2
    away.phase = .resting
    away.restKind = .set
    away.duration = 60
    away.pausedRemaining = 60
    away.deadline = Date.now.addingTimeInterval(60)
    SessionStore.save(away)

    engine.refreshFromStore()

    #expect(engine.snapshot.doneSets == 2)
    #expect(recorder.snapshots.last?.doneSets == 2)
    let keys = Set(recorder.snapshots.map { WorkoutRecord.runKey(for: $0) })
    #expect(keys.count == 1)
}

@MainActor
@Test("A rest that expired before launch is recorded on restore")
func expiredRestBeforeLaunchIsRecorded() {
    SessionStore.clear()
    defer { SessionStore.clear() }

    var saved = SessionSnapshot.initial(manualPreset, now: Date.now.addingTimeInterval(-180))
    saved.doneSets = 1
    saved.phase = .resting
    saved.restKind = .set
    saved.duration = 60
    saved.pausedRemaining = 60
    saved.deadline = Date.now.addingTimeInterval(-30)
    SessionStore.save(saved)

    let engine = SessionEngine(preset: manualPreset)
    #expect(engine.snapshot.doneSets == 1)
    #expect(engine.snapshot.phase == .ready)

    let recorder = FakeRecorder()
    engine.historyRecorder = recorder

    #expect(recorder.snapshots.contains { $0.doneSets == 1 && $0.phase == .ready })
    #expect(recorder.snapshots.allSatisfy {
        WorkoutRecord.runKey(for: $0) == WorkoutRecord.runKey(for: saved)
    })
}

@MainActor
@Test("The engine's first set writes one record through the real store")
func engineFeedsTheHistoryStore() throws {
    SessionStore.clear()
    defer { SessionStore.clear() }
    let container = try ModelContainer(
        for: PresetRecord.self, MovementRecord.self, WorkoutRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let engine = SessionEngine(preset: manualPreset)
    engine.historyRecorder = WorkoutHistoryStore(context: context)

    engine.perform(.startSession)
    engine.perform(.setDone)

    let records = WorkoutRepository.fetchAll(in: context)
    #expect(records.count == 1)
    #expect(records[0].doneSets == 1)
    #expect(records[0].phase == .resting)
}
