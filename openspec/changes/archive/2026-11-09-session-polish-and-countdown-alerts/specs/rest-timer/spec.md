# Spec Delta

## REMOVED Requirements

### Requirement: Restart control on the running timer

**Reason**: The two-tap arm is replaced by a confirmation dialog that names the consequence before any progress is cleared.

**Migration**: Use the new Restart control visibility and Restart asks for confirmation requirements; the transition and lock behavior carry over.

## ADDED Requirements

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
