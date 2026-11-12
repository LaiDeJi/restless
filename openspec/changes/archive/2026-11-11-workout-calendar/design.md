# Design

## Context

See `proposal.md` for motivation. The current shape that constrains the work:

- `PresetRecord` stores the ordered sessions in SwiftData, with the manual
  `sortIndex` already persisted. `PresetRepository.ordered` is the one ordering.
- The live session is `SessionSnapshot` in the App Group's `UserDefaults`
  (`restless.session.v5`), replaced by `SessionEngine.use` and by restart. It has
  `startedAt` but no run identifier and no history.
- `SessionEngine` is the only owner of the snapshot; every mutation goes through
  `SessionTransitions.apply`. Deadline completion and island URLs also pass
  through the engine.
- `RootView` has two tabs; `AppRouter` owns the tab and the SESSIONS path.
- `Shared/` is pure model plus ActivityKit; no SwiftData.
- App Groups are not configured, so the widget cannot read history. That is
  acceptable: the widget shows the live session only.
- The visual reference is the study-app calendar screenshot: an inline month
  label, large per-day marks, a full-width action, and sections below the grid.
  It is adapted to Restless's dark surface; the owl and progress pill become the
  session code and the set-map bar.

## Goals / Non-Goals

**Goals:**

- Project the persisted session order onto training days deterministically,
  with no materialized plan rows to keep in sync.
- Record every run from its first completed set, with enough snapshot data to
  survive later session edits and deletes.
- Put the calendar in a third tab without touching the timer, Live Activity,
  alerts or widget.
- Keep the rotation and record rules pure and testable in `Shared`, and the
  SwiftData write behind a small protocol.

**Non-Goals:**

- Manual history entries, per-date swaps or extra sessions, recurring
  exceptions, time-of-day closures.
- Week starts other than Monday and Sunday.
- Editing a record's content, auto-starting a session, or moving a session
  between days by hand.
- History in the widget or Live Activity.
- Changing the live-session storage version or the App Group fallback.

## Decisions

### 1. The rotation is a projection from one anchor

`CalendarSettings` holds `rotationAnchor` (a start-of-day date), the rest
weekdays, the exception ranges and the week start. A date is a training day when
its weekday is not a rest day and it is in no exception range.

For a target day at or after the anchor:

```
index = (training days in [anchor, target)) % sessions.count
plan  = sessions[index]
```

The anchor is also index 0 on the first training day on or after it, so an
anchor that later becomes a rest day still works.

- **Reordering** sets `rotationAnchor` to the next unstarted training day and
  restarts at the first session. "Unstarted" means today has no record and is a
  training day, else the next training day after today.
- **Rest-day and exception edits** keep the anchor. The count of training days
  between the anchor and a target changes, so upcoming days recompute; a session
  is never consumed by a rest or closed day.
- **Adding, deleting and renaming** keep the anchor. Adding changes the modulus,
  so later days may move; deleting removes an index, and its records keep their
  snapshot.
- The anchor is initialized on the first calendar open to today when today is a
  training day with no record, otherwise to the next training day.
- The rotation advances with elapsed training days, even if no session was done.
  A longer break is expressed with an exception range.

Alternatives considered:

- *Materialized plan rows for the next N weeks.* Every settings or order edit
  must rewrite rows, and stale rows are a silent failure. Rejected.
- *Successor of the last record.* A skipped day would not advance the schedule,
  and the reorder boundary would depend on history. Rejected; the spec wants a
  reorder to affect only upcoming days and a plan to exist for a skipped day.
- *One session per weekday slot.* This was the earlier model, but the user's
  rule that reordering the list changes upcoming sessions makes the list the
  program. Weekday slots would need a second source of truth. Rejected.

Past days are never projected: a day before the next unstarted day shows only a
record, or nothing. This is what keeps a reorder from rewriting the past
visually. Rest and closed words are still drawn for past days, because they
describe settings rather than a session.

### 2. Settings live in UserDefaults, history in SwiftData

`CalendarSettings` is one Codable document in `UserDefaults`
(`restless.calendar.v1`), written after each edit. It is small, atomic, app-only
and has no query needs. `WorkoutRecord` is a SwiftData `@Model`, because the
calendar and the day sheet query it by date and it grows over time.

