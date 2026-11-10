import Foundation
import Testing
@testable import Restless

private let start = Date(timeIntervalSince1970: 3_000_000)
private let benchID = UUID()

@MainActor
private final class FakeScheduler: CountdownAlertScheduler {
    var authorizationRequests = 0
    var scheduled: [(deadline: Date, alert: CompletionAlert)] = []
    var cancels = 0
    var deadlineCancels: [Date] = []
    var stops = 0

    func requestAuthorizationIfNeeded() async {
        authorizationRequests += 1
    }

    func schedule(deadline: Date, alert: CompletionAlert) async {
        scheduled.append((deadline, alert))
    }

    func cancel() async {
        cancels += 1
    }

    func cancel(deadline: Date) async {
        deadlineCancels.append(deadline)
    }

    func stopAlerting() async {
        stops += 1
    }
}

private func preset() -> WorkoutPreset {
    WorkoutPreset(
        name: "Chest",
        blocks: [
            WorkoutBlock(
                name: "Chest",
                rounds: 4,
                setsPerRound: 4,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: benchID, endCondition: .manual)]
            )
        ]
    )
}

private func resting(now: Date = start) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset(), now: now)
    snapshot.startSession()
    snapshot.setDone(now: now)
    return snapshot
}

private func ready(now: Date = start) -> SessionSnapshot {
    var snapshot = SessionSnapshot.initial(preset(), now: now)
    snapshot.startSession()
    snapshot.doneSets = 1
    return snapshot
}

@MainActor
private final class Recorder {
    var haptics = 0
}

@MainActor
private struct CenterHarness {
    let center: CompletionAlertCenter
    let scheduler: FakeScheduler
    let recorder: Recorder
}

@MainActor
private func makeCenter() -> CenterHarness {
    let scheduler = FakeScheduler()
    let recorder = Recorder()
    let center = CompletionAlertCenter(
        scheduler: scheduler,
        movementNames: { [benchID: "Bench press"] },
        haptic: { recorder.haptics += 1 }
    )
    return CenterHarness(center: center, scheduler: scheduler, recorder: recorder)
}

@MainActor
private func drain() async {
    for _ in 0..<20 {
        await Task.yield()
    }
}

@MainActor
@Test("The first countdown asks for permission once")
func asksPermissionOnce() async {
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.sessionChanged(resting(), isActive: true)
    center.sessionChanged(resting(), isActive: true)
    await drain()
    #expect(scheduler.authorizationRequests == 1)
}

@MainActor
@Test("A foreground rest schedules no system alert")
func foregroundRestIsHapticOnly() async {
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    let recorder = harness.recorder
    center.sessionChanged(resting(), isActive: true)
    await drain()

    #expect(scheduler.scheduled.isEmpty)

    let cancels = scheduler.cancels
    await center.countdownReached(ready(), alert: expectedRestAlert(), isActive: true)
    #expect(recorder.haptics == 1)
    #expect(scheduler.cancels > cancels)
}

@MainActor
@Test("Moving to the background schedules one alert for the deadline")
func backgroundRestSchedules() async {
    let snapshot = resting()
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.sessionChanged(snapshot, isActive: true)
    center.setActive(false, snapshot: snapshot)
    await drain()

    #expect(scheduler.scheduled.count == 1)
    #expect(scheduler.scheduled.first?.deadline == snapshot.deadline)
    #expect(scheduler.scheduled.first?.alert.title == "SET REST OVER")

    // A second change in the background does not re-add it.
    center.sessionChanged(snapshot, isActive: false)
    await drain()
    #expect(scheduler.scheduled.count == 1)
}

@MainActor
@Test("Returning to the app cancels the pending system alert")
func returningCancelsPending() async {
    let snapshot = resting()
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.setActive(false, snapshot: snapshot)
    await drain()
    #expect(scheduler.scheduled.count == 1)

    let before = scheduler.cancels
    center.setActive(true, snapshot: snapshot)
    await drain()
    #expect(scheduler.cancels > before)
}

