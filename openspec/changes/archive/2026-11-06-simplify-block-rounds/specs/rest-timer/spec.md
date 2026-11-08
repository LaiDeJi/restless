# Spec Delta

## ADDED Requirements

### Requirement: Sets run sequentially across blocks
A session SHALL execute every set of one block before the first set of the next block. Completed sets SHALL be counted globally across the session. Total sets SHALL equal the sum over blocks of rounds × movements × sets per round.

#### Scenario: Moving from one block to the next
- **GIVEN** a Biceps block with 3 rounds and 3 sets per round followed by a Triceps block with 2 rounds and 4 sets per round
- **WHEN** the ninth set is completed and its rest ends
- **THEN** the next set is Triceps round 1 set 1

#### Scenario: Global set count
- **GIVEN** Biceps 3 rounds × 3 sets and Triceps 2 rounds × 4 sets
- **WHEN** the session starts
- **THEN** the total set count is 17

#### Scenario: Four rounds of four sets
- **GIVEN** one block with one movement, rounds 4, sets per round 4
- **WHEN** the session starts
- **THEN** the total set count is 16

### Requirement: Rest within a block
After a set that is not the last set of its round, the next rest SHALL be the block's set rest. After the last set of a round that is not the block's last round, the next rest SHALL be the block's round rest. A movement switch inside a round SHALL use the set rest and MUST NOT start a round rest.

#### Scenario: Set rest inside a round
- **GIVEN** a block with 4 sets per round and set rest 60
- **WHEN** set 1 of round 1 is completed
- **THEN** a 60 second set rest starts

#### Scenario: Round rest after a round
- **GIVEN** a block with 4 rounds, 4 sets per round, and round rest 120
- **WHEN** set 4 of round 1 is completed
- **THEN** a 120 second round rest starts

#### Scenario: Movement switch in a superset
- **GIVEN** a block with Biceps and Triceps, 2 rounds, 1 set per round, and set rest 30
- **WHEN** the Biceps set of round 1 is completed
- **THEN** a 30 second set rest starts before Triceps, and no round rest starts

#### Scenario: Zero set rest
- **GIVEN** a block with set rest 0
- **WHEN** a set that is not the last set of its round is completed
- **THEN** the next set is ready immediately

### Requirement: Rest between blocks
After the last set of a block's last round, the next rest SHALL be that block's round rest when another block follows. When no block follows, no rest SHALL start.

#### Scenario: Transition rest
- **GIVEN** a Biceps block with round rest 120 followed by a Triceps block
- **WHEN** the last set of the Biceps block's last round is completed
- **THEN** a 120 second round rest starts and Triceps is next

#### Scenario: One-set block followed by another block
- **GIVEN** a one-round one-set block with round rest 90 followed by another block
- **WHEN** its only set is completed
- **THEN** a 90 second round rest starts

#### Scenario: Last block
- **GIVEN** the last block of a session
- **WHEN** its last set is completed
- **THEN** no rest starts and the session is done

### Requirement: Total rest counts block transitions
Session total rest SHALL include every set rest, every round rest after a non-final round, and the round rest after each block followed by another block. It SHALL exclude only the final set of the last block.

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

### Requirement: Block-aware position
The current position SHALL include the block index, block name, round, set, and movement index, all one-based where applicable. Position SHALL clamp to the last set for invalid indexes. The done state SHALL present the whole session as complete.

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
- **THEN** it clamps to the last block's last round and set

### Requirement: Timer presentation includes the block
The timer SHALL show the active block name, `BLOCK n OF m` when the session has several blocks, the current round and set, the upcoming rest or FINISH, and progress through the block. It SHALL hide the round segment when rounds is 1 and the set segment when sets per round is 1. It SHALL NOT show an arrangement label. During a rest it SHALL show the countdown and what the rest follows. Before the start it SHALL present START SESSION, READY, and the first block and movement.

#### Scenario: Ready in a four-by-four block
- **GIVEN** block 1 of 3 named Biceps, round 2 of 4, set 3 of 4
- **WHEN** the timer is ready
- **THEN** it shows Biceps, ROUND 2 OF 4, SET 3 OF 4, and no arrangement label

#### Scenario: One set per round
- **GIVEN** a block with 2 rounds and 1 set per round
- **WHEN** the timer is ready at round 2
- **THEN** it shows ROUND 2 OF 2 and no set segment

#### Scenario: One round
- **GIVEN** a block with 1 round and 3 sets per round
- **WHEN** the timer is ready at set 3
- **THEN** it shows SET 3 OF 3 and no round segment

#### Scenario: No arrangement label
- **GIVEN** a block with two movements
- **WHEN** the timer shows the position
- **THEN** it shows no SUPERSET or CIRCUIT word

#### Scenario: Before the session starts
- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** the kicker is READY, the primary action is START SESSION, and the first block and movement are previewed

