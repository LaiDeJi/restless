import Foundation
import UIKit

/// Decides whether a countdown should alert, and with which surface. It is the
/// only place that knows the rule; the engine feeds it transitions, scene
/// changes, and deadline completions, and tests feed it a fake scheduler.
@MainActor
final class CompletionAlertCenter {
    private let scheduler: any CountdownAlertScheduler
    private let haptic: () -> Void
    private let movementNames: () -> [UUID: String]

    private var isActive = true
    private var pendingDeadline: Date?
    private var scheduledDeadline: Date?
    private var requestedAuthorization = false
    private var generation = 0

    /// `haptic` defaults to the one phone haptic; tests inject a recorder.
    init(
        scheduler: any CountdownAlertScheduler = NoopCountdownAlertScheduler(),
        movementNames: @escaping () -> [UUID: String],
        haptic: (() -> Void)? = nil
    ) {
        self.scheduler = scheduler
        self.movementNames = movementNames
        self.haptic = haptic ?? { CompletionAlertCenter.systemHaptic() }
    }

    static func systemHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    // MARK: - Engine input

    /// After every transition and after a new session takes over.
    func sessionChanged(_ snapshot: SessionSnapshot, isActive: Bool) {
        reconcile(snapshot, isActive: isActive)
    }

    /// Active, inactive, or background. Returning to the app cancels a pending
    /// notification; leaving it schedules one for a running countdown.
    func setActive(_ active: Bool, snapshot: SessionSnapshot) {
        print("RESTLESSDBG setActive active=\(active) phase=\(snapshot.phase) deadline=\(String(describing: snapshot.countdownDeadline))")
        if active {
            Task { await scheduler.stopAlerting() }
        }
        reconcile(snapshot, isActive: active)
    }

    /// The ticker reached the deadline while the app was executing. In the
    /// foreground the pending notification is cancelled and the haptic fires.
    /// In the background the system owns the already-scheduled notification:
    /// it is left pending, no second surface is raised, and only a following
    /// countdown is armed.
    func countdownReached(
        _ snapshot: SessionSnapshot,
        alert: CompletionAlert,
        isActive: Bool
    ) async {
        self.isActive = isActive
        print("RESTLESSDBG countdownReached active=\(isActive) title=\(alert.title)")

        if isActive {
            generation += 1
            pendingDeadline = nil
            scheduledDeadline = nil
            await scheduler.cancel()
            haptic()
            reconcile(snapshot, isActive: true)
            return
        }

        // Do not cancel the request that is due now. The system delivers it and
        // mirrors it to the watch; the app only arms the next countdown.
        reconcile(snapshot, isActive: false, cancelWhenIdle: false)
    }

    /// A new session, a plan change, a refresh from the store, or launch. No
    /// alert may outlive the countdown it belonged to.
    func cancelAll() {
        generation += 1
        pendingDeadline = nil
        scheduledDeadline = nil
        Task { await scheduler.cancel() }
    }

    /// Launch and activation clear an alert that is already firing.
    func stopAlerting() {
        Task { await scheduler.stopAlerting() }
    }

    // MARK: - Rules

    private func reconcile(
        _ snapshot: SessionSnapshot,
        isActive: Bool,
        cancelWhenIdle: Bool = true
    ) {
        self.isActive = isActive
        generation += 1
        let token = generation
        let deadline = snapshot.countdownDeadline
        pendingDeadline = deadline

        // The first countdown arms the permission prompt, even in the foreground.
        if deadline != nil, !requestedAuthorization {
            requestedAuthorization = true
            Task { await scheduler.requestAuthorizationIfNeeded() }
        }

        guard let deadline else {
            scheduledDeadline = nil
            if cancelWhenIdle {
                Task { await scheduler.cancel() }
            }
            return
        }

        guard !isActive,
              let alert = CompletionAlertCopy.pending(for: snapshot, movementNames: movementNames())
        else {
            print("RESTLESSDBG reconcile no schedule: active=\(isActive) deadline=\(String(describing: deadline))")
            scheduledDeadline = nil
            if cancelWhenIdle || isActive {
                Task { await scheduler.cancel() }
            }
            return
        }

        // Already armed for this exact deadline; do not cancel and re-add it.
        if scheduledDeadline == deadline { return }

        print("RESTLESSDBG reconcile scheduling \(alert.title) for \(deadline)")
        Task { [weak self] in
            guard let self else { return }
            await self.scheduler.schedule(deadline: deadline, alert: alert)
            guard token == self.generation else {
                await self.scheduler.cancel(deadline: deadline)
                return
            }
            self.scheduledDeadline = deadline
        }
    }
}
