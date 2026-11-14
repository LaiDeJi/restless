# Spec Delta

## ADDED Requirements

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
