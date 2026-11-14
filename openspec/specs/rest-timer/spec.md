# Rest Timer Specification

## Purpose

Runs a session plan as a deadline-based sequence of untimed sets across ordered parts, choosing the correct rest after every set and presenting part, round, and set progress on the timer.

## Requirements

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

### Requirement: Final set ends the session

After the last set of the last part, no rest SHALL follow. The session SHALL enter the done state with completed sets equal to total sets.

#### Scenario: Completing the session

- **GIVEN** the last set of the last part is ready
- **WHEN** the user marks it done
- **THEN** the session is done, no countdown starts, and completed sets equal total sets

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

### Requirement: Session start gate

A session selected for the first time, and the app with no saved run, SHALL open in a not-started state. The timer's primary action in that state SHALL be START SESSION, and the session MUST NOT count sets or start a Live Activity before it is started.

#### Scenario: Launching a fresh session

- **GIVEN** a stored active session and no saved run
- **WHEN** the app launches
- **THEN** the timer is not started with zero completed sets

#### Scenario: Activating another session

- **GIVEN** Chest is active with completed sets
- **WHEN** the user activates Arms
- **THEN** the timer is not started at Arms with zero completed sets

#### Scenario: The gate runs nothing

- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** no set is counted and no Live Activity exists

### Requirement: Start session transition

START SESSION SHALL move a not-started session to ready at the first set of the first block without completing a set. Applying START SESSION in any other state SHALL be ignored.

#### Scenario: Starting normally

- **GIVEN** a not-started session
- **WHEN** START SESSION is applied
- **THEN** the session is ready at block 1, set 1 with zero completed sets and no rest

#### Scenario: Starting twice

- **GIVEN** a ready session
- **WHEN** START SESSION is applied
- **THEN** the state and completed sets are unchanged

### Requirement: State machine and guards

The session SHALL have not-started, ready, resting, paused, and done states. Start session SHALL apply only in not-started. Set done SHALL apply only in ready. Pause SHALL apply only in resting. Resume SHALL apply only in paused. Skip rest SHALL apply only in resting or paused. Restart SHALL return to ready with zero completed sets.

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

#### Scenario: Set done before the start

- **GIVEN** a not-started session
- **WHEN** set done is applied
- **THEN** no set is completed and the session remains not started

### Requirement: Deadline-based time

Rest remaining SHALL be derived from a stored deadline rather than a decrementing counter. A ticker MAY trigger redraws only. Returning to the app SHALL reconcile the deadline before drawing.

#### Scenario: Returning after the rest expired

- **GIVEN** a rest with 20 seconds remaining
- **WHEN** the app is inactive for 60 seconds and becomes active
- **THEN** the rest is finished and the session is ready at the next set

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

### Requirement: Timer presentation includes the block

The timer SHALL show the active block, the current movement, the current round and set, the upcoming rest or FINISH, and progress through the block. During a rest it SHALL show the countdown and what the rest follows. Before the start it SHALL present START SESSION, READY, and the first block and movement.

#### Scenario: Before the session starts

- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** the kicker is READY, the primary action is START SESSION, and the first block and movement are previewed once

### Requirement: The active block is named once

The timer SHALL name the active block exactly once: the block strip names it when the session has several blocks; otherwise the position strip names it, and only when the block name differs from the movement name.

#### Scenario: A rest does not repeat the block

- **GIVEN** block 2 of 2 named Triceps, resting after set 5
- **WHEN** the timer shows the rest
- **THEN** Triceps appears only in the block strip and the position strip reads UP NEXT · movement · round · set

#### Scenario: A single block names itself once

- **GIVEN** the only block is named Chest and its movement is also named Chest
- **WHEN** the timer is shown
- **THEN** CHEST appears once in the position strip

### Requirement: The position strip omits empty segments

The position strip SHALL NOT carry a `BLOCK n OF m` segment. It SHALL hide the round segment when rounds is 1 and the set segment when sets per round is 1, SHALL NOT show an arrangement label, and SHALL prefix `UP NEXT` during a rest. It SHALL stay on one line at default text sizes, and MAY wrap above the countdown ring at accessibility sizes.

