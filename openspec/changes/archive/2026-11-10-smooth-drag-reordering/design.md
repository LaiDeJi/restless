# Design

## Context

See `proposal.md` for motivation. The drag path is shared by three lists:
`SessionsScreen` (session cards), `SessionEditorScreen` (blocks), and
`BlockEditorScreen` (movements). All three use `PlanListRow.swift`:

- `PlanDragHandle` puts a `UIDragInteraction` on the 44 pt grip. Its system
  preview is a transparent 1 × 1 view; the visible card is a `CALayer` added to
  the window and moved by a `CADisplayLink`.
- `PlanDropDelegate` reorders on `dropEntered`, so the list follows the finger.
- `SessionEditorScreen` and `BlockEditorScreen` reorder through
  `SessionDraftStore.edit`, which schedules a 350 ms flush. A flush saves
  SwiftData and, when the edited session is active, calls `engine.use`, which
  resets the run and refreshes the Live Activity.
- `SessionsScreen` writes `sortIndex` on every row entered and saves on drop.

There are four distinct costs, all on the main actor:

1. **The visual lift starts late.** `dragInteraction(_:sessionWillBegin:)` is
   documented as firing after the lift animation. The card, the source gap, and
   the display link are all created there, so the grip sits unchanged through
   the lift and the card appears only once the user starts moving.
2. **The card chases the finger.** The preview layer is a standalone
   `CALayer`; writes to its `position` outside a disabled action animate
   implicitly for about 0.25 s. Each display-link tick starts a new animation,
   so the card trails the pointer. The app also lacks
   `CADisableMinimumFrameDurationOnPhone`, which caps `CADisplayLink` at 60 Hz
   on a 120 Hz phone.
3. **Lift rendering blocks the frame.** `sessionWillBegin` builds the card with
   `ImageRenderer` at scale 3, including a 26 pt shadow and 30 pt padding for
   that shadow. A large Gaussian blur is rasterized synchronously before the
   card can appear.
4. **The draft commits mid-drag.** Every crossed row calls `draft.edit`, whose
   350 ms debounce can fire while the finger is still down. That saves the
   session and may reset the running session and refresh the Live Activity in
   the middle of the gesture. `dropUpdated` also rewrites `dropTargetID` at
   display rate.

The deployment target is iOS 18, Swift 6, strict concurrency. The editors are
custom `ScrollView` screens, not `List`s. The prototype is the visual reference;
this change does not alter the intended card, source gap, outline, or row layout.

## Goals / Non-Goals

**Goals:**

- The floating card appears and the source row leaves an empty gap when the
  system lift begins.
- The card tracks the pointer at the display's refresh rate for the whole
  gesture.
- Row crossings reorder the visible list with only view-state work.
- The model is written once, on drop; a cancelled drag restores the pre-drag
  order.
- No save, active-session reset, Live Activity refresh, or SwiftData query
  churn while the drag is in progress.
- The same behaviour for session cards, blocks, and movements.

**Non-Goals:**

- No custom gesture replacing the system drag; the standard long-press lift
  remains.
- No change to the card's visual design, the row layout, the grip, the delete
  affordance, or the editing lock.
- No edge autoscroll in a long list; that stays a separate follow-up.
- No rest-timer, watch, or Live Activity content change.
- No persistence format change.

## Decisions

### 1. Move the visual lift to `willAnimateLiftWith`

`UIDragInteractionDelegate` calls
`dragInteraction(_:willAnimateLiftWith:session:)` before the lift animation and
`sessionWillBegin` after it. All visual setup moves to the earlier callback:
take the cached card image first, then set `draggingID`, clear `dropTargetID`,
add the preview layer at the session's current location, and start the display
link. The image is read before the state writes because those writes can update
the SwiftUI row and invalidate the cache. `sessionWillBegin` only records that
the session is live (or does nothing). Setup is idempotent so a drag that skips
the lift callback still gets a card from `sessionWillBegin`.

Set `allowsSimultaneousRecognitionDuringLift = true` so the touch-down
pre-render recognizer from decision 3 cannot block the lift.

Alternative considered: return a full-row `UITargetedDragPreview` and let the
system move it. That removes the display link entirely, but the system applies
its own lift/drop animation and clipping, so the card would need a new visual
pass. The custom card already matches the design and is kept.

### 2. Make the preview layer track without implicit animation

