# Design

## Context

See `proposal.md` for motivation and the specs for the required behavior.

- `SessionsScreen.addSession()` inserts a `PresetRecord` and pushes
  `.session(id)`. `SessionEditorScreen` loads that record through a
  `SessionDraftStore` whose 350 ms debounce saves every burst.
- The sessions list is `@Query`-driven, so any inserted record appears at once.
- `PlanCountRow` and `PlanStepperRow` build each control as an `Image` in a
  34 × 30 frame, then a 44 × 44 frame, then `contentShape(Rectangle())` inside
  the `Button` label. On the iOS 27 simulator the plus only responds in a narrow
  strip at its leading edge, while its visible center does nothing. The same
  applies to the top-right DONE (only its left padding fires) and to the
  end-condition segments (only the text, not the segment, fires). The movement
  editor's single `PlanStepperRow` works, so the fault is in how the label's
  hittable shape is built, not in the model or the draft.
- `SessionRoute` is `.session(UUID)`; `RootView` switches on it.
- The prototype is the visual and behavior reference; the skill owns the
  timing and interaction rules.

## Goals / Non-Goals

**Goals:**

- Open a new session as an in-memory draft; create exactly one record on DONE or
  USE THIS SESSION; discard on back, swipe-back, or a cold launch.
- Keep the active session and the running timer untouched by a draft.
- Make each stepper's whole visible chip the tap target and add press-and-hold
  repeat without changing the debounce pipeline.
- Make DONE and the end-condition segments take a tap on their visible body.

**Non-Goals:**

- Changing the add-block picker's staging: it still stages the block and commits
  on its own DONE; only its controls' tap surfaces change.
- Changing rest maths, the session snapshot, the Live Activity, or the watch.
- Adding sound or haptics.
- Persisting an unsaved draft across a cold launch.

## Decisions

### A route carries the draft, not a record

Add `SessionRoute.newSession(WorkoutPreset)`. `SessionsScreen.addSession()`
builds the draft exactly as today, copies the active session's first block with
a fresh block id and `Untitled block`, names it `New session`, and appends the
route. It does not touch `ModelContext`.

`RootView` maps `.session(id)` to the existing mode and `.newSession(preset)` to
the draft mode. `WorkoutPreset` is `Hashable` and `Sendable`, so it fits the
navigation path. The path holds the value the user opened; the editor's store
holds later edits, so the route does not change while typing.

Alternatives rejected:

- Add a draft flag to `PresetRecord` and filter it out of the list: writes an
  unwanted row and complicates rollback.
- Hold the draft in a `@State` and push `.newSession(UUID)`: the route value
  would have to be looked up outside the navigation path and could desync.
- Insert on the first edit and delete on back: a crash or a background kill
  leaves an orphan session.

### One editor, two commit paths

`SessionEditorScreen` takes a mode:

```swift
enum Mode { case existing(UUID), draft(WorkoutPreset) }
```

- `load()` creates the `SessionDraftStore` from the record or the draft. For a
  draft, `commit` stays nil, so the store keeps every edit in memory and the
  350 ms flush is a harmless no-op. A draft never calls `engine.use` and never
  starts a Live Activity refresh.
- DONE: an existing session flushes and dismisses as today. A draft runs
  `commitDraft()`, which normalizes the name, resolves a unique default name,
  inserts one `PresetRecord`, saves, and dismisses to SESSIONS.
- Back and swipe-back: an existing session flushes and dismisses; a draft
  dismisses without inserting. `onDisappear` and `scenePhase` must not insert a
  draft; they only flush existing sessions.
- USE THIS SESSION: a draft runs the same `commitDraft()`, then sets
  `ActivePresetStore.id`, calls `engine.use`, and shows the timer. An existing
  session keeps today's path.
- The footer for a draft shows no ACTIVE SESSION, RESTART, or DELETE SESSION;
  the delete action only applies to saved records. The draft is never active.
- The name resolves uniquely at save time. If the draft still carries the
  generated `New session`, `uniqueName` appends the lowest free suffix against
  the current records; a user-typed name is kept as normalized. Move `uniqueName`
  into a small shared helper so DONE and USE commit identically and tests can
  call it.
- A draft's DONE stays available while editing is locked because it only saves
  an inactive plan; USE stays disabled while locked because activating would
  reset the running timer. Back still discards. The add control itself keeps
  the existing lock, so a draft cannot be started during a set or rest.

