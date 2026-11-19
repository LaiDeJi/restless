# Proposal

## Why

The reported bug: "If yesterday's session is Arms and I open this app today, the active session will still be Arms." The timer is supposed to follow today's planned session, and the wiring (launch, foreground, local day change) and the clean-state switch were verified working end-to-end on the simulator. The failing state is a **stale partial session**: a session with completed sets that was left mid-workout on an earlier day and now sits at the gate (`.ready`, not running). `ActiveSessionDecision.isReplaceable` protects *any* session with completed sets, whatever day its progress is from, so yesterday's abandoned workout holds the timer forever — today's plan never activates. Reproduced on the iPhone 18 Pro simulator: yesterday's session at the gate with 3 of 9 sets done, today planned as the next session in the rotation; a cold launch kept the old session active with no day-marker write.

## What Changes

- A not-running session whose progress is from an earlier local day than today becomes replaceable: on launch, foreground and a local day change, today's planned session activates at its start gate, exactly as a done session does today.
- Progress from today keeps its protection: a session the user is actually working through today (backgrounded during a rest, reopened the same day) is never replaced.
- A performing, resting or paused session is never replaced, on any day — unchanged.
- A manual activation still holds for the rest of its day — unchanged.
- Rest, closed, skipped and unplanned days still leave the active session alone — unchanged.
- The abandoned partial run is discarded from the timer when the plan takes over. Nothing is lost from history: a record starts with the first completed set and keeps its own snapshot, so the partial workout stays recorded on its day.
- No new UI, no alert, no prompt: the switch is silent, like every other plan-following switch.

### Assumption recorded

Abandoning a partial session means losing the ability to resume it on a later day. The app has no resume affordance today — the leftover progress is an accident of the protection rule, not a feature — and the report asks for the switch, so the change discards the stale timer state rather than preserving or prompting.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `workout-sessions`: the requirement "The active session follows the calendar day" gains the stale-progress rule — a session at the gate whose completed sets are from an earlier local day yields to today's plan, while same-day progress stays protected.
