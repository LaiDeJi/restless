# Spec Delta

## REMOVED Requirements

### Requirement: Session plans are ordered parts

**Reason**: A session is now a list of blocks, and a block holds movements. The part is no longer a session unit.

**Migration**: Each stored part becomes a straight block with one manual movement, preserving the part's name, rounds, sets per round, set rest, and round rest.

### Requirement: Part management

**Reason**: Blocks and movements replace parts; the editor manages blocks and the movements inside them.

**Migration**: Existing parts become blocks; their rounds and sets become the block's count and the movement's sets.

### Requirement: Existing presets migrate to one-part sessions

**Reason**: The migration target is a block with a movement, not a part.

**Migration**: Each preset becomes one straight block with one manual movement; the active preset remains the active session.

### Requirement: Session and part summaries

**Reason**: Summaries now describe blocks, movements, sets or rounds, and rests.

**Migration**: A part summary becomes a block summary with the same totals.

### Requirement: Name rules

**Reason**: Names now cover sessions, blocks, and movements, not sessions and parts.

**Migration**: The new name requirement below keeps the 18-character limit and the Untitled defaults.

## ADDED Requirements

### Requirement: Session plans are ordered blocks

A session SHALL have a stable identifier, a name, and one or more ordered blocks. Each block SHALL have a stable identifier, a name, an arrangement, a set rest, a round rest, and one or more ordered movements. Blocks SHALL run in the order shown.

#### Scenario: A session stores blocks in order

- **GIVEN** a session containing Chest followed by Arms
- **WHEN** the session is opened
- **THEN** Chest is the first block and Arms is the second block

#### Scenario: A session never has zero blocks

- **WHEN** the only block in a session is deleted
- **THEN** the deletion is refused and the block remains

### Requirement: Blocks arrange movements straight or circuit

A block SHALL be straight or circuit. A straight block SHALL perform all sets of one movement before the next movement. A circuit block SHALL perform one set of each movement per round, then repeat. A two-movement circuit SHALL be labelled SUPERSET; three or more SHALL be labelled CIRCUIT.

#### Scenario: Straight order

- **GIVEN** a straight block with bench press 3 sets and incline press 3 sets
- **WHEN** the block runs
- **THEN** the order is bench 1, 2, 3, then incline 1, 2, 3

#### Scenario: Circuit order

- **GIVEN** a circuit block with bench press and incline press, 3 rounds
- **WHEN** the block runs
- **THEN** the order is bench, incline, bench, incline, bench, incline

#### Scenario: Label follows the movement count

- **GIVEN** a circuit block with two movements
- **WHEN** the block is shown
- **THEN** it is labelled SUPERSET
- **AND** a circuit block with three movements is labelled CIRCUIT

### Requirement: Movements carry an end condition

Each block movement SHALL reference a library movement and carry an end condition: reps, time, or manual. A reps movement SHALL carry a target of 1 or more. A time movement SHALL carry a target in seconds. A manual movement SHALL carry no target. The library entry carries no default; the condition belongs to this use.

#### Scenario: Reps movement

- **GIVEN** a block movement with end condition reps
- **WHEN** its target is 12
- **THEN** the set ends when 12 reps are counted

#### Scenario: Time movement

- **GIVEN** a block movement with end condition time
- **WHEN** its target is 60
- **THEN** the set ends when the 60 second countdown reaches zero

#### Scenario: Manual movement

- **GIVEN** a block movement with end condition manual
- **WHEN** the set is ready
- **THEN** the set ends only when the user taps SET DONE

### Requirement: Block and movement management

From the session editor a user SHALL be able to add, rename, reorder, and delete blocks, and add, reorder, and remove movements in a block. A session MUST keep at least one block. A block MUST keep at least one movement. Deleting a block or a movement SHALL require two taps.

#### Scenario: Adding a block

- **GIVEN** a session whose last block has set rest 60 and round rest 120
- **WHEN** the user adds a block
- **THEN** the new block is last and starts with set rest 60 and round rest 120

#### Scenario: Reordering blocks

