# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
