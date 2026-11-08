# Spec Delta

## ADDED Requirements

### Requirement: Movement list editing

Within a block editor a user SHALL be able to reorder and delete the block's movements from the movement list. Each movement row SHALL be draggable by a grip handle and SHALL offer a delete action except when it is the only movement. Tapping a row SHALL open its movement editor. A block MUST keep at least one movement, deletion SHALL require two taps, and drag and delete SHALL be disabled while editing is locked.

#### Scenario: Reordering movements by drag

- **GIVEN** a block with movements Bench Press, Incline Press, Fly
- **WHEN** the user drags Fly above Bench Press
- **THEN** the block order is Fly, Bench Press, Incline Press

#### Scenario: Deleting a movement from the list

- **GIVEN** a block with two movements
- **WHEN** the user taps a movement's delete action once and then again
- **THEN** that movement is removed and the block keeps the other one

#### Scenario: The last movement has no delete

- **GIVEN** a block with one movement
- **WHEN** the movement list is shown
- **THEN** no delete action is offered on that row

#### Scenario: Locked movement rows

- **GIVEN** a running rest
- **WHEN** the block editor is shown
- **THEN** neither drag nor delete is available on a movement row

### Requirement: Destructive actions use red

DELETE SESSION and the block and movement row delete actions SHALL use the destructive red. The first tap SHALL arm the action with a stronger red and the copy TAP AGAIN TO DELETE.

#### Scenario: DELETE SESSION is red

- **GIVEN** two saved sessions
- **WHEN** the session editor is shown
- **THEN** DELETE SESSION is red

#### Scenario: A block row delete arms in red

- **GIVEN** a session with two blocks
- **WHEN** the user taps a block's delete action once
- **THEN** the row shows TAP AGAIN TO DELETE in the stronger red

#### Scenario: A movement row delete arms in red

- **GIVEN** a block with two movements
- **WHEN** the user taps a movement's delete action once
- **THEN** the row shows TAP AGAIN TO DELETE in the stronger red

## MODIFIED Requirements

### Requirement: Session management

From the session editor a user SHALL be able to rename, activate, and delete a session. The last remaining session MUST NOT be deleted. Deleting a session SHALL require two taps on the delete action.

#### Scenario: Activating a session

- **GIVEN** Chest is active with sets completed
- **WHEN** the user activates Arms
- **THEN** Arms becomes active and the timer is not started at its first set with no completed sets

#### Scenario: Deleting a session in two steps

- **GIVEN** two saved sessions
- **WHEN** the user taps delete once and then confirms
- **THEN** the session is removed and another session becomes active

#### Scenario: Refusing to delete the last session

- **GIVEN** one saved session
- **WHEN** the session editor is shown
- **THEN** no enabled delete action is offered

### Requirement: Part management

From the session editor a user SHALL be able to add, rename, reorder, and delete blocks from the block list. Each block row SHALL be draggable by a grip handle and SHALL offer a delete action except when it is the only block. Adding a block SHALL append it and inherit the previous block's rest values. A session MUST keep at least one block. Deleting a block SHALL require two taps, and drag and delete SHALL be disabled while editing is locked.

#### Scenario: Adding a part

- **GIVEN** a session whose last part has set rest 60 and round rest 120
- **WHEN** the user adds a part
- **THEN** the new part is last and starts with set rest 60 and round rest 120

#### Scenario: Reordering parts

- **GIVEN** parts Biceps, Triceps, Back
- **WHEN** the user moves Back before Biceps
- **THEN** the session order is Back, Biceps, Triceps

#### Scenario: Reordering a block by drag

- **GIVEN** blocks Biceps, Triceps, Back
- **WHEN** the user drags the Back block's grip handle above Biceps
- **THEN** the session order is Back, Biceps, Triceps

#### Scenario: Deleting a block from the list

- **GIVEN** a session with two blocks
- **WHEN** the user taps a block row's delete action once and then again
- **THEN** that block is removed and the other block remains

#### Scenario: Deleting the last part

- **GIVEN** a session with one part
- **WHEN** the user looks for a part delete action
- **THEN** no enabled delete action is offered

#### Scenario: Locked block rows

- **GIVEN** a running rest
- **WHEN** the session editor is shown
- **THEN** neither drag nor delete is available on a block row
