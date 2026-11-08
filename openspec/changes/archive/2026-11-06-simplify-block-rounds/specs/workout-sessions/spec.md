# Spec Delta

## ADDED Requirements

### Requirement: Session plans are ordered blocks
A session SHALL have a stable identifier, a name, and one or more ordered blocks. Each block SHALL have a stable identifier, a name, rounds, sets per round, set rest, round rest, and one or more block movements. Rounds and sets per round SHALL be 1 or more. Blocks SHALL run in the order shown in the session.

#### Scenario: A session stores blocks in order
- **GIVEN** a session containing Biceps followed by Triceps
- **WHEN** the session is opened
- **THEN** Biceps is the first block and Triceps is the second block

#### Scenario: A session never has zero blocks
- **WHEN** the only block in a session is deleted
- **THEN** the deletion is refused and the block remains

### Requirement: Block structure has no arrangement mode
A block SHALL define its schedule only by rounds, sets per round, and its ordered movements. It SHALL NOT store or expose a straight/circuit arrangement. One movement SHALL repeat that movement; two or more movements SHALL run each movement's sets-per-round sets in order within each round. A sequential pair SHALL be two blocks.

#### Scenario: One movement, four rounds of four sets
- **GIVEN** a block with one movement, rounds 4, sets per round 4
- **WHEN** the block is shown
- **THEN** it reports 16 sets and contains no arrangement label

#### Scenario: Two movements, two rounds of one set each
- **GIVEN** a block with Biceps and Triceps, rounds 2, sets per round 1
- **WHEN** the block runs
- **THEN** each round runs Biceps then Triceps and the block reports 4 sets

#### Scenario: Sequential pair
- **GIVEN** a user wants Biceps three sets followed by Triceps three sets
- **WHEN** they build the plan
- **THEN** it is two blocks, each with rounds 1 and sets per round 3

### Requirement: Block management
From the session editor a user SHALL add, rename, reorder, and delete blocks. A new block SHALL inherit the previous block's rest values, copy no movements, and open the movement picker; the picked movement SHALL be its first. Each row SHALL be draggable by a grip and SHALL offer delete except when it is the only block. A session MUST keep one block. Delete SHALL require two taps; drag and delete SHALL be disabled while editing is locked.

#### Scenario: Adding a block does not clone movements
- **GIVEN** a session whose last block is Biceps
- **WHEN** the user adds a block and picks Triceps
- **THEN** the new block contains only Triceps and inherits the last block's set and round rests

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

### Requirement: Block copy is numeric
Block rows and summaries SHALL describe a block with movements, rounds, sets per round, total sets, and the two rest values. They SHALL NOT show STRAIGHT, SUPERSET, or CIRCUIT.

#### Scenario: Two-movement block row
- **GIVEN** a block with 2 movements, 2 rounds, 1 set per round
- **WHEN** the session editor shows the row
- **THEN** it reads 2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS, with no SUPERSET or CIRCUIT

#### Scenario: One-movement block row
- **GIVEN** a block with 1 movement, 4 rounds, 4 sets per round
- **WHEN** the session editor shows the row
- **THEN** it reads 1 MOVEMENT · 4 ROUNDS · 4 SETS EACH · 16 SETS

### Requirement: Stored plans migrate to rounds and sets per round
Stored plans SHALL read into the new block shape without losing sets or rest. A legacy part R × S SHALL become one block with rounds R, sets per round S, one manual movement, and its name and rests. A straight block with count C SHALL become rounds 1, sets per round C; with several movements it SHALL split into one block per movement. A circuit with count C SHALL become rounds C, sets per round 1. The active session SHALL survive; an unreadable plan SHALL fall back to the Chest seed.

#### Scenario: Legacy part
- **GIVEN** a stored part named Chest with 3 rounds, 3 sets, 60 set rest, 120 round rest
- **WHEN** the app opens it after the update
- **THEN** it is one block named Chest with rounds 3, sets per round 3, and those rests

#### Scenario: Straight block
- **GIVEN** a stored straight block with count 9 and one movement
- **WHEN** it is read
- **THEN** it has rounds 1 and sets per round 9

#### Scenario: Straight block with two movements
- **GIVEN** a stored straight block with Bench and Incline, count 3
- **WHEN** it is read
- **THEN** it becomes two blocks, Bench then Incline, each with rounds 1 and sets per round 3

#### Scenario: Circuit block
- **GIVEN** a stored circuit block with Biceps and Triceps, count 3
- **WHEN** it is read
- **THEN** it has rounds 3 and sets per round 1

### Requirement: Duplicate movement rows collapse
Adjacent duplicate movements in a stored circuit SHALL collapse into one movement with sets per round equal to the duplicate count when they share the same library movement, end condition, and target. Duplicates that are not adjacent or differ SHALL remain separate movements.