#### Scenario: Ready in a four-by-four block

- **GIVEN** block 1 of 3 named Biceps, round 2 of 4, set 3 of 4
- **WHEN** the timer is ready
- **THEN** it shows Biceps once, ROUND 2 OF 4, SET 3 OF 4, no BLOCK 1 OF 3 segment, and no arrangement label

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

#### Scenario: The strip stays one line

- **GIVEN** a two-block session resting after set 5 at the default text size
- **WHEN** the position strip is shown
- **THEN** it occupies one line above the countdown ring

### Requirement: Restart control visibility

The timer SHALL offer a RESTART control while a session is in progress and at least one set is done. The control SHALL be hidden before the first set and in done, where START AGAIN is the primary action. It SHALL remain available while editing is locked.

#### Scenario: Nothing to restart before the first set

- **GIVEN** a not-started session, or a started session with zero completed sets
- **WHEN** the timer is shown
- **THEN** no RESTART control is offered

#### Scenario: Done uses START AGAIN

- **GIVEN** a done session
- **WHEN** the timer is shown
- **THEN** no RESTART control is offered and START AGAIN remains the primary action

#### Scenario: Restart is not editing

- **GIVEN** a session resting, with editing locked
- **WHEN** the timer is shown
- **THEN** the RESTART control is available while EDIT stays hidden, and editing unlocks only when the restart lands in the start gate

### Requirement: Restart asks for confirmation

Tapping RESTART SHALL open a confirmation dialog that names the consequence: completed sets are cleared, the current rest or timed set is cancelled, and the session returns to block 1, set 1. Confirming SHALL apply the restart transition, which lands in the start gate at block 1, set 1 with zero completed sets and ends the session Live Activity. Cancelling SHALL leave the session unchanged. An open dialog SHALL dismiss when the phase changes.

#### Scenario: Restart after a completed set

- **GIVEN** a session ready at set 3 with two sets completed
- **WHEN** the user taps RESTART
- **THEN** a confirmation dialog names the cleared sets and the return to block 1, set 1, and the session is unchanged
- **AND** confirming lands in the start gate at block 1, round 1, set 1 with zero completed sets, shows START SESSION, and leaves no Live Activity

#### Scenario: Cancelling the dialog

- **GIVEN** a session resting after set 7
- **WHEN** the user taps RESTART and then Cancel
- **THEN** the rest continues with the same remaining time and completed sets

#### Scenario: Restart from a rest

- **GIVEN** a session resting after set 7
- **WHEN** the user taps RESTART and confirms
- **THEN** the rest is cleared and the session is not started at block 1, set 1 with zero completed sets

#### Scenario: Restart from a timed set

- **GIVEN** a session performing a timed set after at least one completed set
- **WHEN** the user taps RESTART and confirms
- **THEN** the work countdown is cleared and the session is not started at block 1, set 1 with zero completed sets

#### Scenario: The dialog closes on a phase change

- **GIVEN** an open restart dialog
- **WHEN** the rest ends or the session changes phase
- **THEN** the dialog closes without applying a restart

### Requirement: A countdown end advances the timer and raises the completion alert

When a rest or timed work countdown reaches zero, the timer SHALL apply the matching transition once and raise the completion alert defined by the countdown-alerts capability. A second delivery of the same deadline MUST NOT advance the session again.

#### Scenario: A rest expires

- **GIVEN** a running rest
- **WHEN** the deadline passes
- **THEN** the timer is ready at the next set and one completion alert is raised

#### Scenario: A timed work set expires

- **GIVEN** a running timed work set
- **WHEN** its deadline passes
- **THEN** the set is completed once, the following rest or done state is shown, and one completion alert is raised

#### Scenario: A late reconcile

- **GIVEN** a deadline that passed while the app was inactive
- **WHEN** the app becomes active
- **THEN** the timer reconciles once and does not raise a second alert for the same deadline

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

### Requirement: Session completion summary

The done state SHALL summarize the completed session by blocks, total sets, and total rest, and SHALL offer START AGAIN to restart the same plan from the first set of the first block.

#### Scenario: Starting again

- **GIVEN** a done session
- **WHEN** the user taps START AGAIN
- **THEN** the session is ready at block 1, round 1, set 1 with zero completed sets

