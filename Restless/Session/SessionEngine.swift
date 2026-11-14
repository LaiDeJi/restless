import Foundation
import Observation

@MainActor
@Observable
final class SessionEngine {
    private(set) var snapshot: SessionSnapshot
    /// Bumped once each time a transition enters `done`. The timer uses it to
    /// play the one-shot celebration; it is view state, never persisted, so a
    /// restored done session does not replay the effect.
    private(set) var completionEvent = 0
    private(set) var isActive = true
    private var ticker: Task<Void, Never>?

    /// Movement names for the Live Activity attributes. The engine owns the
    /// session, not the library, so the app supplies the lookup.
    var movementNamesProvider: (() -> [UUID: String])?

    /// The history hook. Installing it records the snapshot the engine restored
    /// (a timed set or rest that expired before launch would otherwise be
    /// missed until the next action) and every later state change.
    @ObservationIgnored var historyRecorder: (any WorkoutHistoryRecording)? {
        didSet { recordHistory() }
    }

    @ObservationIgnored private var alertCenter: CompletionAlertCenter!

    init(preset: WorkoutPreset, scheduler: any CountdownAlertScheduler = NoopCountdownAlertScheduler()) {
        if let saved = SessionStore.load(), saved.preset.id == preset.id {
            var restored = saved
            _ = restored.reconcile(now: .now)
            snapshot = restored
        } else {
            snapshot = .initial(preset)
        }
        alertCenter = CompletionAlertCenter(
            scheduler: scheduler,
            movementNames: { [weak self] in self?.movementNames ?? [:] }
        )
        SessionStore.save(snapshot)
        // No alert may survive a relaunch of a countdown that already ended.
        alertCenter.cancelAll()
        alertCenter.stopAlerting()
        restartTicker()
        // Read the names when the task runs: the app installs the library
        // provider right after constructing the engine.
        Task { [weak self] in
            guard let self else { return }
            await LiveActivityCoordinator.reset(self.snapshot, movementNames: self.movementNames)
        }
    }

    func perform(_ action: SessionAction) {
        let now = Date.now
        let wasDone = snapshot.phase == .done
        SessionTransitions.apply(action, to: &snapshot, now: now)
        noteCompletion(from: wasDone)
        alertCenter.sessionChanged(snapshot, isActive: isActive)
        persist()
        recordHistory(now: now)
        restartTicker()
    }

    /// A deadline transition. The alert centre leaves the notification that is
    /// due now to the system, so this path must not report a session change
    /// that would cancel it.
    private func performDeadline(_ action: SessionAction) {
        let now = Date.now
        let wasDone = snapshot.phase == .done
        SessionTransitions.apply(action, to: &snapshot, now: now)
        noteCompletion(from: wasDone)
        persist()
        recordHistory(now: now)
        restartTicker()
    }

    /// Active, inactive, or background. Leaving the app during a countdown arms
    /// one local notification for its deadline; the system delivers it and the
    /// app does not cancel it while the deadline is reached in the background.
    func setActive(_ active: Bool) {
        isActive = active
        alertCenter.setActive(active, snapshot: snapshot)
    }

    /// Activation and restart land in the start gate: the previous countdown is
    /// cancelled, the activity is ended, and nothing runs until START SESSION.
    func use(_ preset: WorkoutPreset) {
        alertCenter.cancelAll()
        alertCenter.stopAlerting()
        snapshot = SessionSnapshot.initial(preset)
        alertCenter.sessionChanged(snapshot, isActive: isActive)
        SessionStore.save(snapshot)
        restartTicker()
        let names = movementNames
        Task { await LiveActivityCoordinator.restart(snapshot, movementNames: names) }
    }

    /// Picks up changes made by a Live Activity intent while the app was away.
    func refreshFromStore() {
        guard let saved = SessionStore.load() else { return }
        var restored = saved
        let now = Date.now
        _ = restored.reconcile(now: now)
        guard restored != snapshot else { return }
        let wasDone = snapshot.phase == .done
        alertCenter.cancelAll()
        snapshot = restored
        noteCompletion(from: wasDone)
        alertCenter.sessionChanged(snapshot, isActive: isActive)
        SessionStore.save(snapshot)
        recordHistory(now: now)
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

    private func recordHistory(now: Date = .now) {
        historyRecorder?.record(snapshot, now: now)
    }

    /// One event per arrival in done. Initialisation, `use` and `restart` never
    /// pass through here.
    private func noteCompletion(from wasDone: Bool) {
        guard !wasDone, snapshot.phase == .done else { return }
        completionEvent += 1
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
                    self.performDeadline(.finishRest)
                    let alert = CompletionAlertCopy.restFinished(
                        self.snapshot,
                        movementNames: self.movementNames
                    )
                    await self.alertCenter.countdownReached(
                        self.snapshot,
                        alert: alert,
                        isActive: self.isActive
                    )
                    return
                }
                if self.snapshot.isPerforming,
                   let setDeadline = self.snapshot.setDeadline,
                   Date.now >= setDeadline {
                    self.performDeadline(.setDone)
                    let alert = CompletionAlertCopy.workFinished(
                        self.snapshot,
                        movementNames: self.movementNames
                    )
                    await self.alertCenter.countdownReached(
                        self.snapshot,
                        alert: alert,
                        isActive: self.isActive
                    )
                    return
                }
                guard self.snapshot.phase == .resting || self.snapshot.isPerforming else { return }
            }
        }
    }
}
