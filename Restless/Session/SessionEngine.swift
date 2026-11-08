import Foundation
import Observation

@MainActor
@Observable
final class SessionEngine {
    private(set) var snapshot: SessionSnapshot
    private var ticker: Task<Void, Never>?

    /// Movement names for the Live Activity attributes. The engine owns the
    /// session, not the library, so the app supplies the lookup.
    var movementNamesProvider: (() -> [UUID: String])?

    init(preset: WorkoutPreset) {
        if let saved = SessionStore.load(), saved.preset.id == preset.id {
            var restored = saved
            _ = restored.reconcile(now: .now)
            snapshot = restored
        } else {
            snapshot = .initial(preset)
        }
        SessionStore.save(snapshot)
        restartTicker()
        // Read the names when the task runs: the app installs the library
        // provider right after constructing the engine.
        Task { [weak self] in
            guard let self else { return }
            await LiveActivityCoordinator.reset(self.snapshot, movementNames: self.movementNames)
        }
    }

    func perform(_ action: SessionAction) {
        SessionTransitions.apply(action, to: &snapshot)
        persist()
        restartTicker()
    }

    /// Activation lands in the start gate; a direct restart builds the final
    /// ready snapshot before the single persistence pass.
    func use(_ preset: WorkoutPreset, startImmediately: Bool = false) {
        var next = SessionSnapshot.initial(preset)
        if startImmediately { next.startSession() }
        snapshot = next
        SessionStore.save(snapshot)
        restartTicker()
        let names = movementNames
        Task { await LiveActivityCoordinator.restart(snapshot, movementNames: names) }
    }

    /// Picks up changes made by a Live Activity intent while the app was away.
    func refreshFromStore() {
        guard let saved = SessionStore.load() else { return }
        var restored = saved
        _ = restored.reconcile(now: .now)
        guard restored != snapshot else { return }
        snapshot = restored
        SessionStore.save(snapshot)
        restartTicker()
        let names = movementNames
        Task { await LiveActivityCoordinator.start(snapshot, movementNames: names) }
    }

    /// Island and Lock Screen controls open the app on a URL that names the action.
    func handle(_ url: URL) {
        refreshFromStore()
        switch url.host() {
        case "start-session": perform(.startSession)
        case "set-done": perform(.setDone)
        case "start-set": perform(.startSet)
        case "pause": perform(.pause)
        case "resume": perform(.resume)
        case "skip": perform(.skipRest)
        case "restart": perform(.restart)
        default: break
        }
    }

    private func persist() {
        SessionStore.save(snapshot)
        let current = snapshot
        let names = movementNames
        Task { await LiveActivityCoordinator.start(current, movementNames: names) }
    }

    private var movementNames: [UUID: String] {
        movementNamesProvider?() ?? [:]
    }

    private func restartTicker() {
        ticker?.cancel()
        ticker = nil
        guard snapshot.phase == .resting || snapshot.isPerforming else { return }

        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self else { return }

                if self.snapshot.phase == .resting,
                   let deadline = self.snapshot.deadline,
                   Date.now >= deadline {
                    self.perform(.finishRest)
                    return
                }
                if self.snapshot.isPerforming,
                   let setDeadline = self.snapshot.setDeadline,
                   Date.now >= setDeadline {
                    self.perform(.setDone)
                    return
                }
                guard self.snapshot.phase == .resting || self.snapshot.isPerforming else { return }
            }
        }
    }
}
