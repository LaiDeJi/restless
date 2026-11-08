# Spec Delta

## MODIFIED Requirements

### Requirement: Block management

From the session editor a user SHALL add, rename, reorder, and delete blocks. Tapping `+ ADD BLOCK` SHALL open a new block in the same editor layout used to edit a saved block: block name, summary, rounds, sets per round, set rest, round rest, ordered movements, order preview, and `+ ADD MOVEMENT`. A new block SHALL start as `Untitled block` with rounds 1, sets per round 3, the previous block's set and round rests, and no movements. Its movements SHALL be added through the same add-movement picker a saved block uses. The new block MUST NOT be part of the session until DONE appends it; back, cancel, or closing the new block SHALL discard it, and backgrounding MUST NOT add it to the session. DONE SHALL stay disabled until the new block has at least one movement. Editing a saved block SHALL show the same fields and actions. Each saved block row SHALL be draggable by a grip and SHALL offer delete except when it is the only block. A session MUST keep one block. Delete SHALL require two taps; drag and delete SHALL be disabled while editing is locked.

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
