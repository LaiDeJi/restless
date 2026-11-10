# Design

## Context

See `proposal.md` for motivation. The current app has three set-end conditions, a watch app that captures motion traces and counts reps, a phone recording flow that derives a profile, and a curl lab. The Live Activity and session store already carry the whole `WorkoutPreset`, so a removed end condition can appear in three persisted shapes: `PresetRecord.blocksData`, the legacy `partsData`/single-part columns, and the saved `SessionSnapshot` in `SessionStore`. The movement record is SwiftData with no versioned schema or migration plan, and the app opens its store with `fatalError` on failure.

## Goals / Non-Goals

**Goals:**

- Remove every user-visible and runtime path for recording, deriving, storing, or applying a movement profile.
- Remove the watch app and every app-level watch message, so the iPhone app owns the whole timer.
- Keep saved sessions usable: blocks, movement order, rounds, sets, rests, and names survive the update.
- Keep the movement library useful as a reusable name list.
- Leave one completion-alert path: a phone haptic in the foreground and one local notification in the background.

**Non-Goals:**

- Do not redesign the timer, session editor, set map, Live Activity, or rest timing.
- Do not remove the movement library or typed movement creation.
- Do not drop the legacy SwiftData profile columns or the other legacy movement columns in this change.
- Do not add an export, backup, or replacement for recorded profiles.
- Do not change the notification permission flow or the OS mirroring of local notifications.

## Decisions

### 1. Delete the watch target and the watch link at the project boundary

Remove `RestlessWatch/`, the `RestlessWatch` target and scheme, the embed dependency, the watchOS deployment target, the watch permission copy, and `RestlessWatch` from the SwiftLint include list. The iPhone app no longer creates a `WatchLink`, activates a `WCSession`, or exposes `WatchLink` in the environment.

Alternative considered: keep the watch app for alert haptics only. Rejected: it would retain a watch target, motion/HealthKit permissions, and a message protocol for one optional haptic, while the OS already mirrors background notifications. The phone haptic remains the foreground guarantee.

Remove `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` with the watch app. They exist only so the curl CSV can appear in the Files app; no other feature writes to `Documents`.

### 2. Make `MANUAL` and `TIME` the only end conditions, with a decode bridge

`EndCondition` keeps only `manual` and `time`. `editorOrder` becomes `[.manual, .time]`. `BlockMovement.isCounted`, `requiresWatchProfile`, and the rep-target branch disappear.

`EndCondition` gets an explicit `Codable` implementation that reads the stored string and maps `"manual"` and `"time"` normally, `"reps"` to `.manual`, and any other unknown value to `.manual`. `BlockMovement.init(from:)` already clamps a target through `EndCondition.clampedTarget`; with a manual condition the stored target becomes `nil`. Encoding writes only `manual` or `time`.

This bridge is the single migration point for every stored plan shape. A throw in `BlockMovement` would make `PresetRecord.blocks` fall back to the old parts/columns and would make `SessionStore.load()` silently return `nil`, so the decoder must be total rather than throwing.

Alternative considered: keep a dormant `reps` case and hide it from the UI. Rejected: it leaves rep targets, watch paths, and a "counted" concept in the domain model, and every future switch would have to decide what to do with it.

### 3. Make the library name-only and leave the legacy columns dormant

`Movement` loses `profile`. `MovementRecord.movement` builds a `Movement` from id and name only. `MovementRepository.reRecord` is deleted. `MovementRecord` keeps `axisRaw`, `rise`, `fall`, and `minPeriod` as old storage columns, but nothing reads or writes them; new records store nil/zero. This matches the existing treatment of the unused muscle-group and default-condition columns and avoids a SwiftData schema migration with no versioned schema.

Alternative considered: remove the four attributes from the `@Model`. Rejected for this change: the app opens the store with `fatalError`, there is no migration plan to test against a real old store, and the columns are invisible to users. Dropping them can be a separate schema change after a verified store migration exists.

`MOVEMENTS` keeps its list, rename, usage, and delete behavior. It loses the header `+`, the `+ RECORD MOVEMENT` row, the recording sheet, the re-record button, and all profile copy. Movement creation remains in the add-movement picker, which creates or reuses a typed name. The library screen explains that path when empty. `BlockLibrarySection` keeps the one-tap add but replaces the profile tag with `MANUAL`. The sessions library card no longer says movements are recorded on the watch.

