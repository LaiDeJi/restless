# Spec Delta

## MODIFIED Requirements

### Requirement: Movement creation in the add-movement picker

The add-movement picker SHALL let a user queue a typed movement name or a
library movement with the selected set end and target. ADD MOVEMENT SHALL queue
the typed name without saving it. Tapping a library row SHALL queue that
movement. DONE SHALL create or reuse the typed library movements, append every
queued movement to the block in the displayed order, flush the plan, and close
the picker. CANCEL SHALL close without changing the block or the library. The
picker SHALL stay open while movements are queued. A created movement SHALL
carry no watch profile.

#### Scenario: Queueing a typed movement

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** the user types Cable Fly and taps ADD MOVEMENT
- **THEN** Cable Fly appears in the pending list with MANUAL, no library movement is created yet, and the picker stays open

#### Scenario: Creating a movement and appending it

- **GIVEN** the picker has pending Cable Fly with MANUAL and Bench Press with REPS 10, and the library has Bench Press
- **WHEN** the user taps DONE
- **THEN** the library gains Cable Fly with no profile, the block appends Cable Fly then Bench Press in that order, the plan is flushed, and the picker closes

#### Scenario: Cancel discards the pending movements

- **GIVEN** a pending Cable Fly that does not exist in the library
- **WHEN** the user taps CANCEL
- **THEN** the library still has no Cable Fly, the block is unchanged, and the picker closes

#### Scenario: A new movement has no profile

- **GIVEN** a block movement created from a typed name with REPS selected
- **WHEN** the block movement editor is shown
- **THEN** it reports that the movement has no profile and the watch cannot count it

### Requirement: Block management

From the session editor a user SHALL add, rename, reorder, and delete blocks.
Tapping + ADD BLOCK SHALL open the movement picker without adding a block. DONE
SHALL append one new block with the queued movements, inheriting the previous
block's rest values and copying no movements; CANCEL SHALL add no block. DONE
SHALL stay disabled for a new block until at least one movement is queued. Each
row SHALL be draggable by a grip and SHALL offer delete except when it is the
only block. A session MUST keep one block. Delete SHALL require two taps; drag
and delete SHALL be disabled while editing is locked.

#### Scenario: Adding a block does not clone movements

- **GIVEN** a session whose last block is Biceps
- **WHEN** the user taps + ADD BLOCK, queues Triceps, and taps DONE
- **THEN** the new block contains only Triceps and inherits the last block's set and round rests

#### Scenario: Adding a block waits for DONE

- **GIVEN** a session with one block
- **WHEN** the user taps + ADD BLOCK
- **THEN** the picker opens and the session still has one block with no new block added

#### Scenario: Cancelling the add-block picker adds no block

- **GIVEN** the picker is open from + ADD BLOCK with one queued movement
- **WHEN** the user taps CANCEL
- **THEN** the session still has the same blocks and no empty block is saved

#### Scenario: A new block needs a movement before DONE

- **GIVEN** the picker is open from + ADD BLOCK with nothing queued
- **WHEN** the user looks at DONE
- **THEN** DONE is disabled

#### Scenario: Reordering blocks

- **GIVEN** blocks Biceps, Triceps, Back
- **WHEN** the user drags Back above Biceps
- **THEN** the session order is Back, Biceps, Triceps

#### Scenario: Deleting the last block

- **GIVEN** a session with one block
- **WHEN** the user looks for a block delete action
- **THEN** no enabled delete action is offered

#### Scenario: Locked block rows

- **GIVEN** a running rest
- **WHEN** the session editor is shown
- **THEN** neither drag nor delete is available on a block row

## ADDED Requirements

### Requirement: Set-end choices start with MANUAL

The add-movement picker SHALL list MANUAL, TIME, REPS in that order and SHALL
start with MANUAL selected. The block movement editor SHALL list the same order.

#### Scenario: The picker opens on MANUAL

- **GIVEN** the add-movement picker is opened
- **WHEN** the set-end control is shown
- **THEN** MANUAL is selected and the order is MANUAL, TIME, REPS

#### Scenario: The movement editor uses the same order

- **GIVEN** a block movement in the movement editor
- **WHEN** the set-end control is shown
- **THEN** the order is MANUAL, TIME, REPS with the movement's stored condition selected

### Requirement: The no-profile warning follows the set end

The add-movement page SHALL show the warning that a new movement cannot be
counted without a profile only while REPS is selected. With MANUAL or TIME
selected it SHALL show no profile warning. The existing PROFILE or NO PROFILE
tag on a library movement row SHALL remain.

#### Scenario: REPS shows the warning

- **GIVEN** the add-movement picker with REPS selected
- **WHEN** a new movement name is typed
- **THEN** the page warns that the watch cannot count the movement until it is recorded

#### Scenario: MANUAL and TIME hide the warning

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** a new movement name is typed
- **THEN** the page shows the manual tap-to-finish copy and no profile warning
- **AND** selecting TIME instead also hides the profile warning

### Requirement: Text-entry pages dismiss the keyboard on a page tap

On an editor page with a focused text field, a tap on the page outside that
field SHALL end editing and dismiss the keyboard. A tap inside the focused field
SHALL keep the keyboard. The typed text SHALL remain in the field.

#### Scenario: Tapping the add-movement page dismisses the keyboard

- **GIVEN** the add-movement picker with the keyboard open in the new movement field
- **WHEN** the user taps the page outside the field
- **THEN** the keyboard is dismissed and the typed name stays in the field

#### Scenario: Tapping a block or movement page dismisses the keyboard

- **GIVEN** the block name field is focused with the keyboard open
- **WHEN** the user taps an empty part of the page
- **THEN** the keyboard is dismissed and the trimmed block name is committed

#### Scenario: Tapping the focused field keeps the keyboard

- **GIVEN** the keyboard is open in a focused text field
- **WHEN** the user taps inside that field
- **THEN** the keyboard stays open
