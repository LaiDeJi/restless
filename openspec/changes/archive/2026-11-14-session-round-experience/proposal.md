# Proposal

## Why

Three parts of the session loop feel wrong: a new session starts with a
movement the user did not choose, the CALENDAR gap spends rest days between
individual sessions instead of between full rounds, and finishing a session
ends on a static screen with no moment of completion.

## What Changes

- A new session draft SHALL start with one default block that carries no
  movements. It keeps the active block's rounds, sets per round, set rest and
  round rest, but the movement list is empty and the editor asks the user to add
  one. DONE and USE THIS SESSION stay disabled until every block has at least
  one movement, so an empty plan cannot be saved.
- The CALENDAR rest gap SHALL mean rest days between whole session rounds, not
  between two sessions. Within a round, the saved sessions run on consecutive
  days in SESSIONS order; after the last session, the configured number of rest
  days follows before the next round starts. A closed or skipped session day
  still consumes its session for the round. The setting's line becomes BETWEEN
  ROUNDS and its summary becomes "N REST DAYS BETWEEN ROUNDS".
- Finishing a session SHALL play a short celebration on the TIMER screen: a
  confetti burst in the Restless accent colours over the done state, about 2.5
  seconds, non-blocking, once per completion. Reduce Motion replaces the moving
  particles with a brief static accent glow. The celebration adds no sound, no
  extra haptic, no notification and no Live Activity change; a session restored
  as already done at launch does not replay it.

## Capabilities

### New Capabilities

None — the change refines three existing capabilities.

### Modified Capabilities

- `workout-sessions`: a new session draft starts with an empty default block and
  cannot be committed until it has a movement.
- `training-calendar`: the rest gap is applied between full session rounds;
  sessions inside a round run on consecutive days, and the setting's copy names
  rounds.
- `rest-timer`: the done state gains a one-shot celebration that does not alter
  timing, alerts, history or the Live Activity.

## Impact

- `prototype-workout-timer.html` first for the default block, the calendar copy
  and the celebration, then `AGENTS.md` rule 12 and the rest-timer skill.
- `Restless/Session/NewSessionDraft.swift` and `SessionEditorScreen.swift`: the
  empty default block and the disabled commit actions.
- `Shared/TrainingRotation.swift`, `Restless/UI/CalendarCopy.swift`,
  `CalendarScreen.swift` and `CalendarDaySheet.swift`: the round-based
  projection and copy. `CalendarSettings` keeps its stored shape and 0–6 range;
  no data migration.
- `Restless/Session/SessionEngine.swift` and `Restless/UI/TimerScreen.swift`
  with a new celebration view: a completion event and the overlaid effect.
- `RestlessTests/`: new-session draft and commit guards, round-gap projection,
  skip and closure behaviour, and the completion-event trigger.
- `tools/prototype-driver-calendar.js`: the gap and marks it asserts.
