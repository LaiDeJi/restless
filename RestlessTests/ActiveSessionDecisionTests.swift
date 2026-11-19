import Foundation
import Testing
@testable import Restless

private let today = TestCalendar.day(2026, 11, 15)
private let yesterday = TestCalendar.day(2026, 11, 14)
private let calendar = TestCalendar.calendar

private func preset(_ name: String) -> WorkoutPreset {
    WorkoutPreset(
        name: name,
        blocks: [
            WorkoutBlock(
                name: name,
                rounds: 1,
                setsPerRound: 3,
                setRest: 60,
                roundRest: 120,
                movements: [BlockMovement(movementId: UUID(), endCondition: .manual)]
            )
        ]
    )
}

private let push = preset("Push")
private let arms = preset("Arms")
private let legs = preset("Legs")

private var armsPlan: RotationSession { RotationSession(id: arms.id, name: arms.name) }

private func atGate(_ session: WorkoutPreset, started: Date = today) -> SessionSnapshot {
    .initial(session, now: started)
}

private func withProgress(_ session: WorkoutPreset, started: Date = today) -> SessionSnapshot {
    var snapshot = atGate(session, started: started)
    snapshot.startSession()
    snapshot.setDone(now: started)
    return snapshot
}

/// A session left mid-workout: progress is kept, but the rest ran out while
/// the app was away, so it sits at the gate.
private func withProgressAtGate(_ session: WorkoutPreset, started: Date) -> SessionSnapshot {
    var snapshot = withProgress(session, started: started)
    snapshot.finishRest()
    return snapshot
}

private func done(_ session: WorkoutPreset, started: Date = today) -> SessionSnapshot {
    var snapshot = atGate(session, started: started)
    snapshot.startSession()
    while snapshot.phase != .done {
        if snapshot.phase == .ready { snapshot.setDone(now: started) }
        if snapshot.phase == .resting { snapshot.finishRest() }
    }
    return snapshot
}

private func decide(
    active: WorkoutPreset,
    activeDay: Date?,
    plan: RotationSession?,
    snapshot: SessionSnapshot
) -> ActiveSessionDecision {
    ActiveSessionDecision.decide(
        activeID: active.id,
        activeDay: activeDay,
        today: today,
        plan: plan,
        snapshot: snapshot,
        calendar: calendar
    )
}

@Test("A stale day at the gate switches to today's plan")
func staleDayAtGateSwitches() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: atGate(push)
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("A stale partial session at the gate yields to today's plan")
func stalePartialSessionAtGateSwitches() {
    let snapshot = withProgressAtGate(push, started: yesterday)
    #expect(snapshot.phase == .ready)
    #expect(snapshot.doneSets == 1)

    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: snapshot
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("Progress from today at the gate keeps the session")
func todayProgressAtGateIsProtected() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: withProgressAtGate(push, started: today)
    )

    #expect(decision == .keep)
}

@Test("The same plan with a stale partial session starts fresh")
func samePlanWithStalePartialSessionStartsFresh() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: RotationSession(id: push.id, name: push.name),
        snapshot: withProgressAtGate(push, started: yesterday)
    )

    #expect(decision == .switchTo(RotationSession(id: push.id, name: push.name)))
}

@Test("The same plan with progress from today keeps the session")
func samePlanWithTodayProgressKeeps() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: RotationSession(id: push.id, name: push.name),
        snapshot: withProgressAtGate(push, started: today)
    )

    #expect(decision == .keep)
}

@Test("The same plan with a stale day only records the day")
func samePlanWithStaleDayRecordsDay() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: RotationSession(id: push.id, name: push.name),
        snapshot: atGate(push)
    )

    #expect(decision == .recordDay)
}

@Test("A ready session with no sets and a stale day switches")
func readySessionWithNoSetsSwitches() {
    var snapshot = atGate(push)
    snapshot.startSession()

    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: snapshot
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("The current day keeps the active session, even when it differs from the plan")
func currentDayKeeps() {
    let decision = decide(
        active: legs,
        activeDay: today,
        plan: armsPlan,
        snapshot: atGate(legs)
    )

    #expect(decision == .keep)
}

@Test("A running rest with progress is never replaced")
func runningRestIsProtected() {
    let decision = decide(
        active: legs,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: withProgress(legs)
    )

    #expect(decision == .keep)
}

@Test("A paused session with progress is never replaced")
func pausedSessionIsProtected() {
    var snapshot = withProgress(legs)
    snapshot.pause(now: today)

    let decision = decide(
        active: legs,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: snapshot
    )

    #expect(decision == .keep)
}

@Test("A performing, resting or paused session from an earlier day is never replaced")
func earlierDayRunningSessionIsProtected() {
    let resting = withProgress(push, started: yesterday)
    #expect(resting.phase == .resting)

    var paused = resting
    paused.pause(now: yesterday.addingTimeInterval(30))
    #expect(paused.phase == .paused)

    var performing = resting
    performing.phase = .performing
    performing.setDuration = 60
    performing.setDeadline = yesterday.addingTimeInterval(60)

    for snapshot in [resting, paused, performing] {
        let decision = decide(
            active: push,
            activeDay: yesterday,
            plan: armsPlan,
            snapshot: snapshot
        )
        #expect(decision == .keep, "\(snapshot.phase) from an earlier day must be kept")
    }
}

@Test("A done session from an earlier day yields to today's plan")
func earlierDayDoneSessionSwitches() {
    let decision = decide(
        active: legs,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: done(legs, started: yesterday)
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("A done session yields to the new day's plan")
func doneSessionWithAnotherPlanSwitches() {
    let decision = decide(
        active: legs,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: done(legs)
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("A done single-session rotation starts fresh")
func doneSingleSessionRotationStartsFresh() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: RotationSession(id: push.id, name: push.name),
        snapshot: done(push)
    )

    #expect(decision == .switchTo(RotationSession(id: push.id, name: push.name)))
}

@Test("A day with no plan keeps the session")
func noPlanKeeps() {
    let decision = decide(
        active: push,
        activeDay: yesterday,
        plan: nil,
        snapshot: atGate(push)
    )

    #expect(decision == .keep)
}

@Test("A first launch with no marker follows today's plan")
func missingMarkerFollowsThePlan() {
    let decision = decide(
        active: push,
        activeDay: nil,
        plan: armsPlan,
        snapshot: atGate(push)
    )

    #expect(decision == .switchTo(armsPlan))
}
