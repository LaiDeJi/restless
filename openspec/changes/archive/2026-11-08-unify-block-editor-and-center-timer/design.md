# Design

## Context

See `proposal.md` for motivation. The current add-block flow lives in
`SessionEditorScreen` as a `StagedBlock` sheet that opens
`MovementPickerSheet` with `.newBlock`, then appends a default block on the
picker's DONE. `BlockEditorScreen`, `BlockMovementEditorScreen`, and
`MovementPickerSheet` all address a saved block by `draft.session.blocks`
lookup. The timer in `TimerScreen` is a `ScrollView` containing a `VStack` with
`Spacer(minLength: 10)` around a hero + `SetMap` + watch group. The whole
`VStack` is centered in a `minHeight` frame, so a taller map or a wrapping
position strip moves the group and the ring.

Constraints: the prototype is the layout reference and is updated first; the
skill records the rule; editing stays local-first through `SessionDraftStore`;
no store format changes; SwiftLint runs on the app target.

## Goals / Non-Goals

**Goals:**

- Add and edit a block with one shared editor layout.
- Keep a new block out of the session, and out of persistence, until DONE.
- Keep the timer's countdown ring at one vertical centre on every block and
  phase, with the map below it.
- Keep the session's saved data unchanged and the running session untouched by
  authoring a new block.

**Non-Goals:**

- Changing rest maths, the state machine, the watch link, or the Live Activity.
- Changing the session model or its persisted JSON.
- Adding a new capability, screen, or dependency.
- Reworking the block map's dot/bar thresholds.

## Decisions

### 1. Author the new block in a staged block on the draft store

`SessionDraftStore` gains an optional `stagedBlock: WorkoutBlock?` that is not
part of `session.blocks`. New store methods create it from the previous block's
rests and the defaults (name `Untitled block`, rounds 1, sets per round 3, no
movements), edit it, append queued movements to it, commit it, and discard it.
Edits to the staged block do not mark the session dirty and do not schedule a
save. `commitStagedBlock()` folds it into `session.blocks` through the same
clamping rules as `appendBlock` (at least one movement, rounds and sets at least
1, multi-movement rounds at least 2) in one `edit`, then the editor flushes.
`discardStagedBlock()` drops it.

A single `BlockEditingTarget` value (`saved(UUID)` or `staged`) selects the block
for `BlockEditorScreen`, `BlockMovementEditorScreen`, and
`MovementPickerSheet`; their reads and mutations go through store methods that
resolve the target. This keeps the layout and controls in one place instead of
duplicating a new-block form, and it makes an accidental save impossible: the
session never contains the block until commit.

Alternatives rejected:

- Append the block to `session.blocks` immediately and remove it on cancel. The
  350 ms debounce and the background flush can persist an empty block, so the
  "cancel adds no block" contract would only hold if the flow was fast enough.
- Keep the current picker and open the block editor after it. The user would
  still author the block in two different layouts, and the picker would still
  own the defaults.
- Give `BlockEditorScreen` a local `WorkoutBlock` binding. Three screens
  (block, movement, picker) would each need binding plumbing, and the movement
  picker is also used by saved blocks with a different source.

### 2. `+ ADD BLOCK` pushes the staged block editor

`SessionEditorScreen` removes its `StagedBlock` sheet. Tapping `+ ADD BLOCK`
calls `draft.beginStagedBlock(after: draft.session.blocks.last)` and presents
`BlockEditorScreen(target: .staged)` with a
`.navigationDestination(isPresented:)` declared in the session editor, so the
screen is pushed on the same `NavigationStack` as a saved block. The whole block
form is visible: header, `BLOCK`, name, summary, rounds, sets per round, set
rest, round rest, movements, order preview, and `+ ADD MOVEMENT`. A staged block
offers no `DELETE BLOCK`; back is the discard action. DONE is disabled while the
staged block has no movements; when enabled it commits the block and returns to
the session editor, where the block now appears.

`SessionEditorScreen` watches the presentation binding: when the new-block
destination closes and the staged block was not committed, the session editor
discards it. The block editor does not discard on `onDisappear`, because
pushing the movement editor or opening the movement picker can trigger that
callback while the block is still being authored. A fast double tap on
`+ ADD BLOCK` is gated by the presentation flag so only one staged block is
created. The session editor never lists a staged block.

### 3. The picker adds movements only

`MovementPickerSheet.Target.newBlock(WorkoutBlock)` is removed. The picker takes
the same `BlockEditingTarget` and appends queued movements to the saved or
staged block. The `NEW BLOCK` title, note, and the `isNewBlock && pending.isEmpty`
DONE gate disappear; the page always reads `ADD MOVEMENT` / `SET END`, keeps the
MANUAL/TIME/REPS staging and `TO ADD` list, and DONE with an empty queue simply
closes. The block editor's `+ ADD MOVEMENT` is the only entry point. The movement
editor's target also resolves through the same value, so editing a movement of a
staged block never touches the session.

### 4. Pin the timer hero with a dedicated layout

`TimerScreen` keeps its `GeometryReader`/`ScrollView`, but the inner `VStack`
becomes a small custom `Layout` (or an equivalent measured layout) fed with the
viewport height. It places:

- the header, block strip, and position strip at the top;
- the hero ring with its centre at `viewportHeight / 2`, clamped below the top
  chrome only when the chrome and the ring cannot both fit;
- the set map and watch strip below the ring at a fixed gap;
- the actions at `max(map bottom + gap, viewportHeight - actions height)`.

The layout's height is `max(viewportHeight, actions bottom)`, so the page scrolls
when a tall map pushes the actions down, while the ring's initial centre remains
the viewport centre. The position strip and block strip may wrap or change
height without moving the ring. A pure metrics helper holds the placement maths
so unit tests cover block 1 vs block 2, a wrapping strip, a tall map, and a
short viewport.

Alternatives rejected:

- Keep the centered hero + map group and reserve the session's tallest map
  height. The ring would stay put but sit above the screen's middle, which is the
  position the user asked to fix.
- Give the position strip a fixed two-line height and keep the current VStack.
  It fixes the wrapping case but not the map growth, and it wastes a line on
  every block.

### 5. Prototype and skill first

The prototype's block route gains a staged new-block mode that renders the same
block editor, and its picker drops the `NEW BLOCK` variant. Its timer stage pins
the hero at 50% of the stage and places the map below it; tall content scrolls.
The skill's block-creation, navigation, timer-presentation, copy, and test lists
are updated from the prototype before the app is changed.

## Risks / Trade-offs

- **Ring pinning at accessibility text sizes or a short foldable viewport** →
  clamp the ring below the top chrome when they cannot both fit, and let the page
  scroll. The normal-size contract (fixed centre) still holds.
- **A tall map pushes the actions below the fold** → the timer page scrolls; the
  ring stays centred on first display. This is deliberate: the map is secondary
  to the countdown.
- **A staged block is lost if the app is killed before DONE** → accepted; it was
  never part of the session, and the same is true of an unsaved movement queue.
- **Two ways into `BlockEditorScreen` (NavigationLink and
  `navigationDestination(isPresented:)`) can double-push on a fast double tap** →
  gate the add action on the staged block flag and set it only once; the button
  is a plain button with a full-surface tap target.
- **The shared target value touches three screens** → keep the store methods as
  the only mutation path and cover saved and staged cases in store tests.

## Migration Plan

No data migration. Existing sessions and the current run stay readable. Land the
prototype and skill first, then the store and editors, then the timer layout.
Rollback is a UI revert; the staged block is never persisted, so no cleanup is
needed.
