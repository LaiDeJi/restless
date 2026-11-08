import Foundation

/// Plan names: trimmed, 18 characters, with a fixed fallback when the field is
/// left empty.
enum NameRules {
    static let limit = WorkoutPreset.bounds.nameLimit

    static func session(_ raw: String) -> String {
        normalized(raw, fallback: "Untitled")
    }

    static func block(_ raw: String) -> String {
        normalized(raw, fallback: "Untitled block")
    }

    static func movement(_ raw: String) -> String {
        normalized(raw, fallback: "Untitled movement")
    }

    /// The value shown while typing: capped but not trimmed, so a space can be
    /// typed between words.
    static func live(_ raw: String) -> String {
        String(raw.prefix(limit))
    }

    private static func normalized(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(limit))
    }

    /// A session ready to persist: counts and rests clamped, names trimmed and
    /// capped, block names normalized.
    static func normalize(_ session: WorkoutPreset) -> WorkoutPreset {
        var copy = session.clamped()
        copy.name = Self.session(copy.name)
        copy.blocks = copy.blocks.map { block in
            var normalized = block
            normalized.name = Self.block(block.name)
            return normalized
        }
        return copy
    }

    /// The lowest free `base`, `base 2`, `base 3`, … against the names already
    /// in use, ignoring case. A new session resolves its default name here, at
    /// save time, not when the draft opens.
    static func uniqueName(_ base: String, used: [String]) -> String {
        let taken = Set(used.map { $0.lowercased() })
        if !taken.contains(base.lowercased()) { return live(base) }
        for index in 2..<100 {
            let candidate = live("\(base) \(index)")
            if !taken.contains(candidate.lowercased()) { return candidate }
        }
        return live(base)
    }
}
