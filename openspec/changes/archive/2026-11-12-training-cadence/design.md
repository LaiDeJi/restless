# Design

## Context

See `proposal.md` for motivation and the spec delta for requirements. The
shipped shape that constrains the work:

- `CalendarSettings` holds `weekStart`, `restWeekdays`, `exceptions` and
  `rotationAnchor` in one v1 `UserDefaults` document; this change drops the
  first two fields.
- `ExceptionRange` is start/end/label only, and `CalendarSettings.isTrainingDay`
  means "not a rest weekday and not closed".
- `TrainingRotation` counts training days from the anchor and maps the count
  modulo the session list; the count is what consumes a session.
- `CalendarSettingsModel` is the single observable copy the calendar, the day
  sheet and the SESSIONS reorder write through.
- The day sheet takes a `TrainingDayMark` and a plan preset, and owns START.
- The history record's `startDay` is the local start of day; records are keyed by
  run, not by the plan.

## Goals / Non-Goals

**Goals:**

- Replace the weekday rest model with a cadence whose projection is closed-form
  arithmetic on the anchor and the gap, with no materialized rows or walking
  counts.
- Keep one way to re-phase the order: the anchor write, shared by the SESSIONS
  reorder and the new-round action.
- Make a skip a date mark that cannot move the order, the anchor or a record.
- Migrate a v1 document without losing its exceptions or anchor, and without
  breaking rollback to a v1 build.

**Non-Goals:**

- Editing or deleting a record from the new actions; history stays immutable.
- Activating a session from the new-round action; START stays the only
  activation.
- Per-session gaps, half-day closures, or a gap longer than six days.
- Changing the timer, Live Activity, alerts, widget or the history entity.

## Decisions

### 1. The cadence is arithmetic, not a training-day count

```
offset = localDays(from: anchor, to: day)      // whole days, DST-safe
slot   = offset % (restGap + 1) == 0
index  = offset / (restGap + 1) % sessions.count
```

A day is a slot or it is not; a slot is a session day unless an exception covers
it. Because the index comes from the offset and not from "training days so far",
a closed slot keeps its index and the session it would have taken is dropped.
That is the chosen exception rule, and it costs no state: the same day always
projects the same way for the same anchor, gap, order and exceptions.

`trainingDayCount` and `CalendarSettings.nextTrainingDay` are deleted. The
lookahead that the old code needed to find a training day disappears except in
`nextUnstartedDay`, which walks at most a few slots.

Alternatives considered: keeping a walked "consumed" counter with a paused
schedule (the shipped model, rejected because the user chose a fixed cadence and
dropped closures), and materializing sessions per date (rejected in the archived
change for the same reasons: stale rows and rewrite cost).

### 2. Rest gap and exceptions are settings; skips are marks

`CalendarSettings` v2:

- `restDaysBetween: Int` 0...6, clamped by the setter; `restWeekdays` is gone.
  `weekStart` is gone too: the grid and the weekday row read
  `Calendar.current.firstWeekday` directly, which is the old default without the
  override.
- `exceptions: [CalendarException]`, where
  `CalendarException.Kind` is `.dates(startDay:endDay:)` or `.weekday(Int)`.
  `endDay >= startDay`; dated ranges may overlap; a weekday appears once.
  `exception(containing:)` prefers a dated range over a weekday when both cover
  the date.
- `skippedDays: Set<Date>`, normalized to local start of day.
- `dayChanges: [DayChange]`, each a local day and a session id, at most one per
  day. Changes before today are dropped when the document is saved.
- `rotationAnchor: Date?` unchanged.

A skip is a date fact, not a schedule mutation: the cadence already advances
through the slot, so "skip" only means "do not show this plan and do not offer
START on this date". Nothing else can move, which is what makes the skip safe
and cheap. A change of exercise is a date fact for the same reason: the slot's
index stays the schedule's, and the change only replaces the session drawn on
that date.

Document key `restless.calendar.v2`. `load()` tries v2, then decodes v1 through a
private legacy struct and migrates: the anchor is kept, each rest weekday
becomes a weekday exception, the week start is dropped, `restDaysBetween = 0`,
with skips and changes empty. It saves v2 on migration. v1 is left in place so a
rollback build still reads its own document. The v2 writer never touches v1
again.

Alternatives: bumping v1 in place with a tolerant decoder (a v1 build would then
fail to decode and fall back to defaults, losing settings on rollback), or
discarding calendar settings (loses closures and the anchor). Rejected.

### 3. The anchor is the one re-phase primitive

`setRotationAnchor` already exists. Two callers now use it:

- **SESSIONS reorder** → `nextUnstartedDay`: the first open slot at or after
  today that has no record and is not skipped. Restarts at the first session.