Alternative considered: remove the MOVEMENTS screen too and manage names only from the picker. Rejected: the library is still used for one-tap adds and used-movement delete protection, so a browse/rename/delete screen is still valuable.

### 4. Remove the watch strip and its layout role

`TimerScreen` no longer reads `WatchLink`, renders the `WATCH ARMED` / `WATCH UNAVAILABLE` strip, or arms on a ready set. `TimerStageRole.watch`, `TimerStageMetrics.watchHeight`, `watchTopY`, and the placement branch are removed. The actions follow the set map at the same gap the watch strip used to occupy; the ring still keeps its one fixed centre and the page still scrolls when needed.

Alternative considered: keep the layout role with a permanent zero height. Rejected: it leaves dead layout API and a test that can never exercise a real state.

`SetMap` and its presentation are untouched. The round-labelled dot grid, the progress-bar fallback, and the `n OF m SETS` caption stay exactly as they are; only the watch row below the map is removed. The before/after mockup is schematic about the map and is not a layout proposal.

The change is visual subtraction, so the prototype is updated first: remove the watch strip, watch simulation buttons, recording route and screens, profile grids and traces, and the REPS segment from the add-movement controls. Keep the timer, sessions, block editor, movement library, and add-movement picker with MANUAL/TIME. Check the prototype with `python3 tools/prototype-check.py` before touching Swift.

### 5. Remove the watch alert hook, keep the phone and notification paths

`CompletionAlertCenter` loses its `watchAlert` closure. `SessionEngine.foregroundWatchAlert` and the `RootView` wiring are deleted. The foreground path still calls the phone haptic exactly once; the background path still schedules one local notification and leaves it for the system. `CountdownAlertScheduler`'s comment is reworded to describe OS mirroring without an app message.

Alternative considered: send the alert through a generic notification bus. Rejected: there is no watch app to receive it, and inventing a second surface adds no user value.

### 6. Test the migration at the model boundary, not through the UI

Add regression tests that decode a `BlockMovement` with `"endCondition":"reps"` and target 10 as `.manual` with `nil` target, that a stored session with a REPS row in a later block keeps every block and order, and that a stored `SessionSnapshot` with a REPS row loads. Delete the five watch/recording test files and update the test fixtures that used `.reps` to use `.time` or `.manual`. The timer layout tests lose the watch-height cases and gain the actions-below-map placement.

## Risks / Trade-offs

- **A stored REPS row fails to decode and the plan silently falls back** → `EndCondition` decodes every string, mapping unknown values to `.manual`; tests cover `blocksData`, a multi-block plan, and a running snapshot.
- **Removing a SwiftData attribute breaks an existing store** → keep the profile columns dormant; the model's visible fields and relationships stay unchanged this change.
- **Users lose rep counting and recorded profiles** → this is the requested scope; existing sets remain usable as MANUAL, and no recording prompt or stale watch state remains.
- **Old watch build and derived data linger on simulators/devices** → run `xcodegen generate`, clean old watch build products, and verify the installed app has no `Watch/` bundle or watch target.
- **Removing the file-sharing keys hides old curl CSVs in Files** → accepted; the curl lab and its CSV writer are removed, and no app feature reads `Documents`.
- **Coordinate-based e2e steps drift when the third end-condition segment disappears** → re-record or re-verify the affected picker steps after the UI change; update the session-start fixture selector from `10 REPS` to `MANUAL`.
- **Docs and the skill keep advertising the removed feature** → update `AGENTS.md`, the rest-timer skill, and delete the watch README in the same change; SwiftLint no longer includes the deleted folder.

## Migration Plan

1. Update the prototype, the skill, and the tests before the production code, so the expected copy and states are fixed.
2. Ship the model decode bridge first; verify a launch over a store with a saved REPS session and a running snapshot before deleting the recording UI.
3. Delete the watch target and the recording/watch-link code; regenerate the project and build the iPhone app, widget, and tests.
4. Verify an install over the previous build on the simulator: sessions, blocks, movement names, and a running snapshot survive, a REPS row reads MANUAL, and no watch strip or recording control appears.
5. Rollback keeps the same store shape: the profile columns still exist, and plans written by the new build contain only MANUAL/TIME, which the older build can decode. Re-running the older build restores its watch app only from the older app bundle; no data rollback is needed.

## Visual Review

Before implementation, review the two affected screens as before/after pairs: the TIMER with and without the watch strip, and MOVEMENTS with the record controls replaced by a name-only library. The intended result is subtraction only: no new controls, no replacement card, and the timer ring stays where it is.
