# Live Activity Specification

## Purpose

Mirrors a multi-part session on the Lock Screen and Dynamic Island, showing the active part, the next rest, and controls that stay in step with the in-app session.

## Requirements

### Requirement: Attributes carry the block plan

Activity attributes SHALL carry the session name and the ordered blocks, including each block's name, rounds, sets per round, set rest, round rest, and movements. They SHALL NOT carry a straight/circuit arrangement. Content state SHALL carry only changing values: phase, completed sets, rest kind, duration, deadline, paused remaining, and the timed set's deadline.

#### Scenario: Starting a multi-block session

- **GIVEN** a session with a Biceps block and a Triceps block
- **WHEN** the Live Activity starts
- **THEN** its attributes contain both blocks in order with their own rounds, sets per round, and rests

#### Scenario: Plan changes replace the activity

- **GIVEN** a running activity for the Chest session
- **WHEN** the active session changes to Arms
- **THEN** the Chest activity is ended and a new Arms activity contains the Arms blocks

#### Scenario: No arrangement field

- **GIVEN** a block with two movements
- **WHEN** the activity attributes are built
- **THEN** they contain no SUPERSET or CIRCUIT field

### Requirement: One activity at a time

At most one session activity SHALL exist. No activity SHALL exist while the session is not started; entering the start gate SHALL end any existing activity. Launch and plan changes SHALL end stale activities before requesting a replacement, and SHALL not request one when the session is not started. Starting the session SHALL request one activity.

#### Scenario: Cleaning stale activities

- **GIVEN** more than one session activity exists
- **WHEN** the app starts or restarts the activity
- **THEN** all are ended and exactly one new activity is requested

#### Scenario: Nothing before the start

- **GIVEN** a not-started session with a stale activity
- **WHEN** the app launches or a session is activated
- **THEN** the stale activity is ended and no activity is requested

#### Scenario: Starting requests one

- **GIVEN** a not-started session with no activity
- **WHEN** the user taps START SESSION
- **THEN** exactly one activity for that session is requested

### Requirement: Block-aware island content

Expanded content SHALL identify the active block and the current round and set. It SHALL hide the round when rounds is 1 and the set when sets per round is 1. Compact content SHALL identify the active block with a short label. The done state SHALL summarize the whole session instead of a block.

#### Scenario: Ready in a later block

- **GIVEN** block 2 named Triceps, round 1 set 1
- **WHEN** the expanded and compact islands are shown
- **THEN** the expanded island shows Triceps, round 1, and set 1, and the compact island shows a short Triceps label

#### Scenario: Four rounds of four sets

- **GIVEN** block 1 named Biceps, round 2 of 4, set 3 of 4
- **WHEN** the expanded island is shown
- **THEN** it shows round 2 of 4 and set 3 of 4

#### Scenario: One set per round

- **GIVEN** a block with 2 rounds and 1 set per round
- **WHEN** the expanded island is shown
- **THEN** it shows round 2 of 2 and no set segment

#### Scenario: Session done

- **GIVEN** a completed 3-block session
- **WHEN** the island is shown
- **THEN** it shows DONE with the completed sets total, not a block position

### Requirement: Rest copy names the transition

During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and an in-block round rest SHALL state what finished. A movement switch inside a round SHALL name the finished and next movements. A rest between blocks SHALL name the finished and next blocks.

#### Scenario: Set rest on the island

- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Movement switch on the island

- **GIVEN** a set rest after Biceps inside a superset round, with Triceps next
- **WHEN** the island shows the rest
- **THEN** it shows SET REST and AFTER BICEPS · NEXT TRICEPS

#### Scenario: Block transition on the island

- **GIVEN** a rest after the last Biceps block set with the Triceps block next
- **WHEN** the island shows the rest
- **THEN** it names Biceps as finished and Triceps as next

### Requirement: Island controls use action links

Island controls SHALL remain Links to `restless://set-done`, `restless://pause`, `restless://resume`, `restless://skip`, and `restless://restart`. Tapping SHALL open the app, which SHALL apply the action through the same session transition entry point as the in-app controls. Set done during rest SHALL be ignored.

#### Scenario: Marking the last set of a block done

- **GIVEN** the island is ready at the last set of the Biceps block
- **WHEN** the user taps the set-done link
- **THEN** the app completes that set and starts the round rest before the Triceps block

#### Scenario: Double tapping set done

- **WHEN** the set-done link is applied twice while a rest is running
- **THEN** only the first application completes a set

### Requirement: Updates only on transitions

The activity SHALL update on set done, pause, resume, skip, rest finish, restart, completion, and once when the plan changes. It MUST NOT request an update for every second. The countdown SHALL be rendered from the deadline.

#### Scenario: No per-second pushes