- **Day sheet new round** → the selected date, if it is not closed and is today
  or later. The date becomes slot 0 even when it was a rest day; skips and
  per-date changes are cleared; the order restarts at session 1. A past date is
  not a round start and the sheet does not offer it.

Initialization sets the anchor to today when today is open, else the next open
day, and does not consult records: a record on today is simply today's slot 0
with the record drawn over it.

A new round never activates a session, never deletes a record and never touches
the engine snapshot. If a session is running, it keeps running and its record
keeps its date. No confirmation is needed because nothing is lost; the sheet
updates in place to show the new session for that date.

Alternatives: a separate `roundStart` field alongside the anchor (two sources of
truth for slot 0), and rewriting every planned day as a stored row (rejected in
decision 1).

### 4. A change of exercise is a date override

`TrainingRotation.plan(for:)` computes the schedule's slot and index as before.
Only after it has the scheduled session does it look up `dayChanges` for that
date and, if the stored preset still exists, return that session instead. The
index is never recomputed, so the slot still consumes the scheduled session:
changing Saturday's Arms to Chest leaves the next slot on Legs, exactly where the
schedule put it.

The change is a projection input, not a stored plan row: the grid draws the
chosen code, the sheet draws the chosen preset with a CHANGED tag, and UP NEXT
and START use the same resolution. Picking the scheduled session removes the
entry, which is how the picker resets; the picker tags that row from
`scheduledPlan(for:)`, the same slot resolved without the change. A deleted
chosen preset falls back to the schedule. A skip does not clear the change; a new
round clears every change.

Alternatives: rewriting the order or moving the session to another date (that
shifts every later date, which is the one thing the user asked not to happen), or
storing a full preset copy per date (the record already snapshots history; a plan
change only needs the id). Rejected.

### 5. Marks keep the record-first precedence

`TrainingDayMark` gains `.skipped`. `mark(for:boundary:)` becomes:

1. a covering exception → `.closed(label)`
2. a skipped date → `.skipped`
3. no boundary, or before it → `.none`
4. not a slot → `.rest`
5. otherwise → `.planned`

Exceptions and skips are explicit user marks, so they draw on any date: a
closure the user made still explains last Sunday, and a skip is a fact about
that date. Rest and plan are derived from the anchor and gap, so they start at
the boundary; starting a round therefore never repaints the past with someone
else's rhythm. With no anchor yet, every day is `.none`.

A record is still applied by the grid above the mark, so a skipped date that
somehow gained a record shows the record and the skip stays dormant.

The boundary is the `nextUnstartedDay` defined in decision 3. Past open slots do
not draw plans, and past gap days do not draw REST; past closures still draw
their words, as before.

### 6. The day sheet leads with the action

The sheet reads as: what the date is, the action, then the detail.

- A planned day: date kicker, session title, the blocks/sets/rest summary, START,
  then each block with its rounds, sets and set/round rests, then a footer with
  CHANGE, SKIP and NEW ROUND. The three plan edits are outline buttons under a
  hairline, never beside START and never filled. CHANGE opens a picker of the
  ordered sessions; the scheduled row is tagged SCHEDULED, the current choice is
  checked, picking one writes that date's change and picking the scheduled row
  clears it.
- A planned day with a change: the chosen preset's title with a CHANGED tag, and
  that preset's summary and blocks. The next date is exactly where it was.
- A skipped day: the session title with a SKIPPED tag, the summary, NEXT, then
  UNSKIP and, when the date is today or later, NEW ROUND in the same footer.
- A rest day: REST DAY, the current gap in days, NEXT, and only NEW ROUND when
  the date is today or later, with the line that it makes this date session 1.
- A date before the boundary with no record: NO RECORD, one line, NEXT, and NEW
  ROUND only when the date is today or later.
- A recorded day: the session title with a RECORDED tag, a card with the start
  time, the duration when finished, the sets done, the snapshot blocks and the
  phase, then NEXT, then DELETE RECORD (two taps) and, on today or later, NEW
  ROUND in the footer. Two records stack under 2 RECORDS. The card is read-only;
  the round action is outside it.
- A closed day: the label with its recurrence, NEXT, and no action.

NEXT is the next planned session after the date, or the calendar's UP NEXT when
the date is in the past. It appears only on a date without a START, so a planned
day does not repeat the calendar's line.

At accessibility sizes the three footer buttons stack instead of shrinking. The
picker is a sheet titled CHANGE EXERCISE with the date under it and the ordered
sessions as rows; the choice is a single tap and is reversible by picking the
scheduled row.

