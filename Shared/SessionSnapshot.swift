import Foundation

enum SessionPhase: String, Codable, Hashable, Sendable {
    case notStarted
    case ready
    case performing
    case resting
    case paused
    case done
}

/// The whole live session. Codable so the app and the Live Activity intents can
/// share one source of truth through the App Group.
struct SessionSnapshot: Codable, Hashable, Sendable {
    var preset: WorkoutPreset
    var doneSets: Int
    var phase: SessionPhase
    var restKind: RestKind?
    var duration: Int
    var deadline: Date?
    var pausedRemaining: Int
    /// A timed set's work countdown. Zero outside `performing`.
    var setDuration: Int
    var setDeadline: Date?
    var startedAt: Date

    static func initial(_ preset: WorkoutPreset, now: Date = .now) -> SessionSnapshot {
        SessionSnapshot(
            preset: preset,
            doneSets: 0,
            phase: .notStarted,
            restKind: nil,
            duration: 0,
            deadline: nil,
            pausedRemaining: 0,
            setDuration: 0,
            setDeadline: nil,
            startedAt: now
        )
    }

    var totalSets: Int { preset.totalSets }

    var position: WorkoutPosition { preset.position(at: doneSets) }

    /// The block the current set belongs to. Clamped like `position`.
    var currentBlock: WorkoutBlock {
        let index = min(max(position.blockIndex, 0), preset.blocks.count - 1)
        guard preset.blocks.indices.contains(index) else {
            return .fallback
        }
        return preset.blocks[index]
    }

    /// The block movement for the current set. Clamped like `position`.
    var currentBlockMovement: BlockMovement? {
        let block = currentBlock
        guard !block.movements.isEmpty else { return nil }
        let index = min(max(position.movementIndex, 0), block.movements.count - 1)
        return block.movements[index]
    }

    /// The round and set segments for the current position.
    var roundSetCopy: RoundSetCopy { position.roundSetCopy(in: currentBlock) }

    /// Rest that follows the set now being performed.
    var upcomingRest: RestOption? { preset.rest(after: doneSets) }

    /// The transition of the rest currently running, derived from the set just
    /// finished so the copy and accent need no extra stored state.
    var restTransition: RestTransition? {
        guard phase == .resting || phase == .paused, doneSets > 0 else { return nil }
        return preset.rest(after: doneSets - 1)?.transition
    }

    var isResting: Bool { phase == .resting || phase == .paused }
    var isPerforming: Bool { phase == .performing }
    var isLocked: Bool { isResting || isPerforming }

    /// The timer offers its restart control once at least one set is done and
    /// the session is neither at the gate nor finished. It is a session action,
    /// so a rest or a timed set does not hide it.
    var canRestart: Bool {
        doneSets > 0 && phase != .done && phase != .notStarted
    }

    /// The deadline of a running rest or timed work set, if any. This is the
    /// only countdown that can raise a completion alert.
    var countdownDeadline: Date? {
        switch phase {
        case .resting:
            return deadline
        case .performing:
            return setDeadline
        case .notStarted, .ready, .paused, .done:
            return nil
        }
    }

    func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .resting:
            guard let deadline else { return 0 }
            return max(0, deadline.timeIntervalSince(now))
        case .paused:
            return TimeInterval(pausedRemaining)
        case .notStarted, .ready, .performing, .done:
            return 0
        }
    }

    func setRemaining(at now: Date) -> TimeInterval {
        guard phase == .performing, let setDeadline else { return 0 }
        return max(0, setDeadline.timeIntervalSince(now))
    }

    func progress(at now: Date) -> Double {
        switch phase {
        case .notStarted, .ready:
            return 0
        case .done:
            return 1
        case .paused:
            guard duration > 0 else { return 1 }
            return 1 - Double(pausedRemaining) / Double(duration)
        case .resting:
            guard duration > 0 else { return 0 }
            return min(max(1 - remaining(at: now) / Double(duration), 0), 1)
        case .performing:
            return setProgress(at: now)
        }
    }

    func setProgress(at now: Date) -> Double {
        guard phase == .performing, setDuration > 0 else { return 0 }
        return min(max(1 - setRemaining(at: now) / Double(setDuration), 0), 1)
    }

    /// Ends a rest or a timed set whose deadline has passed. Returns true when
    /// it changed.
    mutating func reconcile(now: Date) -> Bool {
        switch phase {
        case .resting:
            guard let deadline, now >= deadline else { return false }
            finishRest()
            return true
        case .performing:
            guard let setDeadline, now >= setDeadline else { return false }
            setDone(now: now)
            return true
        case .ready, .paused, .done, .notStarted:
            return false
        }
    }

    mutating func finishRest() {
        phase = .ready
        restKind = nil
        duration = 0
        deadline = nil
        pausedRemaining = 0
        setDuration = 0
        setDeadline = nil
    }
}

