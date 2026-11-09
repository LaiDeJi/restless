import Foundation
import SwiftData

/// The in-memory session behind SESSIONS' add control. Building one touches no
/// store, so opening the editor and backing out leaves the list unchanged.
enum NewSessionDraft {
    static func make(from active: WorkoutPreset?) -> WorkoutPreset {
        var block = active?.blocks.first ?? .fallback
        block.id = UUID()
        block.name = "Untitled block"
        return WorkoutPreset(name: "New session", blocks: [block])
    }
}

/// Commits a draft to exactly one record. It never activates the session: DONE
/// and USE differ only in what the caller does after the record exists.
@MainActor
enum SessionDraftCommit {
    @discardableResult
    static func save(
        _ draft: WorkoutPreset,
        usedNames: [String],
        in context: ModelContext
    ) -> PresetRecord {
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