#### Scenario: Four Biceps rows
- **GIVEN** a stored circuit with four adjacent Biceps rows, count 4, same end condition and target
- **WHEN** it is read
- **THEN** it becomes one Biceps movement with rounds 4 and sets per round 4

#### Scenario: Different targets
- **GIVEN** a stored circuit with two adjacent Biceps rows with different targets
- **WHEN** it is read
- **THEN** both movements remain

### Requirement: Session and block summaries
A session SHALL summarize its number of blocks, total sets, and total rest. A block SHALL summarize its movements, rounds, sets per round, total sets, and its two rest values. A total rest of 60 minutes or more SHALL be shown with hours.

#### Scenario: Summarizing a multi-block session
- **GIVEN** Biceps 3 rounds × 3 sets with 60/120 and Triceps 2 rounds × 4 sets with 45/90
- **WHEN** the session summary is shown
- **THEN** it reports 2 blocks and 17 total sets, and total rest is 1080 seconds

#### Scenario: Long total rest
- **GIVEN** a session whose total rest exceeds one hour
- **WHEN** the summary is shown
- **THEN** the duration includes an hours component

### Requirement: Name rules for sessions and blocks
Session and block names SHALL be trimmed and limited to 18 characters. An empty session name SHALL become Untitled. An empty block name SHALL become Untitled block.

#### Scenario: Empty session name
- **WHEN** the user clears the session name and leaves the field
- **THEN** the name becomes Untitled

#### Scenario: Long block name
- **WHEN** the user types more than 18 characters into a block name
- **THEN** only the first 18 characters are kept

## MODIFIED Requirements

### Requirement: Rounds and sets have no upper limit
Rounds and sets per round SHALL accept any integer of 1 or more. The editor MUST NOT disable increase at 6 or at any other product cap. Set rest SHALL be 0 or 15–600 seconds in 15-second steps; round rest SHALL be 15–600 seconds in 15-second steps.

#### Scenario: Increasing past six
- **GIVEN** a block with 6 rounds
- **WHEN** the user taps increase on ROUNDS
- **THEN** the value becomes 7 and the increase control stays enabled

#### Scenario: Typing a large sets value
- **WHEN** the user types 120 into SETS PER ROUND and confirms
- **THEN** the block stores 120 sets per round

#### Scenario: Rest limits are unchanged
- **GIVEN** a block with set rest 600 seconds
- **WHEN** the user tries to increase set rest
- **THEN** the value stays at 600 and the increase control is disabled

#### Scenario: Zero set rest
- **GIVEN** a block with set rest 0
- **WHEN** the user increases set rest once
- **THEN** it becomes 15 seconds

#### Scenario: Large plan totals are exact
- **GIVEN** a block with 40 rounds, 25 sets per round, and one movement
- **WHEN** the block summary is shown
- **THEN** it reports 1000 total sets with no overflow or wrapped number

### Requirement: Exact numeric entry for rounds and sets
Tapping a rounds or sets-per-round value SHALL open numeric entry for that value. Committing an integer of 1 or more SHALL set the value exactly. Committing a number below 1 SHALL clamp it to 1. Empty or non-numeric input SHALL leave the previous value unchanged.

#### Scenario: Entering an exact value
- **GIVEN** a block with 3 sets per round
- **WHEN** the user taps the value, types 12, and confirms
- **THEN** the block has 12 sets per round

#### Scenario: Entering zero
- **WHEN** the user types 0 and confirms
- **THEN** the value becomes 1

#### Scenario: Leaving the field empty
- **GIVEN** a block with 4 rounds
- **WHEN** the user clears the field and confirms without typing
- **THEN** rounds remains 4

## REMOVED Requirements

### Requirement: Session plans are ordered parts
**Reason**: A session is now made of blocks with rounds and sets per round, not parts with one set count.
**Migration**: Each stored part becomes a block; see Stored plans migrate to rounds and sets per round.

### Requirement: Part management
**Reason**: Blocks are no longer cloned from the previous block, and the block list uses block fields rather than part fields.
**Migration**: Existing blocks keep their movements; new blocks start from the picked movement.

### Requirement: Existing presets migrate to one-part sessions
**Reason**: The stored block shape has changed.
**Migration**: See Stored plans migrate to rounds and sets per round.

### Requirement: Session and part summaries
**Reason**: Summaries use rounds, sets per round, and total sets; parts are gone.
**Migration**: See Session and block summaries.

### Requirement: Name rules
**Reason**: The requirement is renamed and its copy uses block names.
**Migration**: See Name rules for sessions and blocks.
