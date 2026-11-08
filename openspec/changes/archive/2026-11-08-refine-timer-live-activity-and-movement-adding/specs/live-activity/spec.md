# Spec Delta

## ADDED Requirements

### Requirement: Lock Screen panel fits 160 points

The Lock Screen and Notification Center panel SHALL fit within 160 points, including its padding, at every supported text size. Each text row SHALL be limited to one line, and the panel MUST NOT rely on the system truncating overflow. Dynamic Type SHALL be capped at xxLarge, the largest size at which the full panel fits.

#### Scenario: Rest panel fits

- **GIVEN** a rest after set 5 with a movement name at the 18-character limit
- **WHEN** the panel is shown at the default text size
- **THEN** the countdown, progress bar, PAUSE, and SKIP are all visible and the panel is at most 160 points tall

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
