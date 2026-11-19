# Design

## Context

The day-following pipeline is `RootView` → `ActiveSessionFollower.follow` (launch, foreground, day change) → the pure `ActiveSessionDecision.decide`, which is the only place the replace-or-keep rule lives. The follower, engine activation (`engine.use`), alerts, Live Activity and persistence already work and are wired; the clean-state switch was verified end-to-end on the simulator. The one failing input is a snapshot at the gate (`.ready`) with completed sets: `isReplaceable` returns false for it regardless of the day the progress is from, so an abandoned run holds the timer forever. See proposal.md - Why.

## Goals / Non-Goals

Goals:

- Make the replace-or-keep rule day-aware for progress at the gate: earlier-day progress yields to today's plan, today's progress stays.
- Keep the change inside the pure decision so launch, foreground and day-change switching all pick it up with zero wiring changes.

Non-Goals:

- No prompt, affordance or state to resume an abandoned run on a later day.
- No change to the protection of a performing, resting or paused session, on any day.
- No change to the manual-pick rule, the rest/closed/skipped/unplanned rule, or the day marker's meaning.
- No watch, Live Activity or persistence format changes; they mirror the session the engine already publishes.

## Decisions

### 1. Staleness is the run's start day, not the active-day marker

A session at the gate is stale when the local day of the snapshot's `startedAt` (the instant its first set began) is an earlier day than today. This matches the history rule that a run belongs to its start date, including a run that crosses midnight. Alternatives:

- *The active-day marker* — rejected: it records when the session was chosen, not when the work happened. A session chosen yesterday but first performed today would wrongly count as stale; `startedAt` protects it.
- *A wall-clock age threshold* — rejected: a local-day comparison is the app's existing notion everywhere (markers, calendar projection) and is DST-safe through `Calendar.startOfDay`.

### 2. The rule lives entirely in `ActiveSessionDecision`

`decide` already receives `today`, `calendar` and the full snapshot, so `isReplaceable` needs only its `.notStarted`/`.ready` branch extended: replace when `doneSets == 0` or the run's start day is earlier than today. `.done` keeps replacing on any day; `.performing`, `.resting`, `.paused` keep never replacing. Nothing else in the call chain changes: the follower's `switchTo` path already resets the snapshot, cancels alerts, restarts the Live Activity and writes the marker, so a stale session switching behaves exactly like a finished session switching.

### 3. Same-day protection is decided from the snapshot, not only the marker

The marker-today gate keeps a manual pick for its day, and the start-day rule keeps a mid-workout session that was backgrounded during a rest and reopened the same day (its rest expired while away, so the phase reconciles to `.ready` with progress). Both gates hold; the snapshot check means same-day progress survives even when the marker is stale.

### 4. The abandoned run is discarded, not archived

History records start with the first completed set and keep their own snapshot, so the partial workout is already recorded on its day and is never edited by the timer. When today's plan takes over, `engine.use` simply resets the timer state; no extra persistence, no migration, no new keys. An installed app with a stale session on its timer switches on its next launch, foreground or day change.

## Risks / Trade-offs

- [A run backgrounded mid-rest that crosses midnight is stale next morning] → Accepted, and it is what the report asks for: the next day's timer belongs to the next day's plan. The record of the partial run stays in history.
- [A user returns later the same evening to resume a workout abandoned that morning] → The run is protected: its `startedAt` day is today, so the decision keeps it. Only cross-day abandonment yields.
- [Existing tests stamp `startedAt` with the real clock while `today` is a fixture date] → The follow-up tasks must construct snapshots with a controlled `startedAt` instead of driving the engine with `Date.now`, so each protection test passes for the reason it claims.

## Migration Plan

None. The snapshot format, defaults keys and store shapes are unchanged; a persisted stale session simply becomes replaceable on the first decision after the update. Rollback is reverting the decision change.

## Open Questions

None.
