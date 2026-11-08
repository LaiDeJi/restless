# Spec Delta

## REMOVED Requirements

### Requirement: Sets run sequentially across parts

**Reason**: A session is now a list of blocks, and a block runs its movements straight or as a circuit.

**Migration**: The block-aware requirement below preserves the sequential rule and adds the circuit order.

### Requirement: Rest within a part

**Reason**: Rest is now chosen inside a block, and the block's arrangement decides which loop is inner.

**Migration**: The block-aware rest requirement below keeps set rest inside the loop and round rest at its boundary.

### Requirement: Rest between parts

**Reason**: Parts are replaced by blocks.

**Migration**: The block transition rest uses the same round rest and the same no-rest rule at the end of the session.

### Requirement: Total rest counts part transitions

**Reason**: Totals now count block transitions and the two arrangements.

**Migration**: The block-aware total rest requirement below preserves the same arithmetic.

### Requirement: Part-aware position

**Reason**: Position now includes the block, the movement, and either the set or the round.

**Migration**: The block-aware position requirement below replaces the part position.

### Requirement: Timer presentation includes the part

**Reason**: The timer now presents a block, a movement, and a timed-set countdown.

**Migration**: The block-aware presentation requirement below replaces the part presentation.

### Requirement: Adaptive part map

**Reason**: The map is now a block map over movements and sets or rounds.

**Migration**: The block-aware map requirement below keeps the 72-dot limit and the progress-bar fallback.

### Requirement: Rest context copy

**Reason**: Rest copy now names a movement transition or a block transition, not a part transition.

**Migration**: The new rest context requirement below keeps the same subtitles with block and movement names.

## ADDED Requirements

### Requirement: Sets run sequentially across blocks

A session SHALL execute every set of one block before the first set of the next block. A straight block SHALL run every set of a movement before the next movement. A circuit block SHALL run one set of each movement per round before the next round. Total sets SHALL equal the sum over blocks of the block's sets.

#### Scenario: Straight block order

- **GIVEN** a straight block with bench press 3 sets and incline press 2 sets
- **WHEN** the block runs
- **THEN** the order is bench 1, 2, 3, then incline 1, 2

#### Scenario: Circuit block order

- **GIVEN** a circuit block with bench press and incline press, 3 rounds
- **WHEN** the block runs
- **THEN** the order is bench, incline, bench, incline, bench, incline

#### Scenario: Total sets

- **GIVEN** a straight block with 2 movements and 3 sets each, and a circuit block with 3 movements and 2 rounds
- **WHEN** the session starts
- **THEN** the total set count is 12

### Requirement: Rest within a block

In a straight block, a set that is not the movement's last SHALL be followed by the set rest; the movement's last set SHALL be followed by the round rest when another movement follows. In a circuit block, a movement that is not the round's last SHALL be followed by the set rest; the round's last movement SHALL be followed by the round rest when another round follows. A set rest MAY be 0.

#### Scenario: Straight set rest

- **GIVEN** a straight block with 3 sets of a movement and set rest 60
- **WHEN** set 1 is completed
- **THEN** a 60 second set rest starts

#### Scenario: Straight movement transition

- **GIVEN** a straight block with bench press then incline press, and round rest 120
- **WHEN** the last bench set is completed
- **THEN** a 120 second round rest starts and incline is next

#### Scenario: Circuit set rest

- **GIVEN** a circuit block with 3 movements and set rest 15
- **WHEN** the first movement of a round is completed
- **THEN** a 15 second set rest starts

#### Scenario: Circuit round rest

- **GIVEN** a circuit block with 3 rounds and round rest 90
- **WHEN** the last movement of round 1 is completed
- **THEN** a 90 second round rest starts

#### Scenario: Zero set rest

- **GIVEN** a superset block with set rest 0
- **WHEN** the first movement is completed
- **THEN** the next movement is ready immediately with no countdown

### Requirement: Rest between blocks

After the last set of a block's last round, the next rest SHALL be that block's round rest when another block follows. When no block follows, no rest SHALL start.

#### Scenario: Block transition

- **GIVEN** a Chest block with round rest 120 followed by an Arms block
- **WHEN** the last Chest set is completed
- **THEN** a 120 second round rest starts and Arms is next

#### Scenario: Last block

- **GIVEN** the last block's last set
- **WHEN** it is completed
- **THEN** no rest starts and the session is done

### Requirement: Total rest counts block transitions

Session total rest SHALL include every set rest, every round rest after a non-final round, and the round rest after each block followed by another block. It SHALL exclude only the final set of the last block.

