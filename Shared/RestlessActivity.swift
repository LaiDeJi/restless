import ActivityKit
import Foundation
import OSLog

struct RestlessActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: SessionPhase
        var doneSets: Int
        var restKind: RestKind?
        var duration: Int
        var deadline: Date?
        var pausedRemaining: Int
        var setDeadline: Date?
    }

    /// The whole plan, so the widget and the app cannot drift.
    var preset: WorkoutPreset

    /// Movement names by library id. The widget has no SwiftData store, and the
    /// island names the movement, so the names travel with the attributes.
    var movementNames: [UUID: String]

    var presetName: String { preset.name }

    var totalSets: Int { preset.totalSets }

    func position(at doneSets: Int) -> WorkoutPosition { preset.position(at: doneSets) }

    func rest(after doneSets: Int) -> RestOption? { preset.rest(after: doneSets) }

    func movementName(_ id: UUID?) -> String {
        guard let id, let name = movementNames[id] else { return "MOVEMENT" }
        return name.uppercased()
    }
}

extension RestlessActivityAttributes.ContentState {
    init(_ snapshot: SessionSnapshot) {
        self.init(
            phase: snapshot.phase,
            doneSets: snapshot.doneSets,
            restKind: snapshot.restKind,
            duration: snapshot.duration,
            deadline: snapshot.deadline,
            pausedRemaining: snapshot.pausedRemaining,
            setDeadline: snapshot.setDeadline
        )
    }
}

extension RestlessActivityAttributes {
    init(_ snapshot: SessionSnapshot, movementNames: [UUID: String] = [:]) {
        self.init(preset: snapshot.preset, movementNames: movementNames)
    }

    /// Display-only snapshot built from immutable attributes and changing state.
    /// `startedAt` has no meaning in the widget.
    func snapshot(_ state: ContentState) -> SessionSnapshot {
        SessionSnapshot(
            preset: preset,
            doneSets: state.doneSets,
            phase: state.phase,
            restKind: state.restKind,
            duration: state.duration,
            deadline: state.deadline,
            pausedRemaining: state.pausedRemaining,
            setDuration: setDuration(at: state.doneSets),
            setDeadline: state.setDeadline,
            startedAt: .distantPast
        )
    }

    /// The timed set's length comes from the plan; only its deadline is state.
    private func setDuration(at doneSets: Int) -> Int {
        let position = preset.position(at: doneSets)
        guard preset.blocks.indices.contains(position.blockIndex) else { return 0 }
        let block = preset.blocks[position.blockIndex]
        guard block.movements.indices.contains(position.movementIndex) else { return 0 }
        let movement = block.movements[position.movementIndex]
        return movement.endCondition == .time ? (movement.target ?? 0) : 0
    }
}

/// Keeps the Live Activity in step with the session from whichever process made
/// the change: the app itself or an intent tapped on the Lock Screen.
@MainActor
enum LiveActivityCoordinator {
    /// Starts an activity, or refreshes an existing one. A not-started session
    /// must have none: end anything stale and request nothing.
    static func start(_ snapshot: SessionSnapshot, movementNames: [UUID: String] = [:]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if snapshot.phase == .notStarted {
            await endAll()
            return
        }
        guard Activity<RestlessActivityAttributes>.activities.isEmpty else {
            await update(snapshot)
            return
        }
        request(snapshot, movementNames: movementNames)
    }

    /// Attributes are immutable, so a new preset or a renamed movement needs a
    /// new activity.
    static func restart(_ snapshot: SessionSnapshot, movementNames: [UUID: String] = [:]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if snapshot.phase == .notStarted {
            await endAll()
            return
        }
        let activities = Activity<RestlessActivityAttributes>.activities
        guard !activities.isEmpty else {
            request(snapshot, movementNames: movementNames)
            return
        }
        // One activity at a time: several launches can leave stale ones behind.
        if activities.count > 1 {
            await endAll()
            request(snapshot, movementNames: movementNames)
            return
        }
        let attributes = RestlessActivityAttributes(snapshot, movementNames: movementNames)
        let needsRestart = activities.contains { activity in
            activity.attributes.preset != attributes.preset
                || activity.attributes.movementNames != attributes.movementNames
        }
        guard needsRestart else {
            await update(snapshot)
            return
        }
        await endAll()
        request(snapshot, movementNames: movementNames)
    }

    static func update(_ snapshot: SessionSnapshot) async {
        await updateAll(snapshot)
    }

    /// Launch: drop any activity left by an earlier plan shape, then request one
    /// only for a running session.
    static func reset(_ snapshot: SessionSnapshot, movementNames: [UUID: String] = [:]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endAll()
        guard snapshot.phase != .notStarted else { return }
        request(snapshot, movementNames: movementNames)
    }

    static func end() async {
        await endAll()
    }

    private static func request(_ snapshot: SessionSnapshot, movementNames: [UUID: String]) {
        do {
            _ = try Activity.request(
                attributes: RestlessActivityAttributes(snapshot, movementNames: movementNames),
                content: ActivityContent(
                    state: RestlessActivityAttributes.ContentState(snapshot),
                    staleDate: snapshot.deadline ?? snapshot.setDeadline
                ),
                pushType: nil
            )
        } catch {
            Logger(subsystem: "com.whc.restless", category: "session")
                .error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // These run off the main actor so a non-Sendable Activity value never
    // crosses an isolation boundary.
    nonisolated private static func updateAll(_ snapshot: SessionSnapshot) async {
        let state = RestlessActivityAttributes.ContentState(snapshot)
        for activity in Activity<RestlessActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: snapshot.deadline ?? snapshot.setDeadline))
        }
    }

    nonisolated private static func endAll() async {
        for activity in Activity<RestlessActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
