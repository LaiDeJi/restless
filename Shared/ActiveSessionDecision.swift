import Foundation

/// What the app should do about today's planned session. The decision is pure
/// so the date rule can be tested with a fixed calendar and no store.
enum ActiveSessionDecision: Equatable, Sendable {
    /// Leave the active session and its state alone.
    case keep
    /// Today's plan is already active at the gate with no progress: record the
    /// day without resetting.
    case recordDay
    /// Activate the planned session at its start gate.
    case switchTo(RotationSession)
}

extension ActiveSessionDecision {
    /// - Parameters:
    ///   - activeID: the stored active preset id.
    ///   - activeDay: the local day the active session was chosen for; nil is
    ///     stale, including installs that predate the marker.
    ///   - today: the local day being opened.
    ///   - plan: the session the calendar plans for `today`, after a per-date
    ///     change; nil on a rest, closed, skipped or unplanned day.
    ///   - snapshot: the live session, so progress is never replaced.
    static func decide(
        activeID: UUID?,
        activeDay: Date?,
        today: Date,
        plan: RotationSession?,
        snapshot: SessionSnapshot,
        calendar: Calendar = .current
    ) -> ActiveSessionDecision {
        guard let plan else { return .keep }

        // A manual pick holds for the rest of its day, whatever today's plan is.
        if let activeDay, calendar.isDate(activeDay, inSameDayAs: today) {
            return .keep
        }

        // A performing, resting or paused session, or any session with
        // completed sets, is never replaced.
        guard isReplaceable(snapshot) else { return .keep }

        guard activeID == plan.id else { return .switchTo(plan) }

        // The same plan is already at the gate: only the day marker is stale.
        // A done session starts fresh, even when the rotation holds one session.
        return snapshot.phase == .done ? .switchTo(plan) : .recordDay
    }

    /// The gate and a ready session with no completed sets can be replaced; a
    /// finished session yields to the new day; everything running is protected.
    private static func isReplaceable(_ snapshot: SessionSnapshot) -> Bool {
        switch snapshot.phase {
        case .notStarted, .ready:
            return snapshot.doneSets == 0
        case .done:
            return true
        case .performing, .resting, .paused:
            return false
        }
    }
}
