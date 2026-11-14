import Foundation
import SwiftData
import Testing
@testable import Restless

private func memoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: PresetRecord.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

private func filled(_ draft: WorkoutPreset) -> WorkoutPreset {
    var copy = draft
    copy.blocks[0].movements = [
        BlockMovement(movementId: Movement.chestID, endCondition: .manual, target: nil)
    ]
    return copy
}

@MainActor
@Test("A new session draft copies the active block's schedule and no movements")
func newSessionDraftCopiesScheduleOnly() throws {
    let active = WorkoutPreset.chest
    let draft = NewSessionDraft.make(from: active)

    #expect(draft.id != active.id)
    #expect(draft.name == "New session")
    #expect(draft.blocks.count == 1)
    #expect(draft.blocks[0].id != active.blocks[0].id)
    #expect(draft.blocks[0].name == "Untitled block")
    #expect(draft.blocks[0].rounds == active.blocks[0].rounds)
    #expect(draft.blocks[0].setsPerRound == active.blocks[0].setsPerRound)
    #expect(draft.blocks[0].setRest == active.blocks[0].setRest)
    #expect(draft.blocks[0].roundRest == active.blocks[0].roundRest)
    #expect(draft.blocks[0].movements.isEmpty)
    #expect(draft.totalSets == 0)
    #expect(!draft.canCommit)
}

@MainActor
@Test("A draft with no active session keeps the standard block defaults")
func newSessionDraftDefaultsWithoutActiveSession() throws {
    let draft = NewSessionDraft.make(from: nil)
    let block = try #require(draft.blocks.first)

    #expect(block.rounds == WorkoutBlock.defaultRounds)
    #expect(block.setsPerRound == WorkoutBlock.defaultSetsPerRound)
    #expect(block.setRest == WorkoutBlock.defaultSetRest)
    #expect(block.roundRest == WorkoutBlock.defaultRoundRest)
    #expect(block.movements.isEmpty)
}

@MainActor
@Test("Building a draft does not write a record")
func newSessionDraftHasNoRecordSideEffect() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    _ = NewSessionDraft.make(from: .chest)

    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).isEmpty)
}

@MainActor
@Test("An empty draft creates no record")
func emptyDraftIsRefused() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let draft = NewSessionDraft.make(from: .chest)

    let record = SessionDraftCommit.save(draft, usedNames: [], in: context)

    #expect(record == nil)
    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).isEmpty)
}

@MainActor
@Test("DONE saves exactly one session with the draft's name, blocks, and values")
func draftCommitInsertsOneSession() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    var draft = filled(NewSessionDraft.make(from: .chest))
    draft.name = "Legs"
    draft.blocks[0].rounds = 3
    draft.blocks[0].setsPerRound = 5
    draft.blocks[0].setRest = 45
    draft.blocks[0].roundRest = 90

    let record = try #require(SessionDraftCommit.save(draft, usedNames: ["Chest"], in: context))
    let records = try context.fetch(FetchDescriptor<PresetRecord>())

    #expect(records.count == 1)
    #expect(records[0].id == record.id)
    #expect(records[0].name == "Legs")
    #expect(records[0].preset.blocks == draft.blocks)
    #expect(records[0].preset.blocks[0].rounds == 3)
    #expect(records[0].preset.blocks[0].setsPerRound == 5)
}

@MainActor
@Test("The default New session name gets its lowest free suffix at save")
func draftCommitResolvesUniqueDefaultName() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let draft = filled(NewSessionDraft.make(from: .chest))

    let record = try #require(SessionDraftCommit.save(
        draft,
        usedNames: ["New session", "New session 2"],
        in: context
    ))

    #expect(record.name == "New session 3")
}

@MainActor
@Test("A typed name is kept when the draft is saved")
func draftCommitKeepsTypedName() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    var draft = filled(NewSessionDraft.make(from: .chest))
    draft.name = "Push Day"

    let record = try #require(SessionDraftCommit.save(draft, usedNames: ["Push Day"], in: context))

    #expect(record.name == "Push Day")
}

@MainActor
@Test("Discarding a draft leaves zero records")
func discardedDraftLeavesNoRecord() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)

    let draft = filled(NewSessionDraft.make(from: .chest))
    #expect(draft.name == "New session")
    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).isEmpty)
}

@MainActor
@Test("Committing a draft leaves the active session alone")
func draftCommitDoesNotActivate() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let previous = ActivePresetStore.id
    defer { ActivePresetStore.id = previous }

    let draft = filled(NewSessionDraft.make(from: .chest))
    let record = try #require(SessionDraftCommit.save(draft, usedNames: [], in: context))

    #expect(ActivePresetStore.id == previous)
    #expect(ActivePresetStore.id != record.id)
}

@MainActor
@Test("A draft store flushes to memory without a commit")
func draftStoreFlushesWithoutPersisting() throws {
    let container = try memoryContainer()
    let context = ModelContext(container)
    let store = SessionDraftStore(
        session: NewSessionDraft.make(from: .chest),
        delay: .seconds(10)
    )

    store.edit { $0.blocks[0].setsPerRound = 4 }
    store.flush()

    #expect(store.commit == nil)
    #expect(store.session.blocks[0].setsPerRound == 4)
    #expect(try context.fetch(FetchDescriptor<PresetRecord>()).isEmpty)
}

@Test("The unique name helper ignores case and finds the lowest free suffix")
func uniqueNameFindsLowestSuffix() {
    #expect(NameRules.uniqueName("New session", used: []) == "New session")
    #expect(NameRules.uniqueName("New session", used: ["New session"]) == "New session 2")
    #expect(
        NameRules.uniqueName("New session", used: ["New session", "NEW SESSION 2"]) == "New session 3"
    )
    #expect(NameRules.uniqueName("Arms", used: ["Arms"]) == "Arms 2")
}
