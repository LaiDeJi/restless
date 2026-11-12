# Proposal

## Why

SESSIONS keeps the plans but not the practice: the app stores only the live
session, and restarting or activating replaces it, so there is no record of what
was done on which day. The manual session order is also inert outside the list,
so the app cannot answer “what is next” or “what did I do last Tuesday”. A
calendar is the missing surface, but it needs a schedule to project and a
history to show.

## What Changes

- Add a third persistent bottom tab, CALENDAR, after SESSIONS.
- Make the persisted SESSIONS order the program: each training day takes the
  next session in the order, cycling. Training days are every day minus the
  configured rest weekdays and exception date ranges.
- A reorder, a rest-day change, or a new exception recalculates the upcoming
  days from the next unstarted day. Every past day and a session already in
  progress keep their record. A reorder restarts the upcoming sequence at the
  top of the new list.
- Rest days are a set of weekdays. Up to six may be set; at least one training
  day must remain. Exception dates are date ranges, consume no session, and
  never rewrite records.
- Add “week starts” as a display setting for the month grid (Monday or Sunday).
  It does not anchor the rotation.
- Record a session when its first set is completed, update the record at every
  state change, and finalize it at DONE. The record keeps its own copy of the
  session's blocks, movements, rounds, sets and rests plus the sets done, the
  position stopped at, the phase, and the start and last-activity times.
- Records are immutable to later session edits and deletes. A record can be
  deleted from its day sheet with the app's two-tap confirmation.
- Draw the month as a quiet grid: a small inline month label, one cell per day
  with the session code and a set bar for recorded days, an amber code for
  planned days, a word for rest and closed days, and a ring for today. Session
  chips filter the grid.
- A day opens a sheet. A planned day offers START, which activates that session
  and opens TIMER at its gate. A recorded day is read-only.
- Put the settings under the grid: week starts, rest days and exception dates.
- **BREAKING** (spec shape): the bottom tab requirement moves from two tabs to
  three, and the manual session order gains scheduling side effects that the
  current requirement explicitly forbids.

## Capabilities

### New Capabilities

- `training-calendar`: the CALENDAR tab, its month grid, session filter, day
  sheet, week-start setting, rest weekdays, exception date ranges, and the
  projection of the ordered session list onto training days.
- `workout-history`: the durable record of a started or finished session, its
  snapshot of the plan, its progress, its immutability, and its deletion.

### Modified Capabilities

- `workout-sessions`: the persistent bottom tabs become three; the manual order
  becomes the rotation source and reordering changes upcoming plans only; a
  deleted session leaves the rotation but not the history.
- `app-typography`: the calendar grid joins the screens that must follow the
  system text size, with its own readable floor and truncation rule.

## Impact

- `Shared/WorkoutPreset.swift`, a new `Shared` rotation/record model, and
  `Shared/Theme.swift` for the grid roles.
- `Restless/Data/` gains a SwiftData record for history; the existing
  `PresetRecord` keeps the order that feeds the rotation.
- `Restless/Session/SessionEngine.swift` gains a recorder hook on every state
  mutation, including deadline reconciliation and refresh from the store.
- `Restless/App/` gains the third tab and its route; `RootView` and `AppRouter`.
- New `Restless/UI/` calendar screen, day sheet, and settings screen.
- `RestlessTests/` for rotation projection, rest days, exceptions, reordering
  boundaries, record capture and record immutability.
- `prototype-workout-timer.html` gains the calendar screen and day sheet before
  the Swift work, per the repository rule.
- No App Group dependency: history lives in the app's own SwiftData store; the
  widget extension does not read it.
- `workout-sessions` and `app-typography` specs are amended; no timer, Live
  Activity, alert or widget behaviour changes.
