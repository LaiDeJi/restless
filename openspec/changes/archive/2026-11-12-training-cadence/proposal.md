# Proposal

## Why

The calendar prescribes rest as a set of weekdays off, but a training program
prescribes a gap between workouts: train, rest N days, train. Users fake that
cadence with three or four rest weekdays, and the shipped model cannot express
"every other day" at all — with no rest weekday every calendar day is a planned
session. Weekday regularity belongs with closures, not with the program's
rhythm.

## What Changes

- Replace the set of rest weekdays with one rest gap: 0–6 days between one
  session and the next. Sessions fall on a fixed cadence of `gap + 1` days from
  the rotation anchor, and the ordered SESSIONS list cycles on those slots.
- A slot day is a training day; every other day shows REST. A skipped session is
  missed, not postponed: the cadence keeps its dates.
- Give exceptions two kinds: a dated range, as today, and a repeating weekday.
  A closed day shows CLOSED and plans no session, but it keeps its slot, so the
  session it would have taken is skipped for that lap.
- Keep two settings rows, REST DAYS (the gap) and EXCEPTIONS. Remove WEEK
  STARTS: the grid follows the device's first weekday, and the round's first
  day is the anchor the user picks, not a week boundary. The six-weekday cap and
  the "one training day must remain" refusal go away; the gap's own 0–6 range
  replaces them.
- Keep the reorder boundary: a reorder restarts the upcoming sequence at the
  first session from the next unstarted training day. Adding, renaming or
  deleting a session and every settings edit keep the anchor.
- Let the day sheet start a new round from any open date **on or after
  today** — never a past date. That date becomes the first session of the order
  and every upcoming slot re-phases around it; records and a session in progress
  are untouched.
- Let a planned date use another exercise without touching the schedule: the
  chosen session replaces the plan on that date only, the slot still consumes
  the session the schedule assigned, and every other date stays where it was. A
  CHANGED mark shows the swap, the picker clears it when the scheduled session is
  chosen, and a new round clears the swaps.
- Let the day sheet skip a planned session. The date shows a skip mark and
  offers no START; the gap, the anchor, the order and every other day stay
  where they are. A skip is reversible and a new round clears the skips.
- **BREAKING**: the stored calendar document moves to v2. Rest weekdays become
  weekday exceptions, the gap starts at 0, the week-start choice is dropped in
  favour of the device's first weekday, and the first cycle after the upgrade
  can shift by one session, because a closed slot now consumes its session where
  a rest weekday paused the order.

## Capabilities

### New Capabilities

None — this change refines an existing capability.

### Modified Capabilities

- `training-calendar`: the projection becomes a fixed cadence with a rest gap;
  rest weekdays are removed in favour of the gap plus weekday exceptions;
  exception ranges generalize to dated or weekly closures; WEEK STARTS is
  removed and the grid follows the device; a planned date can use another
  exercise without moving the schedule; a new round starts only today or later;
  the settings rows change.

## Impact

- `Shared/CalendarSettings.swift`: rest weekdays out, `restDaysBetween`, the
  skipped dates and the per-date exercise changes in, exceptions gain a kind,
  the week start is dropped, a v2 defaults key and the v1 migration.
- `Shared/TrainingRotation.swift`: the projection becomes arithmetic on the
  anchor offset; the boundary is the next open slot without a record; the mark
  gains a skipped case; the round start is an anchor write; a date change
  resolves after the slot and never moves the index.
- `Restless/UI/CalendarSettingsScreens.swift`, `CalendarScreen.swift`,
  `CalendarCopy.swift`, `AppRouter.swift` and `RootView.swift`: the inline gap
  stepper, the two-mode exception editor, the deleted week-start row, screen and
  route, the grid reading the device's first weekday, and the presets passed to
  the exercise picker.
- `Restless/UI/CalendarDaySheet.swift`: the Brief order, the outline plan
  buttons, the CHANGE picker, the CHANGED tag, the record time, the NEXT row,
  and the today-or-later round rule.
- `RestlessTests/`: projection across the gap, a closed slot, a gap edit, the
  reorder boundary, a per-date change, the today-or-later round guard and the v1
  document migration.
- `prototype-workout-timer.html` first, then the Swift, per the repository rule.
- `AGENTS.md` rule 12 and the `training-calendar` purpose; no timer, Live
  Activity, history, alert or widget behaviour changes.
