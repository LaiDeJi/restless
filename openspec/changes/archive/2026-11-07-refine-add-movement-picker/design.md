# Design

## Context

The add-movement picker is `MovementPickerSheet`, presented from
`BlockEditorScreen` and from `SessionEditorScreen` after adding a block. It
holds local state for the set end and target, and today every add path writes
immediately: a library row tap appends and dismisses, and a typed name calls
`MovementRepository.addOrReuse` (which saves SwiftData) before appending and
dismissing. DONE and CANCEL both only dismiss, so the sheet's header does not
express a commit. `SessionEditorScreen.addBlock` also appends an
`Untitled block` to the draft before the picker opens, so cancelling the picker
leaves an empty block behind and the 350 ms commit eventually saves it.

Session edits outside the picker go through `SessionDraftStore`, which applies
an edit in memory and coalesces persistence after 350 ms. The picker should
join that model: change nothing until DONE, then make one draft edit and flush.

The set-end control is the shared `EndConditionPicker`, used by the picker and
`BlockMovementEditorScreen`. It iterates `EndCondition.allCases`, so order and
default live in one place. The block movement editor already hides its
no-profile warning unless the condition is REPS; the picker does not.

The session name field already dismisses the keyboard from a page tap using a
`SpatialTapGesture` plus the field's frame in a named coordinate space. The
other text-field pages do not.

## Goals / Non-Goals

**Goals:**

- Make DONE the only commit in the add-movement picker and CANCEL the only
  discard, with several movements queued per visit.
- Keep the staged list out of the shared draft so a cancel cannot leak through
  the 350 ms debounce.
- Stage a new block with its first movements until that same DONE, so cancelling
  the picker leaves no empty block.
- Use one order and one default for the set-end control.
- Show the no-profile warning only where a profile is needed.
- Share one page-tap keyboard dismissal pattern across the text-entry editors.

**Non-Goals:**

- Changing the watch's counting rules or the profile format.
- Changing the local-first persistence of edits to an existing block; only the
  creation of a new block is staged.
- Allowing a new block with zero movements through the add flow.
- Adding an undo for a committed picker. CANCEL only covers the pending list.
- Changing the timer, rest plan, notifications, or Live Activity.

## Decisions

### Stage the picker in sheet-local state

`MovementPickerSheet` holds a `[PendingMovement]` list. Each entry captures the
movement (library movement or typed name) and the set end and target that were
selected when it was queued. Tapping a library row toggles it in the list;
ADD MOVEMENT queues the trimmed typed name and clears the field. The list is
shown under a "TO ADD" kicker with a remove control per row.

Why: the alternative, appending to the draft immediately and removing on
cancel, makes CANCEL a rollback and can persist a transient state after 350 ms.
Sheet-local staging keeps CANCEL a pure dismissal and leaves the draft untouched
until DONE. Capturing the condition per entry avoids silently rewriting already
queued movements when the control changes; each pending row shows its own
condition.

A movement appears at most once in the pending list; tapping its library row
again removes it. A typed name that matches a queued name is ignored rather
than duplicated. Duplicate movements can still be authored by closing the
picker and opening it again, so this is a convenience rule, not a new model
constraint. The queue rules live in a small value type in the app target so
they can be tested without a view: order, toggle, duplicate rejection, trim,
and removal.

### DONE resolves, appends once, and flushes

DONE first resolves each typed name through `MovementRepository.addOrReuse` (so
an existing name is reused), builds `[BlockMovement]` in pending order, then
calls a new `SessionDraftStore.appendMovements(_:toBlock:)` and `flush()`, then
dismisses. CANCEL and the sheet's swipe-down dismissal discard the pending list
without touching the repository or the draft.

Why a batch append: a loop of `appendMovement` would schedule several commits
and could apply the rounds rule more than once. The batch applies the rule once
against the final count: when a block has fewer than two movements and the
batch brings it to two or more, rounds rises to at least 2. The existing
single-item `appendMovement` becomes a one-item call to the batch, so its tests
and callers stay valid.

Library creation must happen on DONE, not when ADD MOVEMENT is tapped, so
CANCEL leaves the library unchanged. `MovementRepository.addOrReuse` already
handles trimming, case-insensitive reuse, and an empty name.

### Stage a new block with the same picker

`SessionEditorScreen` builds the would-be block locally: name `Untitled block`,
rounds 1, sets per round 3, the previous block's set and round rests, and no
movements. It no longer calls `draft.edit`; it keeps the block as the picker
target and opens `MovementPickerSheet` with either `.block(id)` or
`.newBlock(block)`.