- **GIVEN** a two minute rest
- **WHEN** the rest runs
- **THEN** the activity updates on the transition into the rest and the transition out of it, not once per second

### Requirement: Accent follows the rest and transition

The island accent SHALL be the set-rest green while waiting for a set rest, the round-rest amber while waiting for or taking a round rest or block transition, and the set-rest green when done.

#### Scenario: Block transition colour

- **GIVEN** the rest after the last set of the Biceps block
- **WHEN** the island is shown
- **THEN** its accent is the round-rest amber

### Requirement: Lock Screen panel fits 160 points

The Lock Screen and Notification Center panel SHALL fit within 160 points, including its padding, at every supported text size. Each text row SHALL be limited to one line, and the panel MUST NOT rely on the system truncating overflow. Dynamic Type SHALL be capped at xxLarge, the largest size at which the full panel fits.

#### Scenario: Rest panel fits

- **GIVEN** a rest after set 5 with a movement name at the 40-character limit
- **WHEN** the panel is shown at the default text size
- **THEN** the countdown, progress bar, PAUSE, and SKIP are all visible and the panel is at most 160 points tall

#### Scenario: A long name stays on one row

- **GIVEN** a rest after set 5 with a movement name at the 40-character limit
- **WHEN** the panel is shown at the default text size
- **THEN** the movement row stays on one line, scaling or truncating the name if needed, without pushing the panel past 160 points

#### Scenario: Largest supported text size

- **GIVEN** the system text size is xxLarge
- **WHEN** the panel is shown during a rest
- **THEN** every row and both controls are visible and the panel is at most 160 points tall

#### Scenario: Larger accessibility sizes stay at the cap

- **GIVEN** the system text size is larger than xxLarge
- **WHEN** the panel is shown
- **THEN** it renders at the xxLarge cap and no text or control is clipped

### Requirement: Lock Screen content hierarchy

The panel SHALL show the session name, the active movement, the countdown, and exactly one state row that combines the phase kicker with its context. It MUST NOT add a separate block-position row or a separate rest-context row. It SHALL show progress during a rest or a timed set and SHALL show the same actions as the island. In done it SHALL show SESSION COMPLETE with the completed-set total.

#### Scenario: One state row

- **GIVEN** a session resting after set 5
- **WHEN** the panel is shown
- **THEN** it has exactly one state row and no separate block-position or rest-context row

#### Scenario: Progress during a rest

- **GIVEN** a rest with 30 seconds left of 60
- **WHEN** the panel is shown
- **THEN** the progress bar is visible

#### Scenario: Done

- **GIVEN** a completed session with 17 sets
- **WHEN** the panel is shown
- **THEN** it shows SESSION COMPLETE and 17 OF 17 SETS with the session totals

#### Scenario: Controls match the island

- **GIVEN** a ready, resting, or paused session
- **WHEN** the panel is shown
- **THEN** its controls are the same actions the island offers for that state

### Requirement: Lock Screen state row copy

The state row SHALL pair `SET REST` with `AFTER SET n` during a set rest, the rest kicker with the round or transition context during a round rest, `WORK` with the following rest during a timed set, and `PAUSED` with the frozen context while paused. During ready it SHALL pair the upcoming rest kicker with the current set or `AFTER THIS SET`.

#### Scenario: Set rest

- **GIVEN** a session resting after set 5
- **WHEN** the panel is shown
- **THEN** the state row reads SET REST and AFTER SET 5

#### Scenario: Ready

- **GIVEN** a session ready at set 5 of 8 with a set rest next
- **WHEN** the panel is shown
- **THEN** the state row reads SET REST and SET 5 OF 8

#### Scenario: Timed set

- **GIVEN** a timed set in progress with a one-minute set rest after it
- **WHEN** the panel is shown
- **THEN** the state row reads WORK and REST 1:00 AFTER

#### Scenario: Round rest

- **GIVEN** a session in a round rest after round 3
- **WHEN** the panel is shown
- **THEN** the state row reads ROUND REST and AFTER ROUND 3

#### Scenario: Paused

- **GIVEN** a paused rest after set 5
- **WHEN** the panel is shown
- **THEN** the state row reads PAUSED and AFTER SET 5

### Requirement: A restart ends the session activity

Confirming a restart SHALL end every session Live Activity and SHALL NOT request a replacement, because the session lands in the start gate. START SESSION SHALL request the one new activity.

#### Scenario: Restart from a running session

- **GIVEN** a running session with an active Live Activity
- **WHEN** the user confirms a restart
- **THEN** the timer shows START SESSION and no session activity remains

#### Scenario: Restart from the island

- **GIVEN** a running session with an active Live Activity
- **WHEN** the island's restart link opens the app and the restart is confirmed
- **THEN** the activity ends and the next START SESSION requests a new one