`CalendarSettings` fields:

- `weekStart: Int?` — nil means the device's value, which resolves to Sunday
  only when the device starts on Sunday, otherwise Monday.
- `restWeekdays: Set<Int>` — Calendar weekday numbers, at most six. The setter
  refuses the seventh.
- `exceptions: [ExceptionRange]` — `id`, normalized `startDay` and `endDay`,
  trimmed label. `endDay >= startDay`.
- `rotationAnchor: Date?`.

Alternatives: one SwiftData row for settings (migration and boilerplate for four
scalars), or JSON for history (growth and date queries). Rejected.

### 3. One record per run, keyed by preset and start time

`WorkoutRecord` stores:

- `runKey` (`presetID|startedAt`), unique, to make the island refresh path
  idempotent.
- `presetID`, `sessionName`, `blocksData` (the plan snapshot), `totalSets`.
- `startedAt`, `startDay` (local start of day), `lastActivityAt`, `finishedAt`.
- `doneSets`, `phaseRaw` (the phase at the last change).

`startDay` is stored rather than recomputed, so a record stays on the date it
started even if the timezone changes. The position reached and the set map come
from `doneSets` and the snapshot; no per-set timestamps are stored. A run that
crosses midnight stays on its start date.

Alternative: add a `runID` to `SessionSnapshot`. It would break the v5 Codable
decode or need a custom decoder for no gain; `startedAt` changes on every
`restart` and `use`, so it already separates runs. Two runs in the same second
are not reachable through the UI; the unique key would merge them, which is an
accepted worst case.

### 4. The recorder hangs off the engine's mutation points

`WorkoutHistoryRecording` is a small protocol in `Restless/Session` with
`func record(_ snapshot: SessionSnapshot, now: Date)`. `SessionEngine` gets an
optional recorder and calls it after persistence in:

- `perform` (buttons and island URLs),
- `performDeadline` (ticker-driven rest and timed-set completion),
- `refreshFromStore` (a snapshot changed by the island while away),
- the initial restore after `reconcile`.

The SwiftData implementation upserts by `runKey` only when `doneSets > 0` or a
record already exists. It updates `doneSets`, the phase, `lastActivityAt`, and
sets `finishedAt` once when the phase becomes `done`. It skips the context save
when nothing changed. `use` and `restart` do not delete or finalize a record; the
last state was already written, and the next first set starts a new run key.

Alternatives: writing inside `SessionTransitions` (would drag SwiftData into
`Shared` and mix recording into the pure transition), or a SwiftUI observer
(would miss deadline, restore and URL paths). Rejected.

### 5. The plan snapshot is the record's source of truth

The record encodes `[WorkoutBlock]` with the same JSON approach as
`PresetRecord.blocksData`, plus the name and total. The day sheet reconstructs a
`WorkoutPreset` from that snapshot for display. Renaming or editing the session
later never reaches the record; deleting the session leaves the record with its
name.

### 6. Past days show records, upcoming days show plans

The grid computes one cell per visible date:

- A record wins; the latest record by `startedAt` supplies the code and the set
  bar, and a day with more than one record shows a count.
- A date before the next unstarted day and without a record shows no plan.
- A date at or after the next unstarted day and without a record shows the
  projected plan.
- Rest and closed words are drawn for any date, past or future.
- Adjacent-month dates are muted and inert.

This asymmetry is deliberate: the plan is a future projection, not a claim about
the past. A record with a different session than the day's plan simply replaces
the mark.

### 7. The calendar is a tab with local state, not a router path

`AppTab` gains `.calendar`; `RootView` adds a third tab after SESSIONS. The tab
holds its own `NavigationStack` for the settings screen and a `.sheet(item:)`
for the day sheet. The only shared navigation action is the planned sheet's
START, which calls the engine and `router.showTimer()`.

The month, selected filter and displayed month are view state. The filter is
lost on relaunch, which is appropriate for a view-only control. The month does
not persist either; it opens on the current month.

### 8. START is only in the planned day sheet

The month has no start action. A planned day's sheet shows START:

- If the engine snapshot is at the gate with no completed sets, START activates
  the planned session and opens TIMER.