For `.newBlock`, DONE builds the block with the pending movements in order,
raises rounds to at least 2 when two or more movements are queued, calls a new
`SessionDraftStore.appendBlock(_:)`, flushes, and dismisses. `appendBlock`
rejects an empty movement list, so the add flow cannot save an empty block.
CANCEL and swipe-down add nothing. DONE is disabled while the pending list is
empty; the empty pending note asks for at least one movement. The sheet's
intro says the queued movements become the new block's first movements, while
the existing-block mode keeps the current copy.

Why: appending then removing on cancel is a rollback that the 350 ms debounce
can persist, and it shows an empty block before the user has chosen anything.
A separate `appendBlock` keeps the insertion in one draft edit and lets the
rounds rule be tested at the block boundary. Existing empty blocks from older
data remain readable; this flow simply stops creating new ones.

### Put the set-end order in the model, not in the button loop

Add `EndCondition.editorOrder = [.manual, .time, .reps]` and have
`EndConditionPicker` iterate it. Initialize the add-movement picker's condition
to `.manual` with no target. The block movement editor gets the same order for
free; its selection still comes from the stored movement.

Why not reorder the enum cases: declaration order also drives `allCases`, and a
named order makes the UI intent explicit without implying that REPS is no
longer a valid case. Why not keep two orders: one shared control with two
orders would be a second convention to maintain. Changing the editor's order is
intentional.

### Make the profile warning conditional on REPS

Wrap the picker's warning in `if condition == .reps`. MANUAL already shows
"NO TARGET · TAP SET DONE WHEN THE SET ENDS."; TIME shows its target stepper.
The per-row PROFILE/NO PROFILE tag stays because it describes the library
movement, not the set end. Add `EndCondition.requiresWatchProfile` (true only
for REPS) and use it in both the picker and the block movement editor, so the
rule has one source.

Why: the profile is the watch's rep-counting signal. A manual set ends on the
tap and a timed set ends on the countdown, so neither needs a recorded profile.
This matches `BlockMovementEditorScreen`, which already gates the warning on
REPS.

### One page-tap keyboard dismissal modifier

Add a small `ViewModifier` in the app target that attaches a
`SpatialTapGesture` in a named coordinate space, takes the focused field's
frame, and clears the focus only when the tap is outside that frame. Each screen
keeps its own `@FocusState` and reports the field frame with `onGeometryChange`.
Apply it to the add-movement sheet, the block editor, the movement editor, the
recording sheet, and the session editor (replacing its inline copy of the same
gesture). Add `.scrollDismissesKeyboard(.interactively)` to the picker's scroll
view for parity.

Why a modifier: five screens repeat the same guard, and the session editor's
existing version is the proven shape. A background-only tap gesture would miss
taps on scroll content; a global resign without the frame guard would dismiss
when the user taps the field. The guard keeps the field tap intact.

## Risks / Trade-offs

- **Staging is less obvious than immediate add.** The sheet no longer closes on
  each add, so a user might queue and close with CANCEL without noticing. The
  "TO ADD" section, its count, and disabled-empty ADD button make the state
  visible; DONE keeps the primary treatment.
- **Swipe-down discards silently.** This matches CANCEL and changes nothing
  persistent, but there is no warning. Accept it; an alert would add friction
  to a no-op state.
- **Order change reaches the movement editor.** Existing users see MANUAL first
  when editing a movement. This is the intended single convention.
- **A new block is invisible until DONE.** Cancelling shows no trace, which is
  the goal, but the picker must make clear that it is creating a block. The
  intro copy and the empty pending note carry that context.
- **DONE is disabled for an empty new block.** That could read as a broken
  control. The empty note asks for at least one movement before DONE, and the
  ADD button stays available.
- **Batch and block appends change the rounds bump path.** Cover them with tests
  for an empty block, a one-movement block, a block that already has two or
  more, and a rejected empty block.
- **The page-tap gesture could eat a control tap.** Use `simultaneousGesture`,
  not `gesture`, and keep the field-frame guard so buttons still act.
- **A typed name is not in the library until DONE.** That is the point, but a
  second sheet opened before DONE cannot search for it. Accept it; the library
  is updated when the pending list commits.

## Migration Plan

No stored-format change and no migration. Existing sessions and library
movements remain readable. Rollback is the previous picker and session-editor
source; no data needs reverting unless a user committed a movement or block
through the new DONE path.
