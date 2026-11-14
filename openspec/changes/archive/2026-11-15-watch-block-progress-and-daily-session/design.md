# Design

## Context

See `proposal.md` for the motivation. The relevant current state:

- The watch receives the full `SessionSnapshot`, including the preset, through the existing `WatchSessionPayload`. No wire change is needed.
- The watch currently draws a session-wide `WatchSetBar` of up to 24 thin segments. The phone's `SetMap` draws the current block as rows of dots, with a dot cap and a bar fallback.
- The active session is only `ActivePresetStore.id`. There is no date attached. `PresetRepository.seedIfNeeded` restores it at launch, and the editor and calendar day sheet change it on manual activation.
- The calendar plan is `TrainingRotation` over the SESSIONS order. Its anchor is currently initialised only when the CALENDAR screen appears.
- Constraints: `Shared/` stays Foundation-only; the watch target lists its sources explicitly in `project.yml`; every session mutation still goes through `SessionTransitions`; a running session never moves; `engine.use` must not run inside an editing tap handler.

## Goals / Non-Goals

**Goals:**

- Give the wrist one progress form: a continuous bar for the current block, with the block count and the session count.
- Keep the wrist non-interactive beyond its existing actions and free of time.
- Make the active session follow today's planned session without disturbing a running session or a deliberate same-day pick.

**Non-Goals:**

- No dot map, dot cap, or dots-to-bar fallback on the wrist.
- No progress ring on the wrist.
- No change to the phone's existing `SetMap` appearance or limits.
- No change to the calendar projection, its anchor maths, or the rotation order.
- No persistent "override" beyond the current day.
- No new watch payload fields, watch actions, App Group, notifications, or Live Activity behaviour.

## Decisions

### 1. The wrist always uses one current-block bar

Replace `WatchSetBar` with a `WatchBlockBar`:

- a large block count, `5 / 16`, labelled `SETS IN THIS BLOCK`;
- one continuous bar filled to `doneInBlock / block.totalSets`;
- the session-wide `5 OF 24 SETS` line below.

There is no dot map and no fallback. A block with four sets and a block with four hundred sets both use the same bar, so the wrist has exactly one progress form. The bar's accent follows the snapshot, so a round rest is amber exactly like the rest of the watch.

The block count and bar use the current block; the lower count uses the whole session. The two numbers differ in a multi-block session, which is why the labels are explicit rather than just `5 / 16`.

Add one shared helper for the completed sets inside the current block (the prefix sum currently in `SetMap`), for example a `SessionSnapshot` method. The watch uses it; the phone's `SetMap` may adopt it without changing its dots or limits. Do not move `SetMapLayout` or add watch rows: the phone keeps its map, the watch has no use for the row layout.

Alternative considered: a dot map on the watch with a window around the current set for large blocks. Rejected because it either introduces a second form or a windowing rule that hides most of the block. The chosen bar is one form at every size.

Alternative considered: a progress ring. Rejected because it can read as a countdown, and the chosen bar already uses the empty middle without adding a second ring metaphor to the timer.

### 2. Keep the existing wrist hierarchy, change only the progress block

The phase label, movement title, and round/set position line stay. Below them:

- the large block count and `SETS IN THIS BLOCK` label;
- the bar;
- the session count.

The position line already carries `ROUND 2 OF 4 · SET 2 OF 4`, so the bar does not repeat round or set dots. Sizing: about an 8 pt bar, a 26 pt block count, and 7 pt labels. The layout is short enough for the 42 mm screen and leaves the action row at the bottom.

The progress block gets one accessibility element: block count, block total, and session count, for example “5 of 16 sets in this block, 5 of 24 in the session.”

### 3. Decide the date-follow in a pure helper, apply it from the app shell

Add a pure decision in `Shared/` (for example `ActiveSessionDecision`) with these inputs: active preset id, active-day marker, today, today's planned `RotationSession`, the current snapshot, and a calendar. It returns one of:

- `keep` — no plan today, the session has progress, or the day marker is already today;
- `recordDay` — today's plan is already the active session, the session is at the gate with zero sets, and only the day marker is stale, so record the day without resetting;
- `switchTo(plan)` — today's plan differs and the session is safe to replace, or the session is done on a stale day and today's plan must start fresh even when it is the same session.