START keeps its overwrite confirmation. CHANGE, SKIP, UNSKIP and NEW ROUND are
single tap: they are reversible, and none of them can discard a set. The sheet
reads the shared `CalendarSettingsModel` for the plan writes, receives the ordered
presets for the picker, and keeps its existing START path through the engine.

### 7. Settings change shape

`RestDaysEditorScreen` is deleted. One number does not earn a full page, so the
REST DAYS row carries the control itself: label REST DAYS, the line BETWEEN
SESSIONS, and an inline `−` / value / `+` clamped to 0...6 with 44 pt targets.
The route case goes with the screen. The model gets `setRestGap`. EXCEPTIONS
keeps its screen; the WEEK STARTS row, its screen and its route case are deleted,
and `CalendarScreen` reads `Calendar.current.firstWeekday` for the weekday row
and the leading offset. The archived spec's manual override was a display
preference the device default already covers.

`ExceptionDatesScreen` becomes `ExceptionsScreen`: the list shows both kinds with
their label and dates or weekday, and the add form has a DATES / WEEKDAY mode
control. DATES keeps start, end and label; WEEKDAY picks one weekday and a label.
A duplicate weekday is refused with a note, as an end before the start already
is. Removing a row is unchanged.

`CalendarCopy.restDaysSummary` and `orderedWeekdays` are deleted with the weekday
model; the REST DAYS row pairs the line BETWEEN SESSIONS with the stepper value.
The day sheet notes stop saying "do not advance the rotation" and say a closed
day skips that session instead.

### 8. Prototype first, with assertions

`prototype-workout-timer.html` gets the gap, the dropped-slot rule, the skip mark,
the change picker and the day-sheet order before the Swift work.
`tools/prototype-driver-calendar.js` asserts: a gap of 1 leaves alternating REST;
a closed slot shows CLOSED and the next open day carries the following session;
SKIP hides a planned day and leaves the next day's code; NEW ROUND from a rest day
makes it the first session and moves the following codes; a change of exercise
keeps the next day's code; a past date offers no NEW ROUND.

## Risks / Trade-offs

- **A fixed cadence can schedule a session a day after a late one.** → The user
  chose the fixed cadence; the new-round action re-phases from any open date in
  one tap, and the calendar never silently moves a plan.
- **A closure drops the sessions inside it, and a long closure drops several.**
  → Same choice; the day sheet shows CLOSED, the round action re-aligns on
  return, and no record is touched.
- **A six-day gap with a weekday closure on the anchor's weekday plans nothing.**
  → The grid is all CLOSED and UP NEXT is empty; starting a round on the one open
  weekday, lowering the gap, or removing the weekday restores a plan. No silent
  data loss, so no extra guard.
- **Most cells become REST at a small gap.** → The word is muted and the session
  codes carry the accent; the prototype check shows the density before Swift.
- **The v1 migration shifts the first cycle by one session.** → Stated in the
  spec's migration; the round action fixes the phase, and v1 stays readable for a
  rollback.
- **A skipped date can stop being a slot after a gap edit.** → The skip still
  draws, because it is an explicit fact about that date; a new round clears all
  skips, and a record outranks the mark.
- **A past date can no longer start a round.** → The past is fixed on purpose;
  the per-date change is the tool for a single date, and a round can only move
  today or later.
- **A change on a date with a running session changes the plan, not the live
  session.** → The engine is untouched; the sheet's START still asks before it
  clears another session's sets.
- **The chosen session is deleted.** → The date falls back to the schedule and
  the CHANGED tag disappears; the entry stays inert until a new round or another
  choice clears it.
- **A new round clears deliberate date changes.** → Stated in the spec; the round
  is the explicit reset of the whole cadence, and a change is one tap to redo.
- **Three footer buttons at accessibility sizes.** → They stack instead of
  shrinking, keeping the 44 pt targets.

## Migration Plan

1. Prototype: gap, dropped slot, skip, round action, change picker and the past
   restriction; run the driver.
2. `Shared/CalendarSettings.swift` v2 plus `CalendarException` and the v1 decode;
   tests before any UI.
3. `Shared/TrainingRotation.swift` arithmetic, boundary, `.skipped`, round start
   and the date change resolution; tests.
4. `CalendarSettingsModel` methods; then the two settings controls, the grid mark,
   the three-button footer and the picker.
5. `AGENTS.md` rule 12 and the calendar copy; run SwiftLint and the full suite.
6. Open the simulator store written by the shipped build and confirm the v1
   document migrates: the anchor is kept, each rest weekday appears as a weekday
   closure, the week start is ignored, and the gap is 0.

No entity or live-session change. Rollback: the v1 document and the old record
schema are untouched; the history entity is unchanged.