- **GIVEN** blocks Chest, Arms, Back
- **WHEN** the user moves Back before Chest
- **THEN** the order is Back, Chest, Arms

#### Scenario: Deleting the last block

- **GIVEN** a session with one block
- **WHEN** the user looks for a block delete action
- **THEN** no enabled delete action is offered

#### Scenario: Adding a movement

- **GIVEN** a block with one movement
- **WHEN** the user adds a movement from the library
- **THEN** the movement is appended to the block

#### Scenario: Removing the last movement

- **GIVEN** a block with one movement
- **WHEN** the user looks for a movement remove action
- **THEN** no enabled remove action is offered

### Requirement: Existing plans migrate to one block with one movement

Each stored part SHALL become a straight block with one manual movement. The block SHALL preserve the part's name, rounds, sets per round, set rest, and round rest. The movement SHALL use the part's name and no profile. The active session SHALL survive.

#### Scenario: Upgrading a saved part

- **GIVEN** a stored part named Chest with 3 rounds, 3 sets, 60 set rest, and 120 round rest
- **WHEN** the app first launches after the update
- **THEN** it contains one straight block named Chest with one manual movement named Chest and those values

#### Scenario: Missing or unreadable plan

- **WHEN** the app launches with no readable saved plan
- **THEN** it seeds a Chest session with one straight block, one manual movement, 3 rounds, 3 sets, and 60/120 rests

### Requirement: Session and block summaries

A session SHALL summarize its number of blocks, total sets, and total rest. A block SHALL summarize its movements, its sets per movement in a straight block or rounds in a circuit, and its two rests. A total rest of 60 minutes or more SHALL show hours.

#### Scenario: Summarizing a multi-block session

- **GIVEN** a straight block with 2 movements and 3 sets each, and a circuit block with 2 movements and 3 rounds
- **WHEN** the session summary is shown
- **THEN** it reports 2 blocks and 12 total sets, and total rest equals the sum of both blocks

#### Scenario: Long total rest

- **GIVEN** a session whose total rest exceeds one hour
- **WHEN** the summary is shown
- **THEN** the duration includes an hours component

### Requirement: Name rules across sessions, blocks, and movements

Session, block, and movement names SHALL be trimmed and limited to 18 characters. An empty session name SHALL become Untitled, an empty block name Untitled block, and an empty movement name Untitled movement.

#### Scenario: Empty session name

- **WHEN** the user clears the session name and leaves the field
- **THEN** the name becomes Untitled

#### Scenario: Long block name

- **WHEN** the user types more than 18 characters into a block name
- **THEN** only the first 18 characters are kept

#### Scenario: Long movement name

- **WHEN** the user types more than 18 characters into a movement name
- **THEN** only the first 18 characters are kept

## MODIFIED Requirements

### Requirement: Rounds and sets have no upper limit

Block counts SHALL accept any integer of 1 or more: sets per movement in a straight block, rounds in a circuit. The editor MUST NOT disable increase at 6 or at any other product cap. Rest values SHALL remain between 15 and 600 seconds in steps of 15, except a block's set rest MAY be 0.

#### Scenario: Increasing past six

- **GIVEN** a block with 6 sets per movement
- **WHEN** the user taps increase
- **THEN** the value becomes 7 and the increase control stays enabled

#### Scenario: Typing a large sets value

- **WHEN** the user types 120 into SETS PER MOVEMENT and confirms
- **THEN** the block stores 120 sets per movement

#### Scenario: Rest limits are unchanged

- **GIVEN** a block with round rest 600 seconds
- **WHEN** the user tries to increase round rest
- **THEN** the value stays at 600 and the increase control is disabled

#### Scenario: Zero set rest

- **GIVEN** a superset block with set rest 0
- **WHEN** the user increases it once
- **THEN** the value becomes 15

#### Scenario: Large plan totals are exact

- **GIVEN** a straight block with 40 movements and 25 sets each
- **WHEN** the block summary is shown
- **THEN** it reports 1000 total sets with no overflow or wrapped number
