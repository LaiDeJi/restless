import Foundation
import SwiftData

/// The in-memory session behind SESSIONS' add control. Building one touches no
/// store, so opening the editor and backing out leaves the list unchanged.
enum NewSessionDraft {
    /// The draft copies the active block's schedule and none of its movements:
    /// a new session's movements are the user's to choose.
    static func make(from active: WorkoutPreset?) -> WorkoutPreset {
        let source = active?.blocks.first
        let block = WorkoutBlock(
            name: "Untitled block",
            rounds: source?.rounds ?? WorkoutBlock.defaultRounds,
            setsPerRound: source?.setsPerRound ?? WorkoutBlock.defaultSetsPerRound,
            setRest: source?.setRest ?? WorkoutBlock.defaultSetRest,
            roundRest: source?.roundRest ?? WorkoutBlock.defaultRoundRest
        )
        return WorkoutPreset(name: "New session", blocks: [block])
    }
}

/// Commits a draft to exactly one record. It never activates the session: DONE
/// and USE differ only in what the caller does after the record exists.
@MainActor
enum SessionDraftCommit {
    /// Returns nil for a draft with an empty block, so a saved session always
    /// has at least one movement per block.
    @discardableResult
    static func save(
        _ draft: WorkoutPreset,
        usedNames: [String],
        in context: ModelContext
    ) -> PresetRecord? {
        guard draft.canCommit else { return nil }
        var session = NameRules.normalize(draft)
        if session.name == "New session" {
            session.name = NameRules.uniqueName("New session", used: usedNames)
        }
        PresetRepository.normalizeOrder(in: context)
        let record = PresetRecord(session)
        record.sortIndex = PresetRepository.fetchAll(context).count
        context.insert(record)
        try? context.save()
        return record
    }
}
