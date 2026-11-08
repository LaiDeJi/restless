# Design

## Context

See `proposal.md` for motivation. The three touch points are already isolated:

- `Restless/UI/SessionEditorScreen.swift` owns the name field, the keyboard
  accessory toolbar, and the block list.
- `Restless/UI/MovementPickerSheet.swift` chooses an end condition and target,
  then appends an existing `MovementRecord` to the block.
- `Restless/UI/PlanListRow.swift` attaches the system drag to the 44 pt grip
  and reorders through `PlanDropDelegate`. Because the drag modifier is on the
  grip, the system preview is only the grip, not the row.

`WorkoutBlock`, `WorkoutPreset`, `MovementRecord`, and `MovementRepository` are
the existing model and persistence boundaries. The prototype is the visual
reference, and the project keeps SwiftUI-only changes out of the model layer.

## Goals / Non-Goals

**Goals:**

- Dismiss the session name keyboard from the page and remove the accessory bar.
- Create a library movement and append it to a block in one picker action.
- Make the dragged row unmistakable: a lifted full-row card, a dimmed source
  slot, and an outlined row under the pointer.
- Keep the existing edit debounce, editing lock, name limits, and library rules.

**Non-Goals:**

- Changing how a movement's watch profile is recorded or counted.
- Adding a movement category beyond the set end condition.
- Editing the movement name or profile from the picker.
- Reworking the rest timer, Live Activity, or watch protocol.
- Making rows draggable again while the session is resting or paused.

## Decisions

### Page tap dismisses by location, not by a blanket gesture

Remove the `.toolbar` keyboard item from `SessionEditorScreen`. Put the editor's
content in a named coordinate space and record the name field's frame with
`onGeometryChange`. Attach a `SpatialTapGesture` to the page as a simultaneous
gesture; when the tap ends outside the recorded name-field frame and the field
is focused, clear the focus. Focus loss continues to commit the trimmed name.

A plain `.onTapGesture` on the page would also fire when the user taps the name
field to place the cursor, and a transparent layer behind the `ScrollView` does
not receive taps on the scroll view's empty area. The location check handles
both while leaving block rows, steppers, and the footer fully tappable.

### One shared append path for picked and typed movements

Add `MovementRepository.addOrReuse(name:in:)`. It trims the name, caps it at the
existing 18-character limit, returns `nil` for an empty result, reuses a library
movement whose name matches ignoring case, and otherwise inserts a new
`MovementRecord` with no profile and saves.

Move the block append rule out of the view and into
`SessionDraftStore.appendMovement(_:toBlock:condition:target:)`: it clamps the
target through `BlockMovement`, appends the movement, and raises a one-round
block to two rounds when a second movement is added. Both the library row and
the new-name field call this path, so the picker cannot drift from the
existing add behaviour.

The picker adds a NEW MOVEMENT section above the library list: a name field,
the no-profile note, and a confirmation button that stays disabled until the
trimmed name is non-empty. Confirming creates or reuses the library movement,
appends it with the selected end condition and target, and dismisses the sheet.
Creating a block movement does not record a watch profile, so the existing
"NO PROFILE · RE-RECORD..." warning in the block movement editor remains the
single explanation of what the watch can count.

### Keep the system drag, replace its preview and add row states

Keep the system `onDrag`/`onDrop` reorder because it already handles targeting,
stable ids, and accessibility. Change the drag call to the preview overload and
render a card that mirrors the row: same number, name, and meta, measured at the
row's current width, with an opaque background, a slight lift, and a shadow.
The source row dims while it is the `draggingID`, and the row whose
`PlanDropDelegate` receives `dropEntered`/`dropUpdated` draws a set-accent
outline until `dropExited` or `performDrop`.

The source dim clears through every available end path: the drop delegate, a
container-level `.onDrop` on the editor page for releases outside the rows, a
scene-phase change (the session editor already observes it), `onDisappear`, and
on the next drag start. This covers the iPhone flows without replacing the
system drag with a hand-rolled gesture that would have to arbitrate against the
`ScrollView`.

The floating card is a preview only: it is not interactive, and the row's grip,
delete action, and accessibility Move up/Move down actions stay on the real row.

### Prototype before code

Because the row lift and the new-movement section are visible changes, update
`prototype-workout-timer.html` first: the picker gains the name field and the
lifted-row treatment gains an opaque card and stronger shadow. The browser
prototype does not model the iOS keyboard accessory, so the keyboard change is
tracked in the app and specs only.

## Risks / Trade-offs

- **A page-wide tap gesture could eat control taps.** It is added as a
  simultaneous gesture and only changes focus, so buttons still receive their
  tap; the location check keeps taps inside the name field from dismissing.
  Verify by tapping a block row, a stepper, and the name field with the keyboard
  open.
- **A cancelled system drag can leave `draggingID` set.** The container-level
  drop, scene-phase change, `onDisappear`, and next drag start all clear it.
  A drag cancelled by a system gesture with no drop callback is the residual
  case; the source row dim is the only stale visual.
- **Reusing a name prevents two library entries with the same shown name.**
  This avoids an ambiguous picker. A user who needs a second variant can rename
  it (for example, Cable Curl); no data is lost.
- **A movement created in the picker is saved immediately and has no profile.**
  It appears in LIBRARY as NO PROFILE until re-recorded; the block movement
  editor already explains that the watch cannot count it.
- **The floating preview is a snapshot at the row's width.** At accessibility
  sizes its text can wrap more than the source row. It is a transient preview,
  so this is accepted rather than adding a second layout mode.

## Migration Plan

No store or JSON format change. Existing `MovementRecord` rows, session blocks,
and profiles remain valid. Reverting the UI files removes the new picker section
and drag treatment; any library movement created in the meantime stays a normal
record and remains deletable when unused.

## Open Questions

None.
