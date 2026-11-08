# Spec Delta

## ADDED Requirements

### Requirement: Restart control on the running timer

The timer SHALL offer a two-tap RESTART control while a session is in progress and at least one set is done. The first tap SHALL arm it with `TAP AGAIN` in the round-rest amber; the second SHALL apply the restart transition, returning to ready at block 1, set 1 with zero completed sets without passing through the start gate. The control SHALL be hidden before the first set and in done, where START AGAIN is the primary action, and SHALL clear its armed state when the phase changes.

#### Scenario: Restart after a completed set

- **GIVEN** a session ready at set 3 with two sets completed
- **WHEN** the user taps RESTART once
- **THEN** the control reads TAP AGAIN in amber and the session is unchanged
- **AND** a second tap leaves the session ready at block 1, round 1, set 1 with zero completed sets

#### Scenario: Nothing to restart before the first set

- **GIVEN** a not-started session, or a started session with zero completed sets
- **WHEN** the timer is shown
- **THEN** no RESTART control is offered

#### Scenario: Restart from a rest

- **GIVEN** a session resting after set 7
- **WHEN** the user confirms RESTART
- **THEN** the rest is cleared and the session is ready at block 1, set 1 with zero completed sets

#### Scenario: Done uses START AGAIN

- **GIVEN** a done session
- **WHEN** the timer is shown
- **THEN** no RESTART control is offered and START AGAIN remains the primary action

#### Scenario: The armed state clears on a phase change

- **GIVEN** a RESTART control armed with TAP AGAIN
- **WHEN** the phase changes, such as a rest ending
- **THEN** the control returns to its unarmed RESTART state

#### Scenario: Restart is not editing

- **GIVEN** a session resting, with editing locked
- **WHEN** the timer is shown
- **THEN** the RESTART control is available while EDIT stays hidden, and editing unlocks only when the restart lands in ready

## MODIFIED Requirements

### Requirement: Timer presentation includes the block

The timer SHALL show the active block, the current movement, the current round and set, the upcoming rest or FINISH, and progress through the block. It SHALL name the active block exactly once: the block strip names it when the session has several blocks; otherwise the position strip names it, and only when the block name differs from the movement name. The position strip SHALL NOT carry a `BLOCK n OF m` segment. It SHALL hide the round segment when rounds is 1 and the set segment when sets per round is 1, SHALL NOT show an arrangement label, and SHALL prefix `UP NEXT` during a rest. The position strip SHALL stay on one line at default text sizes; at accessibility sizes it MAY wrap above the countdown ring. During a rest the timer SHALL show the countdown and what the rest follows. Before the start it SHALL present START SESSION, READY, and the first block and movement.

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

#### Scenario: Before the session starts

- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** the kicker is READY, the primary action is START SESSION, and the first block and movement are previewed once

#### Scenario: A rest does not repeat the block

- **GIVEN** block 2 of 2 named Triceps, resting after set 5
- **WHEN** the timer shows the rest
- **THEN** Triceps appears only in the block strip and the position strip reads UP NEXT · movement · round · set

#### Scenario: A single block names itself once

- **GIVEN** the only block is named Chest and its movement is also named Chest
- **WHEN** the timer is shown
- **THEN** CHEST appears once in the position strip

#### Scenario: The strip stays one line

- **GIVEN** a two-block session resting after set 5 at the default text size
- **WHEN** the position strip is shown
- **THEN** it occupies one line above the countdown ring