@MainActor
@Test("Pausing, skipping, and restarting cancel the pending alert")
func transitionsCancelPending() async {
    let snapshot = resting()
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.setActive(false, snapshot: snapshot)
    await drain()
    #expect(scheduler.scheduled.count == 1)

    var paused = snapshot
    paused.pause(now: start)
    let afterSchedule = scheduler.cancels
    center.sessionChanged(paused, isActive: false)
    await drain()
    #expect(scheduler.cancels > afterSchedule)

    var skipped = snapshot
    skipped.finishRest()
    let afterPause = scheduler.cancels
    center.sessionChanged(skipped, isActive: false)
    await drain()
    #expect(scheduler.cancels > afterPause)

    var restarted = snapshot
    restarted.restart(now: start)
    let afterSkip = scheduler.cancels
    center.sessionChanged(restarted, isActive: false)
    await drain()
    #expect(scheduler.cancels > afterSkip)
}

@MainActor
@Test("A zero rest never schedules an alert")
func zeroRestSchedulesNothing() async {
    let zero = WorkoutPreset(
        name: "Zero",
        blocks: [
            WorkoutBlock(
                name: "Zero",
                rounds: 1,
                setsPerRound: 2,
                setRest: 0,
                roundRest: 60,
                movements: [BlockMovement(movementId: benchID, endCondition: .manual)]
            )
        ]
    )
    var snapshot = SessionSnapshot.initial(zero, now: start)
    snapshot.startSession()
    snapshot.setDone(now: start)
    #expect(snapshot.phase == .ready)

    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.setActive(false, snapshot: snapshot)
    await drain()
    #expect(scheduler.scheduled.isEmpty)
}

@MainActor
@Test("A background deadline leaves the notification pending and raises no in-app alert")
func backgroundDeadlineLeavesTheNotification() async {
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    let recorder = harness.recorder
    center.setActive(false, snapshot: resting())
    await drain()
    let cancels = scheduler.cancels

    await center.countdownReached(ready(), alert: expectedRestAlert(), isActive: false)
    await drain()

    #expect(recorder.haptics == 0)
    #expect(scheduler.cancels == cancels)
    #expect(scheduler.scheduled.count == 1)
}

@MainActor
@Test("A background timed set arms the following rest without cancelling the fired alert")
func backgroundTimedSetArmsTheNextRest() async {
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.setActive(false, snapshot: resting())
    await drain()
    let cancels = scheduler.cancels

    let following = resting(now: start.addingTimeInterval(60))
    await center.countdownReached(following, alert: expectedRestAlert(), isActive: false)
    await drain()

    #expect(scheduler.cancels == cancels)
    #expect(scheduler.scheduled.count == 2)
    #expect(scheduler.scheduled.last?.deadline == following.deadline)
}

@MainActor
@Test("A late reconcile raises no second alert")
func lateReconcileIsSilent() async {
    let harness = makeCenter()
    let center = harness.center
    let recorder = harness.recorder
    // The app returns after the rest deadline; the engine reconciles separately.
    center.setActive(true, snapshot: ready())

    #expect(recorder.haptics == 0)
}

@MainActor
@Test("A plan change cancels everything and starts clean")
func cancelAllIsQuiet() async {
    let snapshot = resting()
    let harness = makeCenter()
    let center = harness.center
    let scheduler = harness.scheduler
    center.setActive(false, snapshot: snapshot)
    await drain()

    let before = scheduler.cancels
    center.cancelAll()
    await drain()
    #expect(scheduler.cancels > before)
}

private func expectedRestAlert() -> CompletionAlert {
    CompletionAlert(title: "SET REST OVER", body: "AFTER SET 1 · NEXT ROUND 1 OF 4 · NEXT SET 2 OF 4")
}

@Test("Each deadline gets its own notification identifier")
func notificationIdentifiersArePerDeadline() {
    let first = SystemCountdownAlertScheduler.identifier(for: Date(timeIntervalSince1970: 1_000))
    let second = SystemCountdownAlertScheduler.identifier(for: Date(timeIntervalSince1970: 1_060))

    #expect(first.hasPrefix(SystemCountdownAlertScheduler.notificationPrefix))
    #expect(second.hasPrefix(SystemCountdownAlertScheduler.notificationPrefix))
    #expect(first != second)
}