Alternative rejected: one editor that always inserts a record and deletes it on
back. It leaks if the app dies between insert and back, and it briefly changes
the list.

### A draft survives backgrounding, not a cold launch

The draft lives in the navigation path and the in-memory store. Backgrounding
keeps both; a terminated app starts from the saved sessions, so an uncommitted
draft is gone. That is the intended meaning of “only after DONE”. No draft is
written to SwiftData, `SessionStore`, or `ActivePresetStore`.

### Build the stepper from one full-size shape

Replace `PlanCountRow.stepButton` and `PlanStepperRow.stepButton` with one
`PlanStepButton`:

- The label is one filled `RoundedRectangle` of 48 × 44 with the symbol drawn on
  top. The visible background is the full label, so the whole chip is hit-
  testable even where the old 44 pt frame around a 34 × 30 chip was transparent.
- `.contentShape(Rectangle())` is applied to the `Button`, not buried inside the
  label after a nested frame.
- A repeat task starts after a 500 ms press and fires every 100 ms. It calls the
  same binding as a single tap, re-checks `enabled` and the range on every tick,
  and cancels on release, disable, lock, or disappearance. A quick tap produces
  exactly one step; a hold produces the first repeat at 500 ms and no extra
  step on release.
- Each step mutates the draft, so the number leads the finger; the existing
  350 ms debounce collapses a burst or a hold into one commit, session reset,
  and Live Activity refresh.
- The accessibility label names the row and direction (`Increase ROUNDS`,
  `Decrease SETS PER ROUND`) instead of the symbol's `Add`/`Remove`.

Alternatives rejected:

- Adding `.contentShape` to the existing Button: the hit shape is still tied to
  the narrow intrinsic label on this OS build.
- A UIKit `UIButton` wrapper: heavier, loses SwiftUI Dynamic Type behavior, and
  is unnecessary if the full-size shape verifies.

### DONE and segments use a full-size styled body

The top-right DONE and the back action move their padding and capsule into a
shared pill button style, so the styled body is the full visible pill and the
Button is hit-tested on that body. The MANUAL/TIME/REPS control gets a
full-segment style with the fill behind the whole third, not just the text, and
a minimum height of 44 pt so the segment itself meets the tap-target rule.
`describe` must show the segment's button frame as the full third; a center tap
must select it. The same treatment applies to the picker's DONE and CANCEL, so
the fix does not stop at one screen.

### Prototype first, then the skill

- The prototype's `newSession()` keeps a `ui.newSession` draft, routes to the
  session editor without pushing or saving, and only `done-session` /
  `use-session` commit it; `back-list` drops it.
- Its stepper pointer handlers start a 500 ms delay and a 100 ms repeat while
  pressed, matching the app.
- `.agents/skills/restless-rest-timer/SKILL.md` updates the new-session default
  and the stepper paragraph; `AGENTS.md` needs no new rule because the skill
  owns the behavior detail.

## Risks / Trade-offs

- **A draft is lost on a cold launch** → intended; the editor shows the draft
  only until DONE, and the prototype copy keeps DONE as the commit.
- **The full-size shape may still miss on iOS 27** → verify with an Argent e2e
  that taps the visible center of every stepper, DONE, and a segment before
  closing the change; if a control still misses, wrap that single control in a
  `UIViewRepresentable` `UIButton`. The e2e is the guard against a silent
  regression.
- **A hold can outrun the debounce** → the repeat calls the same draft edit, and
  the debounce already cancels and reschedules; verify one save per hold.
- **A draft route carries a whole preset in the navigation path** → values are
  small and Hashable, and the path is not persisted; no migration concern.
- **DONE is the only commit besides USE** → its tap target is part of this
  change; the center-tap e2e covers it.
- **A draft can be committed while a set or rest runs** → DONE only saves an
  inactive plan, and USE stays disabled while locked, so the live timer is
  untouched.

## Migration Plan

No store format change. Existing `PresetRecord` rows keep their ids, blocks, and
active flag. New sessions are inserted only on DONE or USE, so an older build
sees the same records it always did. Reverting the app restores immediate
creation on `+`; sessions already saved remain valid. The prototype and skill
changes ship with the code and have no runtime migration.

## Open Questions

None.
