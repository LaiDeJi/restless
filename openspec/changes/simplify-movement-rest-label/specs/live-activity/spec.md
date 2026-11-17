# Spec Delta

## MODIFIED Requirements

### Requirement: Rest copy names the transition

During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and a round rest between rounds of one movement SHALL state what finished. A movement switch after a movement's last round SHALL name only the next movement. A rest between blocks SHALL name only the next block. It SHALL NOT name the finished movement or the finished block in either transition.

#### Scenario: Set rest on the island

- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Movement switch on the island

- **GIVEN** a round rest after Biceps' last round, with Triceps next
- **WHEN** the island shows the rest
- **THEN** it shows ROUND REST and NEXT TRICEPS, with no AFTER BICEPS text

#### Scenario: Block transition on the island

- **GIVEN** a rest after the last Biceps block set with the Triceps block next
- **WHEN** the island shows the rest
- **THEN** it names Triceps as next and does not name Biceps

### Requirement: Lock Screen state row copy

The state row SHALL pair `SET REST` with `AFTER SET n` during a set rest, the rest kicker with the round or transition context during a round rest, `WORK` with the following rest during a timed set, and `PAUSED` with the frozen context while paused. During a movement switch the transition context SHALL name only the next movement, and during a block transition SHALL name only the next block. During ready it SHALL pair the upcoming rest kicker with the current set or `AFTER THIS SET`.

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

#### Scenario: Movement switch

- **GIVEN** a round rest after a movement's last round, with Triceps next
- **WHEN** the panel is shown
- **THEN** the state row reads ROUND REST and NEXT TRICEPS, with no finished movement named

#### Scenario: Paused

- **GIVEN** a paused rest after set 5
- **WHEN** the panel is shown
- **THEN** the state row reads PAUSED and AFTER SET 5
