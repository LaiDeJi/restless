# Design

## Context

See `proposal.md` for motivation. The relevant current shape:

- `SessionSnapshot` lives in `Shared/` and is compiled into the app, the widget
  extension, and the watch target. Its `SessionPhase` is a `String`-backed
  `Codable` enum, so adding a case keeps existing stored snapshots readable.
- Every mutation goes through `SessionTransitions.apply`. The timer's primary
  button reads `snapshot.primaryAction`; the island links call the same entry
  point from `SessionEngine.handle(_:)`.
- `SessionEditorScreen` and `BlockEditorScreen` are custom `ScrollView` screens,
  not `List`s. Rows are `NavigationLink` cards with a column of move buttons.
- `SessionEngine.persist()` requests a Live Activity on every mutation;
  `LiveActivityCoordinator.start` creates one if none exists and updates it
  otherwise.
- Deletion is two-step and the last block, movement, and session cannot be
  deleted.

## Goals / Non-Goals

**Goals:**

- A deliberate start gate that is part of the shared session state, so the
  timer, island links, watch arming, and restored snapshots agree.
- Direct manipulation of the plan: drag to reorder, delete from the row.
- One destructive red token used by every delete action affected here.
- Existing v3 snapshots keep working; no store migration.

**Non-Goals:**

- No changes to rest maths, block/set counting, or the watch counting path.
- No native `List` conversion of the editors.
- No new sound, notification, or haptic behaviour.
- No reordering of the sessions list itself.

## Decisions

### 1. Add `SessionPhase.notStarted` rather than a boolean

A new phase is compiler-checked: every `switch` over `SessionPhase` must decide
what the gate looks like, and the transition guards live in the same place as
the existing state machine. A `hasStarted` boolean would be a second source of
truth, would need custom `Codable` decoding to keep old snapshots readable, and
would leave the state machine unchanged while the UI special-cased it.

- `SessionPhase` gains `notStarted` (raw value `notStarted`).
- `SessionSnapshot.initial` returns `.notStarted`; `.replacePreset` also
  returns `.notStarted`.
- `SessionTransitions.apply(.startSession)` sets `.ready` and leaves
  `doneSets` at zero. It is valid only in `.notStarted`.
- `setDone` and `startSet` already guard on `.ready`/`.performing`, so an
  island set-done tap in the gate is ignored.
- `.restart` keeps its current meaning: it returns to `.ready` at zero sets.
  START AGAIN is already a direct start. The editor's RESTART SESSION passes
  `startImmediately: true` to `engine.use`.
- `isLocked` is false in the gate, so plans stay editable.

Presentation in the gate:

| Element | Value |
| --- | --- |
| kicker | `READY` |
| hero | `START` |
| subtitle | `n BLOCKS · n SETS · n TOTAL REST` |
| primary title | `START SESSION` |
| primary subtitle | `BLOCK 1 · <FIRST BLOCK NAME>` |
| block strip / position strip / set map | first block and set, zero completed |
| watch strip | hidden |
| accent | set green |

`usesSmallHero` is true for the gate.

### 2. The gate is entered at launch, activation, and active-plan edits

`SessionEngine` starts a new install in the gate. Restoring a saved snapshot
keeps whatever phase was stored; an old ready/resting snapshot therefore
resumes as before. `engine.use(_:)` resets to the gate for USE THIS SESSION and
for the active-plan commit path. RESTART SESSION uses
`engine.use(_:startImmediately:)`, which applies `.startSession` before the one
persistence pass, so it does not flash the gate or end and re-request the
activity.

This keeps the rule that a plan change resets the run, while explicit "again"
and "restart" actions remain one tap.

### 3. Live Activity reconciles through one gate-aware call

`LiveActivityCoordinator.restart` and `.start` gain an early branch: when the
snapshot is `.notStarted`, end all activities and return. Every engine
mutation still launches exactly one activity task, so activation, edits, and
starting cannot leave a stale activity behind. `use(startImmediately:)` builds
the final snapshot before persisting, so it issues one "start" task rather than
an end followed by a start.

The widget's phase switches add `.notStarted` cases for completeness, but the
gate normally has no activity to display.