### Requirement: Stable timer hero

The timer's countdown ring SHALL keep one fixed vertical centre in the timer viewport on every block and phase. The block strip, position strip, and set map SHALL NOT move that centre as their copy wraps or their row count changes. When the top chrome and the ring cannot both fit, the ring SHALL sit below the chrome and the page SHALL scroll.

#### Scenario: Moving from a short block to a tall block

- **GIVEN** block 1 with one round and a one-row set map, and block 2 with three rounds and a three-row set map
- **WHEN** the timer leaves block 1 and counts down from block 2
- **THEN** the countdown ring keeps the same vertical centre

#### Scenario: A wrapping position strip

- **GIVEN** block 2 whose position strip needs two lines while block 1's needs one
- **WHEN** block 2 becomes active
- **THEN** the additional line stays above the ring and the ring does not move

#### Scenario: Starting and ending a rest

- **GIVEN** a ready set and the rest that follows it
- **WHEN** the rest starts and later returns to ready
- **THEN** the countdown ring keeps the same vertical centre throughout

#### Scenario: Chrome and ring cannot both fit

- **GIVEN** a viewport whose top chrome and countdown ring cannot both fit at the same time
- **WHEN** the timer appears
- **THEN** the ring sits below the chrome and the rest of the page is reachable by scrolling

### Requirement: Timer content sits below the ring

The set map SHALL render below the countdown ring. When the content below the ring cannot fit, the timer page SHALL scroll rather than move the ring.

#### Scenario: A map too tall for one screen

- **GIVEN** a block whose set map and caption extend below the available space
- **WHEN** the timer shows that block
- **THEN** the ring keeps its centre on first display and the rest of the page is reachable by scrolling

#### Scenario: Accessibility text sizes

- **GIVEN** an accessibility text size
- **WHEN** the timer first appears
- **THEN** the ring is centred and the content that no longer fits is reachable by scrolling

### Requirement: Session completion celebration

Entering the done state after the final set SHALL play one celebration on the
TIMER screen for about 2.5 seconds: a non-blocking confetti burst in the Restless
accent colours. The effect SHALL play once per completion and MUST NOT replay
when a done session is restored at launch or revisited. With Reduce Motion
enabled it SHALL use a brief static accent glow instead of moving particles.

#### Scenario: The final set plays the celebration

- **GIVEN** the last set of the session is ready
- **WHEN** the user marks it done
- **THEN** the session enters done and the celebration appears over the done
  screen

#### Scenario: A restored done session does not celebrate

- **GIVEN** a saved snapshot that is already done
- **WHEN** the app launches and shows TIMER
- **THEN** no celebration plays

#### Scenario: Done reached on another tab celebrates on return

- **GIVEN** the final set completes while another tab is visible
- **WHEN** the user returns to TIMER
- **THEN** the celebration plays once for that completion

#### Scenario: Reduce Motion uses the static glow

- **GIVEN** Reduce Motion is enabled
- **WHEN** the final set is marked done
- **THEN** a brief static accent glow appears and no particles move

#### Scenario: The celebration ends by itself

- **GIVEN** the celebration is playing
- **WHEN** about 2.5 seconds pass
- **THEN** the effect disappears and the done screen stays

### Requirement: The celebration has no side effects

The celebration MUST NOT change the phase, completed sets, history, completion
alerts, haptics, audio, notifications or the Live Activity. It MUST NOT block
the timer's controls, and START AGAIN SHALL remain usable while it plays.

#### Scenario: START AGAIN works during the celebration

- **GIVEN** the celebration is playing on the done screen
- **WHEN** the user taps START AGAIN
- **THEN** the session restarts immediately and the effect does not delay or
  block the tap

#### Scenario: No second alert or haptic

- **GIVEN** the final set is marked done in the foreground
- **WHEN** the celebration plays
- **THEN** no sound, extra haptic, notification or alerting Live Activity update
  is added by the effect

#### Scenario: History is unchanged

- **GIVEN** the final set is marked done
- **WHEN** the record is shown in CALENDAR
- **THEN** the run is finished with its normal completed sets and finish time