### Requirement: Adaptive block map
A block SHALL be drawn as a dot grid when rounds ≤ 12, movements × sets per round ≤ 12, and total dots ≤ 72. The grid SHALL draw one row per round and one dot per set in the round, grouped by movement. A larger block SHALL be drawn as a progress bar showing completed and total sets. The timer MUST NOT draw more than 72 set dots.

#### Scenario: Four rounds of four sets
- **GIVEN** a block with 4 rounds, 4 sets per round, and one movement
- **WHEN** the timer draws the map
- **THEN** it draws 4 rows of 4 dots

#### Scenario: Two movements and two rounds
- **GIVEN** a block with 2 movements, 2 rounds, and 1 set per round
- **WHEN** the timer draws the map
- **THEN** it draws 2 rows of 2 dots, grouped by movement

#### Scenario: Large block uses a bar
- **GIVEN** a block with 20 rounds and 30 sets per round
- **WHEN** the timer draws the map
- **THEN** it draws a progress bar instead of dots and shows completed and total sets

### Requirement: Rest copy names what finished
During a rest, the timer SHALL state what finished: `AFTER SET n` for a set rest, `AFTER ROUND n` for a round rest inside a block, `AFTER <finished movement> · NEXT <next movement>` for a movement switch inside a round, and `AFTER <finished block> · NEXT <next block>` for a block transition. The kicker SHALL be `SET REST`, `ROUND REST`, or `PAUSED`.

#### Scenario: Set rest copy
- **GIVEN** a rest after set 2
- **WHEN** the timer rests
- **THEN** the kicker is SET REST and the subtitle is AFTER SET 2

#### Scenario: Movement switch copy
- **GIVEN** a set rest after Biceps inside a superset round, with Triceps next
- **WHEN** the timer rests
- **THEN** the subtitle is AFTER BICEPS · NEXT TRICEPS

#### Scenario: Round rest copy
- **GIVEN** a round rest after round 2
- **WHEN** the timer rests
- **THEN** the subtitle is AFTER ROUND 2

#### Scenario: Block transition copy
- **GIVEN** a rest after the Biceps block with Triceps next
- **WHEN** the timer rests
- **THEN** the subtitle names Biceps as finished and Triceps as next

## MODIFIED Requirements

### Requirement: Editing is locked during rest
While a session is resting or paused, editing the active session SHALL be blocked, the timer's EDIT action SHALL be hidden, and SESSIONS SHALL present plans read-only. Switching tabs MUST NOT alter the running rest. Editing SHALL become available when the session is ready or done.

#### Scenario: Read-only sessions during rest
- **GIVEN** a running set rest
- **WHEN** the user opens SESSIONS
- **THEN** session and block edit, add, delete, reorder, and activate controls are disabled

#### Scenario: Unlocked after the rest
- **GIVEN** SESSIONS is open and read-only during a rest
- **WHEN** the rest ends
- **THEN** editing controls become available without leaving the tab

### Requirement: Active plan changes reset the session
Committing a change to the active session's plan SHALL reset the session to not started with zero completed sets and no rest. Editing a non-active session SHALL NOT change the current session or timer.

#### Scenario: Editing the active plan
- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a Chest block's set rest is committed
- **THEN** the timer is not started and START SESSION begins at Chest's first set with zero completed sets

#### Scenario: Editing another session
- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a block in Arms is edited
- **THEN** the Chest session keeps its completed sets and rest

### Requirement: Session completion summary
The done state SHALL summarize the completed session by blocks, total sets, and total rest, and SHALL offer START AGAIN to restart the same plan from the first set of the first block.

#### Scenario: Starting again
- **GIVEN** a done session
- **WHEN** the user taps START AGAIN
- **THEN** the session is ready at block 1, round 1, set 1 with zero completed sets

## REMOVED Requirements

### Requirement: Sets run sequentially across parts
**Reason**: Parts are replaced by blocks, and total sets now use rounds × movements × sets per round.
**Migration**: See Sets run sequentially across blocks.

### Requirement: Rest within a part
**Reason**: Rest selection now uses rounds and sets per round instead of part rounds and part sets.
**Migration**: See Rest within a block.

### Requirement: Rest between parts
**Reason**: Part transitions are block transitions.
**Migration**: See Rest between blocks.

### Requirement: Total rest counts part transitions
**Reason**: The total now counts set rests, round rests, and block transitions for the block shape.
**Migration**: See Total rest counts block transitions.

### Requirement: Part-aware position
**Reason**: Position now includes the block, round, set, and movement.
**Migration**: See Block-aware position.

### Requirement: Timer presentation includes the part
**Reason**: The timer presents blocks and numeric round and set copy, with no arrangement label.
**Migration**: See Timer presentation includes the block.

### Requirement: Adaptive part map
**Reason**: The map now draws one row per round and one dot per set in the round.
**Migration**: See Adaptive block map.

### Requirement: Rest context copy
**Reason**: The requirement is renamed and its copy now covers movement switches and block transitions.
**Migration**: See Rest copy names what finished.
