# Spec Delta

## Purpose

Runs a session plan as a deadline-based sequence of untimed sets across ordered parts, choosing the correct rest after every set and presenting part, round, and set progress on the timer.

## ADDED Requirements

### Requirement: Sets run sequentially across parts

A session SHALL execute every set of one part before the first set of the next part. Completed sets SHALL be counted globally across the session. Total sets SHALL equal the sum of rounds × sets per round over all parts.

#### Scenario: Moving from one part to the next

- **GIVEN** Biceps 3 × 3 followed by Triceps 2 × 4
- **WHEN** the ninth set is completed and its rest ends
- **THEN** the next set is Triceps round 1 set 1

#### Scenario: Global set count

- **GIVEN** Biceps 3 × 3 and Triceps 2 × 4
- **WHEN** the session starts
- **THEN** the total set count is 17

### Requirement: Rest within a part

After a set that is not the last set of its round, the next rest SHALL be that part's set rest. After the last set of a round that is not the part's last round, the next rest SHALL be that part's round rest.

#### Scenario: Set rest inside a round

- **GIVEN** a part with 3 sets per round and set rest 60
- **WHEN** set 1 of round 1 is completed
- **THEN** a 60 second set rest starts

#### Scenario: Round rest after a round

- **GIVEN** a part with 3 rounds, 3 sets per round, and round rest 120
- **WHEN** set 3 of round 1 is completed
- **THEN** a 120 second round rest starts

### Requirement: Rest between parts

After the last set of a part's last round, the next rest SHALL be that part's round rest when another part follows. When no part follows, no rest SHALL start.

#### Scenario: Transition rest

- **GIVEN** Biceps with round rest 120 followed by Triceps
- **WHEN** the last set of Biceps round 3 is completed
- **THEN** a 120 second round rest starts and Triceps is next

#### Scenario: One-set part followed by another part

- **GIVEN** a one-round one-set part with round rest 90 followed by another part
- **WHEN** its only set is completed
- **THEN** a 90 second round rest starts

### Requirement: Final set ends the session

After the last set of the last part, no rest SHALL follow. The session SHALL enter the done state with completed sets equal to total sets.

#### Scenario: Completing the session

- **GIVEN** the last set of the last part is ready
- **WHEN** the user marks it done
- **THEN** the session is done, no countdown starts, and completed sets equal total sets

### Requirement: Total rest counts part transitions

Session total rest SHALL include every set rest, every round rest after a non-final round, and the round rest after each part followed by another part. It SHALL exclude only the final set of the last part.

#### Scenario: Totals across two parts

- **GIVEN** Biceps 3 × 3 with 60/120 and Triceps 2 × 4 with 45/90
- **WHEN** total rest is calculated
- **THEN** it equals 1080 seconds: 360 + 240 + 120 for Biceps and 270 + 90 for Triceps

### Requirement: State machine and guards

The session SHALL have ready, resting, paused, and done states. Set done SHALL apply only in ready. Pause SHALL apply only in resting. Resume SHALL apply only in paused. Skip rest SHALL apply only in resting or paused. Restart SHALL return to ready with zero completed sets.

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

### Requirement: Deadline-based time

Rest remaining SHALL be derived from a stored deadline rather than a decrementing counter. A ticker MAY trigger redraws only. Returning to the app SHALL reconcile the deadline before drawing.

#### Scenario: Returning after the rest expired

- **GIVEN** a rest with 20 seconds remaining
- **WHEN** the app is inactive for 60 seconds and becomes active
- **THEN** the rest is finished and the session is ready at the next set

### Requirement: Part-aware position

The current position SHALL include the part index, part name, round, and set, all one-based. Position SHALL clamp to the last set for invalid indexes. The done state SHALL present the whole session as complete.

#### Scenario: Position at a part boundary

- **GIVEN** a 3 × 3 part followed by a 2 × 4 part
- **WHEN** completed sets is 9
- **THEN** the position is part 2, round 1, set 1

#### Scenario: Position after the last set

- **GIVEN** completed sets equal total sets
- **WHEN** position is requested
- **THEN** it clamps to the last part's last round and set

### Requirement: Timer presentation includes the part

The timer SHALL show the active part name, `PART n OF m`, the current round and set, the upcoming rest or FINISH, and progress through the active part. During a rest it SHALL show the countdown and what the rest follows.

#### Scenario: Ready inside a part

- **GIVEN** part 2 of 3 named Triceps, round 1 of 2, set 1 of 4
- **WHEN** the timer is ready
- **THEN** it shows Triceps, PART 2 OF 3, ROUND 1 OF 2, and SET 1 OF 4

#### Scenario: During a part transition rest

- **GIVEN** the round rest after the last Biceps set, before Triceps
- **WHEN** the timer is resting
- **THEN** it shows the countdown and identifies Biceps as finished and Triceps as next

### Requirement: Adaptive part map

A part with at most 6 rounds and at most 12 sets per round SHALL be drawn as a dot grid. A larger part SHALL be drawn as a progress bar showing completed and total sets. The timer MUST NOT draw more than 72 set dots.

#### Scenario: Small part uses dots

- **GIVEN** a part with 3 rounds and 3 sets per round
- **WHEN** the timer draws the map
- **THEN** it draws 9 set dots

#### Scenario: Large part uses a bar

- **GIVEN** a part with 20 rounds and 30 sets per round
- **WHEN** the timer draws the map
- **THEN** it draws a progress bar instead of dots and shows completed and total sets

### Requirement: Editing is locked during rest

While a session is resting or paused, editing the active session SHALL be blocked, the timer's EDIT action SHALL be hidden, and SESSIONS SHALL present plans read-only. Switching tabs MUST NOT alter the running rest. Editing SHALL become available when the session is ready or done.

#### Scenario: Read-only sessions during rest

- **GIVEN** a running set rest
- **WHEN** the user opens SESSIONS
- **THEN** session and part edit, add, delete, reorder, and activate controls are disabled

#### Scenario: Unlocked after the rest

- **GIVEN** SESSIONS is open and read-only during a rest
- **WHEN** the rest ends
- **THEN** editing controls become available without leaving the tab

### Requirement: Active plan changes reset the session

Committing a change to the active session's plan SHALL reset the session to ready with zero completed sets and no rest. Editing a non-active session SHALL NOT change the current session or timer.

#### Scenario: Editing the active plan

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a Chest part's set rest is committed
- **THEN** the timer is ready at Chest's first set with zero completed sets

#### Scenario: Editing another session

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a part in Arms is edited
- **THEN** the Chest session keeps its completed sets and rest

### Requirement: Rest context copy

During a rest, the timer SHALL state what finished: `AFTER SET n` for a set rest, `AFTER ROUND n` for a round rest inside a part, and the finished part followed by the next part for a transition rest. The kicker SHALL be `SET REST`, `ROUND REST`, or `PAUSED`.

#### Scenario: Set rest copy

- **GIVEN** a rest after set 2
- **WHEN** the timer rests
- **THEN** the kicker is SET REST and the subtitle is AFTER SET 2

#### Scenario: Transition copy

- **GIVEN** a rest after Biceps round 3 with Triceps next
- **WHEN** the timer rests
- **THEN** the subtitle names Biceps as finished and Triceps as next

### Requirement: Session completion summary

The done state SHALL summarize the completed session by parts, total sets, and total rest, and SHALL offer START AGAIN to restart the same plan from the first set of the first part.

#### Scenario: Starting again

- **GIVEN** a done session
- **WHEN** the user taps START AGAIN
- **THEN** the session is ready at part 1, round 1, set 1 with zero completed sets