The app-side follower lives outside `SessionEngine` because it needs SwiftData, the calendar settings, and the active-session store. It:

1. initialises the rotation anchor for today if it is still nil;
2. fetches the ordered presets and resolves today's plan through `TrainingRotation`, including a per-date change;
3. asks the decision;
4. on `switchTo`, sets the active id and day, then calls `engine.use(record.preset)` (the same id is used when a done single-session rotation starts fresh);
5. on `recordDay`, writes only the day marker, because the gate already shows the right plan.

This keeps the engine's narrow role and makes the date rule unit-testable with a fixed calendar.

Alternative considered: put the reconciliation in `CalendarScreen`. Rejected because the timer must follow the plan even if the user never opens CALENDAR.

### 4. Protect progress, and hold a manual pick for the day

The decision only replaces a session when it is not locked and either has no completed sets or is already done:

- `notStarted` with zero sets → replace;
- `ready` with zero sets → replace;
- `done` → replace;
- `performing`, `resting`, `paused`, or any state with completed sets → keep.

A planned session that is already active and at the gate with zero sets records today without calling `engine.use`, so a foreground does not reset the gate. A done session on a stale day does call `engine.use` even when the plan names the same session, so a one-session rotation starts fresh. A day with no plan (rest, closed, skipped, before the anchor) keeps the active session and its state.

`ActivePresetStore` gains a day marker and an `activate(id:on:)` helper that writes the id and today's date together. Back it with a small injectable storage value (defaults suite and keys) behind the existing static facade, so the marker and the follower can be tested in their own suite without touching the live app defaults. The manual call sites adopt it: `USE THIS SESSION` in the editor, the calendar day sheet's `START`, and the fallback after deleting the active session. Editing or restarting the active session does not touch the marker.

The day comparison uses `Calendar.isDate(_:inSameDayAs:)`, so a timezone shift does not spuriously switch. Starting a future day's plan from the calendar still marks today, which means the pick holds for the rest of today; tomorrow follows tomorrow's plan.

Existing installs have no day marker. A missing marker is treated as stale, so the first launch after upgrade follows today's plan. No migration is needed.

### 5. Reconcile from the app shell

`RootView` is the lifecycle hub:

- on first appearance (`.task`);
- when `scenePhase` becomes active, after `engine.refreshFromStore()` so a Live Activity intent is not discarded;
- on `NSCalendarDayChanged` while the app is open;
- on `UIApplication.significantTimeChangeNotification` for a manual clock or timezone change.

The reconciliation is idempotent: the day marker makes repeated foregrounds cheap. A local midnight while the app is suspended is caught by the next foreground; the follower does not need a background task.

Ordering matters: restore the persisted snapshot first, then decide. If the restored session is running, the decision keeps it. If it is done, the decision can move to the new day.

## Risks / Trade-offs

- **The bar shows less structure than dots** → The round and set line above it carries the structure, and the two counts give the exact block and session numbers.
- **A big block count can be mistaken for session progress** → The `SETS IN THIS BLOCK` label sits directly under it, and the session count stays below the bar.
- **A wide bar on a small wrist** → The bar is one line and is shorter than the old segmented bar's text block; verify 42 mm and 46 mm.
- **A surprise reset on foreground** → The decision is limited to zero-progress or done sessions, and a manual pick marks the day. A user who deliberately picks another session that day keeps it.
- **A session that crosses midnight** → It is never replaced while it runs. If it finishes after midnight, the next foreground may move to the new day's plan; the completed run is already recorded in history.
- **`NSCalendarDayChanged` is not guaranteed while suspended** → The foreground reconciliation is the backstop.
- **New persisted day marker** → A missing value means stale, which is the desired first-run behaviour. Removing the behaviour later leaves harmless defaults behind.
- **`engine.use` ends the Live Activity and cancels alerts** → Safe because it only runs for a zero-progress or done session, so no countdown is active. No editing tap calls it.

## Migration Plan

- No database or JSON migration. The active-day key is new; absent means follow today's plan on the next reconciliation.
- Existing sessions, records, rotation settings, and the active preset id are untouched.
- Rollback is a code revert: the old active id remains valid, and an old watch build simply ignores the extra snapshot data it already received. The phone's map and the session JSON are unchanged.

## Open Questions

None.