### 4. Reorder with system drag-and-drop, not a hand-rolled gesture

Each row's trailing grip is the drag source (`onDrag` with the item's UUID),
and each row is a drop target. A `DropDelegate` reorders on `dropEntered`, so
the list moves under the finger instead of waiting for the drop. Removing the
source and inserting at the target's original index makes the move
direction-aware:

- dragging down onto a row lands after it;
- dragging up onto a row lands before it.

Alternatives rejected:

- **Custom `DragGesture` + offsets**: fights the `ScrollView` pan, needs manual
  midpoint maths and autoscroll, and is hard to make accessible.
- **Native `List` with edit mode or `.onMove`**: the editors are one custom
  scroll surface with a header, name field, summary, steppers, and footer. An
  always-active edit mode disables `NavigationLink`s and breaks the card look;
  a nested `List` would need a fixed height.
- **`.draggable`/`.dropDestination`**: reorders only on drop; `onDrop` with
  `dropEntered` gives the live feel the request asks for.

The drag item is the row's stable id, not its index. The reorder handler looks
up the current indexes after every hover, so a fast drag across several rows
does not use stale indexes.

Row structure:

```
[ number | name + meta | grip 44×44 | trash 44×44 ]
          the card is the NavigationLink; grip and trash are siblings
```

- The grip is a 44 pt target with `accessibilityHidden(true)`; the row carries
  VoiceOver custom actions `Move up`, `Move down`, and `Delete`.
- Drag and drop are attached only while editing is unlocked.
- The last block/movement has no trash; the grip stays.
- First trash tap arms only that row: the secondary line becomes
  `TAP AGAIN TO DELETE` in red and the trash fills red. Second tap deletes and
  flushes the draft immediately. Any other trash tap moves the arm.
- Reorder and delete call `draft.edit` and then `draft.flush()`: they are
  discrete actions, not a stepper burst, so the save and the active-plan reset
  happen once immediately.

Long plans: system drag may not autoscroll a plain `ScrollView`. This is
accepted for the first pass and verified with a long fixture; if it does not
scroll, a follow-up adds edge autoscroll rather than changing the interaction.

### 5. One destructive token

`Theme.destructive` is a warm red that sits beside the existing green and amber
on the near-black surface. Using one token keeps DELETE SESSION, row deletes,
and the existing detail-page delete links consistent. The armed treatment is
the full-strength red plus a red-tinted capsule; the resting treatment is the
same red at reduced opacity. The prototype's `.danger-link` class changes from
white/amber to this red so the visual reference and the app agree.

### 6. Prototype and skill are updated before code

The prototype is the behaviour and visual reference. It gains the gate state,
START SESSION copy, the grip/trash row layout, and the red danger link. The
skill's state table, transition list, timer presentation, editing rules, and
copy list are updated from the prototype before the SwiftUI changes land.

## Risks / Trade-offs

- **Drag does not autoscroll in a long list** → verify with a long fixture; a
  later edge-autoscroll change is additive and does not alter the row API.
- **Drag starts with a system lift, not an immediate pull** → this is the
  standard iOS drag affordance; the grip makes the source discoverable. The
  row also keeps VoiceOver move actions for non-drag use.
- **An old saved snapshot is in `.ready` and skips the gate** → intentional:
  an in-flight session from before the update is not interrupted.
- **A new phase touches every `SessionPhase` switch** → the compiler enumerates
  them; the widget and timer get explicit gate copy. The watch app does not
  switch on `SessionPhase`.
- **Two-step delete in a row is less discoverable than a dialog** → the row's
  meta line changes on the first tap and the copy matches the existing delete
  links, so the second tap is explicit.
- **Activity end/start ordering** → one activity task per engine mutation and
  `use(startImmediately:)` as a single snapshot avoid end-then-start pairs.

## Migration Plan

No store key change. `SessionPhase` reads the existing raw values and the new
one; a pre-change v3 snapshot continues at whatever phase it stored. A downgrade
that meets `notStarted` fails to decode and falls back to a ready session, which
is the same behaviour as an unreadable snapshot today. Ship the prototype and
skill update in the same change as the code so the reference and app do not
drift.