- If the snapshot has completed sets, or is resting or performing, START opens a
  confirmation naming the sets that would be discarded. Cancel changes nothing.
- A record sheet is read-only; the only action is a two-tap delete of the record.
- A rest or closed day offers no start.

Starting from SESSIONS or TIMER remains possible and is untouched. The calendar
does not auto-activate the next session.

### 9. Order edits write the calendar in one place

`SessionsScreen.persistOrder` is the single commit point for a session drag and
for the accessibility move. After it saves, it resets the anchor to the next
unstarted training day. The reset reads today's records through the same history
store. A cancelled drag never calls it. Adding a session, deleting one, or
renaming one does not reset the anchor.

The calendar itself has no reorder control; the user rearranges in SESSIONS, as
before.

### 10. Typography and layout follow the existing app

The grid uses the existing `Theme` surface: near-black background, white 4%
tiles, the set accent for done, the round accent for planned, and no Liquid
Glass. The day number is the content tier; the session code sits at the 11 pt
floor with tail truncation; the day sheet carries the full name. The whole cell,
not the tile, is the hit target and is at least 44 pt. At accessibility sizes
the grid keeps seven columns and truncates codes; the sheet scales normally.
The settings rows use the same card and chevron language as SESSIONS.

The screen scrolls: header, filter chips, inline month, grid, UP NEXT line, then
the three settings rows. The reference's full-width CTA is deliberately absent.

### 11. The prototype comes first

`prototype-workout-timer.html` gains the CALENDAR tab, the grid states, the day
sheet, the settings screen and the reorder boundary before any Swift change, per
the repository rule. The HTML mockup already discussed is the visual target; the
prototype check runs it headless.

## Risks / Trade-offs

- **A reorder restarts the cycle, which can move more days than the user
  expects.** → The UP NEXT line and the grid update immediately, the action is
  reversible by dragging back, and no record or running session moves. No
  confirmation, because a drag is cheap and frequent.
- **The rotation advances on skipped days.** → Exception ranges pause it; the
  day sheet shows the plan; the calendar does not nag or auto-catch-up.
- **A day done with a different session than planned shows only the record.** →
  The record is the truth; the plan for that date is not presented as missed.
- **Record writes on every state change.** → Only state changes, not ticks; the
  store skips no-op saves. The run key makes repeat paths idempotent.
- **A unique `runKey` collision within one second.** → Not reachable through
  taps; the merge is benign.
- **Date-only values across timezones and DST.** → Normalize to local start of
  day, compare with `Calendar` day equality, and store `startDay` on the record.
  A timezone change can shift a closure by hours but not the stored work dates.
- **A 7-column grid at accessibility sizes truncates codes.** → The day sheet is
  the full view; the 11 pt floor and the cell hit target are preserved.
- **Adding a session changes the modulus without a reset.** → Upcoming days may
  move; this is a recalc, stated in the spec, and the new session appends at the
  end where it enters the cycle last.
- **SwiftData schema addition and rollback.** → The new entity is additive and
  the live-session store is untouched. Test opening the store with the previous
  build; history is not needed by the timer if a rollback hides it.
- **No App Group means no history in the widget.** → Accepted; the widget keeps
  showing the live session only.

## Migration Plan

1. Prototype: add the calendar section to `prototype-workout-timer.html`; verify
   the month, day sheet, settings and reorder states with
   `tools/prototype-check.py`.
2. Add `CalendarSettings`, `ExceptionRange` and the pure rotation projection to
   `Shared`; add tests before wiring UI.
3. Add `WorkoutRecord` to the SwiftData container and the history store; add the
   recorder to `SessionEngine` and its tests.
4. Add the third tab, calendar screen, day sheet and settings screen; wire the
   order reset and the planned START.
5. Add the calendar text floor to the typography check; run SwiftLint and the
   full test suite on `iPhone 18 Pro`.

No data migration is needed for sessions or the live snapshot. The only new
store is the history entity; existing stores open with it as a lightweight
addition. Removing the feature leaves the records in the store and the timer
untouched.

## Open Questions

None that change the specs or the approach. The remaining choices (grid
spacing, the exact UP NEXT copy, and the settings row summaries) are visual and
can be settled in the prototype.
