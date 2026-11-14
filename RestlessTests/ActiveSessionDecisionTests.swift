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

private let chest = preset("Chest")
private let arms = preset("Arms")
private let legs = preset("Legs")

private var armsPlan: RotationSession { RotationSession(id: arms.id, name: arms.name) }

private func atGate(_ session: WorkoutPreset) -> SessionSnapshot {
    .initial(session, now: today)
}

private func withProgress(_ session: WorkoutPreset) -> SessionSnapshot {
    var snapshot = atGate(session)
    snapshot.startSession()
    snapshot.setDone(now: today)
    return snapshot
}

private func done(_ session: WorkoutPreset) -> SessionSnapshot {
    var snapshot = atGate(session)
    snapshot.startSession()
    while snapshot.phase != .done {
        if snapshot.phase == .ready { snapshot.setDone(now: today) }
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
        active: chest,
        activeDay: yesterday,
        plan: armsPlan,
        snapshot: atGate(chest)
    )

    #expect(decision == .switchTo(armsPlan))
}

@Test("The same plan with a stale day only records the day")
func samePlanWithStaleDayRecordsDay() {
    let decision = decide(
        active: chest,
        activeDay: yesterday,
        plan: RotationSession(id: chest.id, name: chest.name),
        snapshot: atGate(chest)
    )

    #expect(decision == .recordDay)
}

@Test("A ready session with no sets and a stale day switches")
func readySessionWithNoSetsSwitches() {
    var snapshot = atGate(chest)
    snapshot.startSession()

    let decision = decide(
        active: chest,
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
        active: chest,
        activeDay: yesterday,
        plan: RotationSession(id: chest.id, name: chest.name),
        snapshot: done(chest)
    )

    #expect(decision == .switchTo(RotationSession(id: chest.id, name: chest.name)))
}

@Test("A day with no plan keeps the session")
func noPlanKeeps() {
    let decision = decide(
        active: chest,
        activeDay: yesterday,
        plan: nil,
        snapshot: atGate(chest)
    )

    #expect(decision == .keep)
}

@Test("A first launch with no marker follows today's plan")
func missingMarkerFollowsThePlan() {
    let decision = decide(
        active: chest,
        activeDay: nil,
        plan: armsPlan,
        snapshot: atGate(chest)
    )

    #expect(decision == .switchTo(armsPlan))
}
