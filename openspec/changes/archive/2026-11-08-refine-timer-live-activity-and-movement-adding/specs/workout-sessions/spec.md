# Spec Delta

## ADDED Requirements

### Requirement: One-tap add from the movement library

The block editor SHALL show an `ADD FROM LIBRARY` list of recorded movements that are not already in the block. Tapping one SHALL append that movement with MANUAL and no target in one edit, keep the add-movement sheet closed, and apply the existing two-movement rounds rule. The list SHALL be hidden while editing is locked and absent when no unused movement remains. The add-movement sheet SHALL remain for several movements, custom ends and targets, and typed names.

#### Scenario: One tap adds a movement

- **GIVEN** a block containing Chest, and a library with Chest, Bench Press, and Curl
- **WHEN** the user taps Bench Press under ADD FROM LIBRARY
- **THEN** the block contains Chest then Bench Press with MANUAL and no target
- **AND** no sheet opens and the plan is flushed once

#### Scenario: A staged block gains its first movement

- **GIVEN** a staged block with no movements
- **WHEN** the user taps a library movement
- **THEN** the movement row appears, DONE becomes enabled, and the session still has no new block until DONE

#### Scenario: Used movements leave the list

- **GIVEN** every library movement is already in the block
- **WHEN** the block editor is shown
- **THEN** no ADD FROM LIBRARY list is offered

#### Scenario: A second movement raises rounds

- **GIVEN** a one-round block with one movement
- **WHEN** the user adds a second movement from the library
- **THEN** the block has two movements and rounds becomes 2

#### Scenario: The sheet still batches several movements

- **GIVEN** the add-movement sheet with two movements queued
- **WHEN** the user taps DONE
- **THEN** both movements are appended in order as before

#### Scenario: The added movement stays editable

- **GIVEN** a movement added from the library with MANUAL
- **WHEN** the user opens its row
- **THEN** its end condition and target can be changed to TIME or REPS

#### Scenario: Locked block editor

- **GIVEN** a session resting, with editing locked
- **WHEN** the block editor is shown
- **THEN** the ADD FROM LIBRARY list is not offered

## MODIFIED Requirements

### Requirement: Block management

From the session editor a user SHALL add, rename, reorder, and delete blocks. Tapping `+ ADD BLOCK` SHALL open a new block in the same editor layout used to edit a saved block: block name, summary, rounds, sets per round, set rest, round rest, ordered movements, order preview, and `+ ADD MOVEMENT`. A new block SHALL start as `Untitled block` with rounds 1, sets per round 3, the previous block's set and round rests, and no movements. Its movements SHALL be added through the block editor's `ADD FROM LIBRARY` list or the same add-movement picker a saved block uses. The new block MUST NOT be part of the session until DONE appends it; back, cancel, or closing the new block SHALL discard it, and backgrounding MUST NOT add it to the session. DONE SHALL stay disabled until the new block has at least one movement. Editing a saved block SHALL show the same fields and actions. Each saved block row SHALL be draggable by a grip and SHALL offer delete except when it is the only block. A session MUST keep one block. Delete SHALL require two taps; drag and delete SHALL be disabled while editing is locked.

#### Scenario: Adding a block does not clone movements

- **GIVEN** a session whose last block is Biceps
- **WHEN** the user taps `+ ADD BLOCK`, adds Triceps, and taps DONE
- **THEN** the new block contains only Triceps and inherits the last block's set and round rests

#### Scenario: Adding a block uses the block editor layout

- **GIVEN** a session with one saved block
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the page shows the block name field, rounds, sets per round, set rest, round rest, the movement list, the order preview, and `+ ADD MOVEMENT`, matching the page shown when a saved block is opened

#### Scenario: Adding a block waits for DONE

- **GIVEN** a session with one block
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the block editor opens and the session still has one block until DONE

#### Scenario: A new block starts from the documented defaults

- **GIVEN** a session whose last block has set rest 45 and round rest 90
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the new block is named `Untitled block` with rounds 1, sets per round 3, set rest 45, round rest 90, and no movements

#### Scenario: DONE appends the staged block

- **GIVEN** a staged block named Arms with rounds 4, sets per round 3, set rest 45, round rest 90, and one movement
- **WHEN** the user taps DONE
- **THEN** the session appends that block with those values and flushes the plan

#### Scenario: Cancelling the add-block picker adds no block

- **GIVEN** the new block editor is open from `+ ADD BLOCK` with one movement added
- **WHEN** the user goes back or cancels
- **THEN** the session still has the same blocks and no new block is saved

#### Scenario: A new block needs a movement before DONE

- **GIVEN** the new block editor is open with nothing added
- **WHEN** the user looks at DONE
- **THEN** DONE is disabled

#### Scenario: A staged block does not survive leaving the editor

- **GIVEN** the new block editor is open with a name and values but no movements
- **WHEN** the app is backgrounded and returns
- **THEN** the session still has its original blocks and no empty block

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
