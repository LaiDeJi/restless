# Spec Delta

## MODIFIED Requirements

### Requirement: Rest copy names what finished

During a rest, the timer SHALL state what finished for a set rest (`AFTER SET n`) and for a round rest between rounds of one movement (`AFTER ROUND n`). For a movement switch it SHALL name only the next movement, prefixed `NEXT · ` (`NEXT · <next movement>`), and for a block transition it SHALL name only the next block, prefixed `NEXT · ` (`NEXT · <next block>`). It SHALL NOT name the finished movement or the finished block in either transition. The kicker SHALL be `SET REST` for a set rest, `ROUND REST` for every other rest, or `PAUSED`.

#### Scenario: Set rest copy

- **GIVEN** a rest after set 2
- **WHEN** the timer rests
- **THEN** the kicker is SET REST and the subtitle is AFTER SET 2

#### Scenario: Movement switch copy

- **GIVEN** a round rest after Biceps' last round, with Triceps next
- **WHEN** the timer rests
- **THEN** the kicker is ROUND REST and the subtitle is NEXT · TRICEPS, with no AFTER BICEPS text

#### Scenario: Round rest copy

- **GIVEN** a round rest after round 2 of one movement
- **WHEN** the timer rests
- **THEN** the subtitle is AFTER ROUND 2

#### Scenario: Block transition copy

- **GIVEN** a rest after the Biceps block with Triceps next
- **WHEN** the timer rests
- **THEN** the subtitle names Triceps as next after a NEXT · prefix and does not name Biceps