extension SessionSnapshot {
    /// Enters the normal ready state at the first set without consuming one.
    mutating func startSession() {
        guard phase == .notStarted else { return }
        phase = .ready
        doneSets = 0
        restKind = nil
        duration = 0
        deadline = nil
        pausedRemaining = 0
        setDuration = 0
        setDeadline = nil
    }

    mutating func setDone(now: Date = .now) {
        guard phase == .ready || phase == .performing, doneSets < totalSets else { return }

        setDuration = 0
        setDeadline = nil

        guard let rest = preset.rest(after: doneSets) else {
            doneSets = totalSets
            phase = .done
            restKind = nil
            duration = 0
            deadline = nil
            pausedRemaining = 0
            return
        }

        doneSets += 1

        // A zero set rest never becomes a rest state; the next set is ready.
        guard rest.duration > 0 else {
            phase = .ready
            restKind = nil
            duration = 0
            deadline = nil
            pausedRemaining = 0
            return
        }

        restKind = rest.kind
        duration = rest.duration
        pausedRemaining = rest.duration
        deadline = now.addingTimeInterval(TimeInterval(rest.duration))
        phase = .resting
    }

    mutating func startSet(now: Date = .now) {
        guard phase == .ready else { return }
        guard let blockMovement = currentBlockMovement,
              blockMovement.endCondition == .time,
              let target = blockMovement.target,
              target > 0 else { return }

        phase = .performing
        setDuration = target
        setDeadline = now.addingTimeInterval(TimeInterval(target))
        restKind = nil
        duration = 0
        deadline = nil
        pausedRemaining = 0
    }

    mutating func pause(now: Date = .now) {
        guard phase == .resting else { return }
        pausedRemaining = Int(remaining(at: now).rounded(.up))
        phase = .paused
        deadline = nil
    }

    mutating func resume(now: Date = .now) {
        guard phase == .paused else { return }
        deadline = now.addingTimeInterval(TimeInterval(pausedRemaining))
        phase = .resting
    }

    mutating func skipRest() {
        guard isResting else { return }
        finishRest()
    }

    /// Clears progress. A finished session has nothing to lose, so START AGAIN
    /// starts directly at set 1; a session with progress returns to the gate so
    /// no Live Activity is left running.
    mutating func restart(now: Date = .now) {
        let wasDone = phase == .done
        self = .initial(preset, now: now)
        if wasDone { phase = .ready }
    }

    mutating func replacePreset(_ preset: WorkoutPreset, now: Date = .now) {
        self = .initial(preset, now: now)
    }
}

enum SessionAction: Sendable, Equatable {
    case startSession
    case setDone
    case startSet
    case pause
    case resume
    case skipRest
    case finishRest
    case restart
}

enum SessionTransitions {
    /// Single entry point for every mutation, so the in-app button, the island
    /// link and the URL handler cannot drift apart.
    static func apply(_ action: SessionAction, to snapshot: inout SessionSnapshot, now: Date = .now) {
        _ = snapshot.reconcile(now: now)
        switch action {
        case .startSession: snapshot.startSession()
        case .setDone: snapshot.setDone(now: now)
        case .startSet: snapshot.startSet(now: now)
        case .pause: snapshot.pause(now: now)
        case .resume: snapshot.resume(now: now)
        case .skipRest: snapshot.skipRest()
        case .finishRest: snapshot.finishRest()
        case .restart: snapshot.restart(now: now)
        }
    }
}
