# Spec Delta

## ADDED Requirements

### Requirement: Session start gate

A session selected for the first time, and the app with no saved run, SHALL open in a not-started state. The timer's primary action in that state SHALL be START SESSION, and the session MUST NOT count sets, arm the watch, or start a Live Activity before it is started.

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
- **THEN** no set is counted, the watch is not armed, and no Live Activity exists

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

## MODIFIED Requirements

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

### Requirement: Timer presentation includes the part

The timer SHALL show the active part name, `PART n OF m`, the current round and set, the upcoming rest or FINISH, and progress through the active part. During a rest it SHALL show the countdown and what the rest follows. Before the session starts it SHALL present START SESSION, READY, and the first block and movement.

#### Scenario: Ready inside a part

- **GIVEN** part 2 of 3 named Triceps, round 1 of 2, set 1 of 4
- **WHEN** the timer is ready
- **THEN** it shows Triceps, PART 2 OF 3, ROUND 1 OF 2, and SET 1 OF 4

#### Scenario: During a part transition rest

- **GIVEN** the round rest after the last Biceps set, before Triceps
- **WHEN** the timer is resting
- **THEN** it shows the countdown and identifies Biceps as finished and Triceps as next

#### Scenario: Before the session starts

- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** the kicker is READY, the primary action is START SESSION, and the first block and movement are previewed

### Requirement: Active plan changes reset the session

Committing a change to the active session's plan SHALL reset the session to not started with zero completed sets and no rest. Editing a non-active session SHALL NOT change the current session or timer.

#### Scenario: Editing the active plan

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a Chest part's set rest is committed
- **THEN** the timer is not started and START SESSION begins at Chest's first set with zero completed sets

#### Scenario: Editing another session

- **GIVEN** Chest is active with 4 completed sets
- **WHEN** a part in Arms is edited
- **THEN** the Chest session keeps its completed sets and rest