#### Scenario: Straight block followed by another

- **GIVEN** a straight block with 2 movements, 3 sets each, set rest 60, round rest 120, followed by another block
- **WHEN** total rest is calculated
- **THEN** it equals 480 seconds: 240 of set rest plus 240 of round rest

#### Scenario: Final circuit block

- **GIVEN** a circuit block with 2 movements, 3 rounds, set rest 0, round rest 120, as the last block
- **WHEN** total rest is calculated
- **THEN** it equals 240 seconds of round rest and no set rest

### Requirement: Block-aware position

The current position SHALL include the block index, block name, movement index, movement name, and either the set index in a straight block or the round index in a circuit, all one-based. Position SHALL clamp to the last set for invalid indexes.

#### Scenario: Straight position

- **GIVEN** a straight block with bench press 3 sets and incline press 3 sets
- **WHEN** completed sets is 4
- **THEN** the position is incline press, set 1

#### Scenario: Circuit position

- **GIVEN** a circuit block with bench press and incline press, 3 rounds
- **WHEN** completed sets is 3
- **THEN** the position is round 2, bench press

#### Scenario: Position after the last set

- **GIVEN** completed sets equal total sets
- **WHEN** position is requested
- **THEN** it clamps to the last movement's last set or round

### Requirement: Timer presentation includes the block

The timer SHALL show the active block name, `BLOCK n OF m`, the active movement, and the current set or round. While ready it SHALL show the upcoming rest or FINISH. While performing a timed set it SHALL show the work countdown and the rest that follows. While resting it SHALL show the countdown and what the rest follows.

#### Scenario: Ready in a straight block

- **GIVEN** block 2 of 3 named Arms, incline press set 2 of 3
- **WHEN** the timer is ready
- **THEN** it shows Arms, BLOCK 2 OF 3, INCLINE PRESS, and SET 2 OF 3

#### Scenario: Performing a timed set

- **GIVEN** a 60 second plank with 43 seconds remaining
- **WHEN** the set is performing
- **THEN** the timer shows the work countdown and the rest that follows

#### Scenario: During a rest

- **GIVEN** a round rest after the last Chest set, before Arms
- **WHEN** the timer is resting
- **THEN** it shows the countdown and identifies Chest as finished and Arms as next

### Requirement: Adaptive block map

A block with at most 6 movements and at most 12 sets or rounds SHALL be drawn as a dot grid. A larger block SHALL be drawn as a progress bar. The timer MUST NOT draw more than 72 dots. A straight block SHALL fill rows; a circuit block SHALL fill columns.

#### Scenario: Small block uses dots

- **GIVEN** a straight block with 2 movements and 3 sets each
- **WHEN** the timer draws the map
- **THEN** it draws 6 set dots and fills the bench row before the incline row

#### Scenario: Circuit fills columns

- **GIVEN** a circuit block with 2 movements and 3 rounds
- **WHEN** the timer draws the map
- **THEN** it draws 6 set dots and fills the first round column before the second

#### Scenario: Large block uses a bar

- **GIVEN** a block with 20 movements and 30 sets
- **WHEN** the timer draws the map
- **THEN** it draws a progress bar instead of dots

### Requirement: Rest context copy names the movement or block

During a rest, the timer SHALL state what finished: `AFTER SET n` for a set rest in a straight block, `AFTER ROUND n` for a round rest in a circuit, the finished movement and the next movement for a movement transition, and the finished block and the next block for a block transition. The kicker SHALL be `SET REST`, `ROUND REST`, or `PAUSED`.

#### Scenario: Set rest copy

- **GIVEN** a rest after set 2
- **WHEN** the timer rests
- **THEN** the kicker is SET REST and the subtitle is AFTER SET 2

#### Scenario: Circuit round rest copy

- **GIVEN** a rest after round 1 of a circuit
- **WHEN** the timer rests
- **THEN** the kicker is ROUND REST and the subtitle is AFTER ROUND 1

#### Scenario: Movement transition copy

- **GIVEN** a straight block with bench press then incline press
- **WHEN** the last bench set is done and its round rest runs
- **THEN** the subtitle names bench press as finished and incline press as next

#### Scenario: Block transition copy

- **GIVEN** a rest after Chest with Arms next
- **WHEN** the timer rests
- **THEN** the subtitle names Chest as finished and Arms as next

## MODIFIED Requirements

### Requirement: Final set ends the session