The preview layer gets an `actions` dictionary that maps `position`, `bounds`,
`contents`, and `opacity` to `NSNull`, so every display-link write is applied
without an implicit animation. The display link gets a
`CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)`, and `project.yml`
adds `CADisableMinimumFrameDurationOnPhone: true` to the app's Info.plist.
Without the key, the link stays at 60 Hz on a 120 Hz phone and the card visibly
trails the system drag.

Alternative considered: a `CATransaction` with actions disabled around each
tick. It works, but a per-tick transaction is more code than a one-time
`actions` dictionary and is easy to forget on a new property.

### 3. Pre-render the card on touch-down and draw the shadow on the layer

The card image contains only the card: same corner radius, background, content,
and stroke, rendered at the window's scale, with no shadow and no shadow
padding. The `CALayer` draws the shadow with the current values (black 0.7,
radius 26, y 16) and a `shadowPath` for the card's rounded rect, so the blur is
never rasterized on the CPU.

A zero-duration `UILongPressGestureRecognizer` on the grip view triggers the
render on touch-down, long before the system lift delay elapses. The recognizer
sets `cancelsTouchesInView = false`, allows simultaneous recognition, and ends
by clearing the cache if no lift started. `willAnimateLiftWith` uses the cached
image and falls back to rendering once if the cache is empty.
`updateUIView` invalidates the cache when SwiftUI hands the handle new content.

The card's on-screen position is preserved: the old image's 30 pt padding and
the 12 pt offset put the card's bottom 42 pt above the finger, and the padding
clamped the card 30 pt inside the window. The new layer keeps the 42 pt bottom
offset and the 30 pt edge inset.

Alternatives considered:

- Keep the shadow in the image and pre-render it. The render still pays for the
  blur on touch-down, and the cache is an order of magnitude larger.
- Snapshot the live row with `drawHierarchy`. It is fast but includes the grip
  and trash and can capture the dimmed or outlined state, which changes the
  card's look.

### 4. Hold a provisional order in each screen and commit once

Each screen owns a `dragOrder` captured when the drag begins. The `ForEach`
renders from that order while the drag is active; `onReorder` only permutes the
local array. On a successful drop, the screen applies the final order in one
model call and ends the drag, which flushes once. On cancel, lock, background,
or disappear, it discards the array, ends the drag, and the list returns to the
model order.

- **SessionEditorScreen**: `dragOrder: [UUID]?`; `displayedBlocks` maps each id
  to the current `WorkoutBlock`. Drop calls
  `draft.reorderBlocks(to: order)` then `draft.endDrag()`. The commit runs after
  the drop frame, so a pause over a row never reaches the draft or the debounce.
- **BlockEditorScreen**: the same for movements. A saved block uses the
  draft's `edit`; a staged block is updated directly and never flushes.
- **SessionsScreen**: `dragOrder: [UUID]?` of record ids; the displayed records
  map from it. Drop assigns contiguous `sortIndex` values once and calls
  `context.save()`. No `sortIndex` writes while the pointer is down.

The draft's 350 ms debounce is not the reorder mechanism any more: the drag no
longer calls `edit`, and the first reorder edit happens on drop. A drag can
still begin while an earlier edit is waiting in that debounce, so
`SessionDraftStore` gains `beginDrag()` and `endDrag()`: `beginDrag()` cancels
the pending task and suspends scheduled flushes; `endDrag()` clears the flag and
flushes once. Both the commit and the revert path call `endDrag()`, so a
keystroke made immediately before grabbing a grip is deferred, never lost, and
still cannot save while the finger is down. This also means a reorder during the
active session's editor cannot reset the run or refresh the Live Activity until
the drag ends, which is the documented "edit resets the active plan" behaviour
at a predictable moment.

Alternatives considered:

- Add only a "suspend flush" flag to `SessionDraftStore`. It stops the
  mid-drag save, but still mutates the session on every crossing, rebuilding
  every observer, and still needs a separate cancel path. The flag is kept only
  for an edit already pending when the drag begins.
- Commit on every row entry (current). That is the main-thread work this change
  removes.
- Reorder only on drop. It loses the list-follows-the-finger behaviour the
  existing spec and design require.

### 5. Batch reorder methods in `SessionDraftStore`

Add `reorderBlocks(to:)` and `reorderMovements(in:to:)`. Both validate that the
incoming ids are a permutation of the current items (same count, no duplicates,
same set), then apply one `edit`. A failed validation leaves the session
untouched and returns false, so a stale provisional order cannot drop items.
The screen calls `endDrag()` after a successful drop, which flushes the single
edit. Tests cover saved and staged movement targets, valid permutations,
duplicates, missing ids, and the one-commit-per-drop rule.

