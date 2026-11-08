# Spec Delta

## MODIFIED Requirements

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