After the last set of the last block, no rest SHALL follow. The session SHALL enter the done state with completed sets equal to total sets. A timed set SHALL end at its deadline and follow the same rule.

#### Scenario: Completing the session

- **GIVEN** the last set of the last block is ready
- **WHEN** the user marks it done
- **THEN** the session is done, no countdown starts, and completed sets equal total sets

#### Scenario: Completing on a timed final set

- **GIVEN** the last set of the last block is a 60 second hold that is performing
- **WHEN** its deadline passes
- **THEN** the session is done with no rest

### Requirement: State machine and guards

The session SHALL have ready, performing, resting, paused, and done states. Set done SHALL apply in ready or performing. Start set SHALL apply only in ready for a timed set. Pause SHALL apply only in resting. Resume SHALL apply only in paused. Skip rest SHALL apply only in resting or paused. Restart SHALL return to ready with zero completed sets.

#### Scenario: Double tap consumes one set

- **GIVEN** a ready set
- **WHEN** set done is applied twice in a row
- **THEN** exactly one set is completed

#### Scenario: Pausing longer than the rest

- **GIVEN** a rest with 30 seconds remaining
- **WHEN** the user pauses, waits 5 minutes, and resumes
- **THEN** the rest still has 30 seconds remaining

#### Scenario: Skipping rest

- **GIVEN** a running rest after set 2
- **WHEN** the user skips the rest
- **THEN** the session is ready at the next set and completed sets is unchanged

#### Scenario: Starting a timed set

- **GIVEN** a ready set with end condition time and target 60
- **WHEN** start set is applied
- **THEN** the set is performing with a 60 second deadline

#### Scenario: Ending a timed set early

- **GIVEN** a performing timed set with 30 seconds remaining
- **WHEN** the user taps SET DONE
- **THEN** the set is done and its rest starts

#### Scenario: A timed set expires

- **GIVEN** a performing timed set whose deadline has passed
- **WHEN** the session reconciles
- **THEN** the set is done and its rest starts

### Requirement: Deadline-based time

Rest remaining and timed-set remaining SHALL be derived from stored deadlines rather than decrementing counters. A ticker MAY trigger redraws only. Returning to the app SHALL reconcile both deadlines before drawing.

#### Scenario: Returning after the rest expired

- **GIVEN** a rest with 20 seconds remaining
- **WHEN** the app is inactive for 60 seconds and becomes active
- **THEN** the rest is finished and the session is ready at the next set

#### Scenario: Returning during a timed set

- **GIVEN** a performing timed set with 20 seconds remaining
- **WHEN** the app is inactive for 60 seconds and becomes active
- **THEN** the set is finished and its rest has started

### Requirement: Editing is locked during rest

While a session is performing, resting, or paused, editing the active session SHALL be blocked, the timer's EDIT action SHALL be hidden, and SESSIONS SHALL present plans read-only. Switching tabs MUST NOT alter the running set or rest. Editing SHALL become available when the session is ready or done.

#### Scenario: Read-only sessions during rest

- **GIVEN** a running set rest
- **WHEN** the user opens SESSIONS
- **THEN** session, block, movement, add, delete, reorder, and activate controls are disabled

#### Scenario: Read-only during a timed set

- **GIVEN** a performing timed set
- **WHEN** the user opens SESSIONS
- **THEN** editing controls are disabled

#### Scenario: Unlocked after the rest

- **GIVEN** SESSIONS is open and read-only during a rest
- **WHEN** the rest ends
- **THEN** editing controls become available without leaving the tab

### Requirement: Active plan changes reset the session

Committing a change to the active session's plan SHALL reset the session to ready with zero completed sets, no rest, and no running timed set. Editing a non-active session SHALL NOT change the current session or timer.

#### Scenario: Editing the active plan

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a Chest block's set rest is committed
- **THEN** the timer is ready at Chest's first set with zero completed sets

#### Scenario: Editing another session

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a block in Arms is edited
- **THEN** the Chest session keeps its completed sets and rest

### Requirement: Session completion summary

The done state SHALL summarize the completed session by blocks, movements, total sets, and total rest, and SHALL offer START AGAIN to restart the same plan from the first set of the first block.

#### Scenario: Starting again

- **GIVEN** a done session
- **WHEN** the user taps START AGAIN
- **THEN** the session is ready at block 1, movement 1, set 1 with zero completed sets

#### Scenario: Summary

- **GIVEN** a done session with 2 blocks and 12 sets
- **WHEN** the done state is shown
- **THEN** it reports 2 blocks, 12 sets, and the total rest