### 6. Tighten `PlanDropDelegate`

- Keep live reorder in `dropEntered`, but guard `dropTargetID != targetID`
  before reordering, so a row that moves under a stationary pointer cannot
  apply the same move twice.
- In `dropUpdated`, only write `dropTargetID` when it differs; do not reorder.
  This keeps the outline accurate without invalidating the rows on every
  display tick.
- `performDrop` clears the drag bindings and calls the commit closure.
  `didEndWith` always fires and reports `operation == .move`; it removes the
  layer, stops the link, clears the cache, and asks the screen to commit or
  revert. The screen's commit is idempotent, so a drop followed by `didEndWith`
  saves once. A cancelled drag also animates the card from the release point
  back to the slot it lifted from in `willAnimateCancelWith`, before the
  system's return animation runs, so the card does not hang at the release point
  while the row goes back; `didEndWith` removes it when that animation finishes.

### 7. Preserve the current end-state clearing

`draggingID`, `dropTargetID`, and `dragOrder` all clear on drop, cancel, lock,
background, and disappear. A lock in the middle of a drag discards the
provisional order; the subsequent `didEndWith` finds nothing to commit. A drag
that never crosses a row leaves `dragOrder` equal to the model order; the screen
skips the model write when the arrays are equal but still ends the drag, so a
pending pre-drag edit is flushed and a lift-and-drop without a reorder does not
save a new order.

The floating card keeps the number and content captured at lift. The rows under
it renumber as they move, which is the current behaviour.

### 8. Leave a gap and suspend user scrolling during the gesture

The source row is hidden as a whole while it is the drag source: the card, the
grip, and the trash are not drawn, but the row keeps its height and a content
shape, so the list shows an empty slot instead of a second, dimmed copy of the
card with its green ACTIVE chrome. The slot must stay hit-testable because
UIKit ignores alpha-zero drop targets; otherwise releasing a crossed row back
into its own slot would cancel the drag and discard the provisional order. This
matches the gap a collection view opens for an insert-at-destination reorder.
The drop outline stays on the row under the pointer.

Each of the three lists disables user scrolling while a row drag is in flight.
The drag sits inside a `ScrollView` and the pan recognizer otherwise wins for an
upward move: the list rubber-bands at the top and cancels the drag, leaving the
card at the release point until the system cancel animation finishes. With user
scrolling suspended the card keeps tracking the pointer into the header, the
list does not bounce, and the drag ends on release. A long list still scrolls
near an edge to reveal earlier rows; app-driven autoscroll remains the separate
follow-up named in the non-goals.

Apple's lists also accept a release above the first row or below the last and
insert at the nearest edge. The top and bottom 200 pt of each list become drop
zones while a drag is live, using the first and last rows as their targets, so a
release in the header moves the source to the top and a release in the footer
moves it to the bottom, committing instead of cancelling and springing the card
back. The zones are nearly transparent because they are only hit targets; they
exist solely during the gesture and cannot block a normal tap.

### 9. Lift the row's own card and animate the crossing

The first pass made the card track the finger, but it measured the whole row, so
the card was 100 pt wider than the row card and the 30 pt window clamp pinned it
left of the finger. It also re-laid out the list in one frame on every crossing,
which is the visible difference from a native list.

- **Geometry.** `PlanListRow` and `SessionDragRow` measure the card's own frame
  (`.global`) and pass it to `PlanDragHandle`. The rendered lift card is that
  size, the layer starts at that frame's centre, and the offset between the card
  and the finger at lift is kept for the whole gesture. The window clamp is
  gone: a native lifted row follows the pointer even when part of it leaves the
  screen, and the grab point is what must not move. A row that has not measured
  itself falls back to the grip's rect, and the preview to 320 × 68.
- **Animation.** Each screen's `reorder` wraps the provisional-order write in
  `withAnimation(.smooth(duration: 0.26))`. SwiftUI interpolates the rows and
  the empty slot; the lifted card is a `CALayer` and is unaffected. The cancel
  path uses the same animation to glide back to the saved order under the card's
  own return animation.
- **Drop.** `performDrop` clears the bindings inside
  `withAnimation(.easeOut(duration: 0.14))`, so the source row fades back in,
  and `PlanDragHandle` fades its layer out over the same 0.14 s. The card keeps
  the number captured at lift, so the two overlap briefly with different
  numbers; the alternative needs the row's post-drop frame, which a drop
  delegate does not report.

Alternatives considered:

- Snap the card to the destination row on drop. `performDrop` runs before the
  row's final frame is laid out and the card has no handle on the destination,
  so the crossfade is the cheapest settle that stays correct.
- Animate only the crossed rows with `matchedGeometryEffect`. The rows are in
  one `VStack` with stable ids, so the implicit layout animation is the whole
  mechanism; matched geometry would add a namespace per screen.

### 10. Keep the frame out of state, and land the card

The native-feel pass removed the two self-inflicted costs the earlier design
left in, and closed a drag that could hang.

- **Frame in a box.** The row card's rect is written into `PlanCardMetrics`, a
  reference box shared with the handle, not into `@State`. A crossing changes
  the frames of the rows it moves; writing those into state re-evaluated each of
  those rows on top of the re-evaluation the shared `dropTargetID` already
  causes. The box keeps the frame live (the settle needs the destination slot)
  without touching the view graph. The row still reads the shared drag bindings,
  so a crossing re-evaluates every row; at 5–20 rows that is the price of a
  SwiftUI list, and only a collection view removes it.
- **Lift and land.** The card grows to 1.02 over 0.12 s when it lifts and, on a
  drop, moves onto the slot that took the row, shrinks to 1.0 and fades over
  0.16 s while the row fades in. A cancel uses the same shrink and fade as it
  returns to its old slot. This replaces the 0.14 s crossfade, so the two copies
  of the card are no longer side by side for a frame.
- **End every drag.** A hold-and-release without a crossing makes UIKit cancel
  the session without calling `didEndWith`; `draggingID` stayed set and the
  source row stayed hidden. The display link now records the finger-up and
  finishes the drag 0.45 s later if the system has not, using the same teardown
  as `didEndWith`. The watchdog cannot race a normal drag: a drop clears
  `draggingID` in `performDrop`, and a cancel reports back in about 0.3 s.
- **A card that cannot fail.** If the SwiftUI render ever comes back nil, the
  handle draws a plain rounded card instead, so the source row is never hidden
  behind no card at all.

## Risks / Trade-offs

- **Layer shadow differs from the rendered SwiftUI shadow** → keep the same
  colour, opacity, radius, offset, and corner radius; compare a screenshot of
  the lifted card against the current build and adjust the constants.
- **A crossing now animates the rows** → a fast drag can cross two rows inside
  one animation, and the second crossing retargets the in-flight rows; the
  drop target itself is still the layout position, so targeting stays exact.
  Verified with a slow and a fast drag in the Argent sequence.
- **The card is no longer clamped to the window** → a grip grabbed at the row's
  right edge and pushed to the left edge takes part of the card off-screen, as
  a native lifted row does; the grab point stays under the finger so the card
  never detaches.
- **The settle holds two copies of the card for 0.16 s** → the card keeps the
  number captured at lift while the row shows its new one; the shrink and fade
  read as one card landing.
- **The end watchdog can fire before a sluggish system callback** → it only
  acts when `draggingID` is still set 0.45 s after finger-up, and its teardown
  is the same one `didEndWith` runs, so a late callback is a no-op.
- **The touch-down recognizer competes with the drag or the scroll view** →
  `cancelsTouchesInView = false`, simultaneous recognition, and
  `allowsSimultaneousRecognitionDuringLift = true`; verify a quick tap on the
  grip, a vertical scroll starting on the grip, and a full drag.
- **A lift callback is skipped** → `sessionWillBegin` performs the same
  idempotent setup if it has not run, so the card still appears.
- **Provisional order diverges from the model** → editing is a single-finger
  gesture; other mutations cannot occur while the drag is down. Lock,
  background, and disappear discard the array. A staged block's provisional
  order is applied directly to the staged block.
- **Cancel now reverts the crossed order** → this is the documented behaviour
  in the lifted-row requirement; standard iOS drag-and-drop reverts outside a
  valid drop target. The e2e sequence covers it.
- **ProMotion opt-in affects the whole app** → the key only raises the allowed
  refresh rate; no visual or layout change. The display link exists only for
  the duration of a drag.
- **Row rebuild still happens on each crossing** → the reorder must rebuild the
  visible rows; the change removes the model, save, engine, and query work from
  that rebuild. A long list remains bounded by its row count, and lazy rows are
  a separate optimization if measurement still shows a problem.

## Migration Plan

No stored state changes. The reorder APIs replace per-row draft mutations but
read and write the same `WorkoutPreset` structure and `sortIndex` column.
Existing sessions, drafts, and legacy records load unchanged. Rollback is a code
revert; no data migration or store version bump is required.

## Open Questions

None.
