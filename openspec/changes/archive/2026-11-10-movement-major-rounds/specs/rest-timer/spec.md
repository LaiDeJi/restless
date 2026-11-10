# Spec Delta

## MODIFIED Requirements

### Requirement: Total rest counts block transitions

Session total rest SHALL include every set rest, every round rest between rounds of a movement, the round rest at each movement switch, and the round rest after each block followed by another block. It SHALL exclude only the final set of the last block.

#### Scenario: Four rounds of four sets
- **GIVEN** one block with 4 rounds, 4 sets per round, set rest 60, and round rest 120
- **WHEN** total rest is calculated without a following block
- **THEN** it is 1080 seconds: 12 set rests and 3 round rests

#### Scenario: Totals across two blocks
- **GIVEN** Biceps 3 rounds × 3 sets with 60/120 and Triceps 2 rounds × 4 sets with 45/90
- **WHEN** total rest is calculated
- **THEN** it is 1080 seconds

#### Scenario: Final set has no rest
- **GIVEN** the last set of the last block
- **WHEN** total rest is calculated
- **THEN** the rest after that set is excluded

#### Scenario: Two movements, three rounds, two sets
- **GIVEN** one block with Biceps and Triceps, 3 rounds, 2 sets per round, set rest 60, and round rest 120
- **WHEN** total rest is calculated without a following block
- **THEN** it is 960 seconds: 6 set rests and 5 round rests, one of them at the movement switch

### Requirement: Block-aware position

The current position SHALL include the block index, block name, movement index, round, and set, all one-based where applicable. Within a block each movement SHALL run all of its rounds, in order, before the next movement starts. Position SHALL clamp to the last set for invalid indexes. The done state SHALL present the whole session as complete.

#### Scenario: Position at a block boundary
- **GIVEN** a 3 × 3 Biceps block followed by a 2 × 4 Triceps block
- **WHEN** completed sets is 9
- **THEN** the position is block 2, round 1, set 1

#### Scenario: Position inside a round
- **GIVEN** a block with one movement, 4 rounds, and 4 sets per round
- **WHEN** completed sets is 5
- **THEN** the position is round 2, set 2

#### Scenario: Position after the last set
- **GIVEN** completed sets equals total sets
- **WHEN** position is requested
- **THEN** it clamps to the last block's last movement, last round, and last set

#### Scenario: Position across movements
- **GIVEN** a block with Biceps and Triceps, 3 rounds, and 2 sets per round
- **WHEN** completed sets is 6
- **THEN** the position is Triceps, round 1, set 1

#### Scenario: Position in a later round of the first movement
- **GIVEN** a block with Biceps and Triceps, 3 rounds, and 2 sets per round
- **WHEN** completed sets is 4
- **THEN** the position is Biceps, round 3, set 1

### Requirement: Adaptive block map

A block SHALL be drawn as a dot grid when it has at most 12 rows, at most 12 sets per row, and at most 72 set dots in total. Its rows SHALL be the movements' rounds in run order: one row per round of each movement, with a gap between movements, and one dot per set in that round. A larger block SHALL be drawn as a progress bar showing completed and total sets. The timer MUST NOT draw more than 72 set dots.

#### Scenario: Four rounds of four sets
- **GIVEN** a block with 4 rounds, 4 sets per round, and one movement
- **WHEN** the timer draws the map
- **THEN** it draws 4 rows of 4 dots

#### Scenario: Two movements and two rounds
- **GIVEN** a block with 2 movements, 2 rounds, and 1 set per round
- **WHEN** the timer draws the map
- **THEN** it draws 4 rows of 1 dot, two rows for each movement, with a gap between the movements

#### Scenario: Large block uses a bar
- **GIVEN** a block with 20 rounds and 30 sets per round
- **WHEN** the timer draws the map
- **THEN** it draws a progress bar instead of dots and shows completed and total sets

#### Scenario: Two movements in run order
- **GIVEN** a block with Biceps and Triceps, 3 rounds, and 2 sets per round
- **WHEN** the timer draws the map
- **THEN** it draws 6 rows of 2 dots, Biceps' three rows above Triceps' three rows, with a gap between them

### Requirement: Rest copy names what finished

During a rest, the timer SHALL state what finished: `AFTER SET n` for a set rest, `AFTER ROUND n` for a round rest between rounds of one movement, `AFTER <finished movement> · NEXT <next movement>` for a movement switch, and `AFTER <finished block> · NEXT <next block>` for a block transition. The kicker SHALL be `SET REST` for a set rest, `ROUND REST` for every other rest, or `PAUSED`.

#### Scenario: Set rest copy
- **GIVEN** a rest after set 2
- **WHEN** the timer rests
- **THEN** the kicker is SET REST and the subtitle is AFTER SET 2

#### Scenario: Movement switch copy
- **GIVEN** a round rest after Biceps' last round, with Triceps next
- **WHEN** the timer rests
- **THEN** the kicker is ROUND REST and the subtitle is AFTER BICEPS · NEXT TRICEPS

#### Scenario: Round rest copy
- **GIVEN** a round rest after round 2 of one movement
- **WHEN** the timer rests
- **THEN** the subtitle is AFTER ROUND 2

#### Scenario: Block transition copy
- **GIVEN** a rest after the Biceps block with Triceps next
- **WHEN** the timer rests
- **THEN** the subtitle names Biceps as finished and Triceps as next

## REMOVED Requirements

### Requirement: Rest within a block

**Reason**: A movement switch now takes the round rest, not the set rest, and the old requirement's scenario names a superseded superset shape. A MODIFIED block cannot drop a scenario, so the rule is restated under a new name.

**Migration**: The requirement "Rest after each set follows the run order" below replaces it when the change is archived.

## ADDED Requirements

### Requirement: Rest after each set follows the run order

After a set that is not the last set of its movement's round, the next rest SHALL be the block's set rest. After the last set of a round that is not the movement's last round, the next rest SHALL be the block's round rest. After the last set of a movement's last round when another movement follows in the block, the next rest SHALL be the block's round rest and MUST NOT be the set rest.

#### Scenario: Set rest inside a round
- **GIVEN** a block with 4 sets per round and set rest 60
- **WHEN** set 1 of round 1 is completed
- **THEN** a 60 second set rest starts

#### Scenario: Round rest after a round
- **GIVEN** a block with 4 rounds, 4 sets per round, and round rest 120
- **WHEN** set 4 of round 1 is completed
- **THEN** a 120 second round rest starts

#### Scenario: Round rest between rounds of one movement
- **GIVEN** a block with Biceps and Triceps, 2 rounds, 1 set per round, set rest 30, and round rest 120
- **WHEN** the Biceps set of round 1 is completed
- **THEN** a 120 second round rest starts and Biceps round 2 is next

#### Scenario: Movement switch is a round rest
- **GIVEN** a block with Biceps and Triceps, 2 rounds, 1 set per round, set rest 30, and round rest 120
- **WHEN** the Biceps set of round 2 is completed
- **THEN** a 120 second round rest starts, Triceps round 1 is next, and no 30 second set rest starts

#### Scenario: Zero set rest
- **GIVEN** a block with set rest 0
- **WHEN** a set that is not the last set of its round is completed
- **THEN** the next set is ready immediately
