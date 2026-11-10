# Spec Delta

## MODIFIED Requirements

### Requirement: Rest copy names the transition

During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and a round rest between rounds of one movement SHALL state what finished. A movement switch after a movement's last round SHALL name the finished and next movements. A rest between blocks SHALL name the finished and next blocks.

#### Scenario: Set rest on the island
- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Movement switch on the island
- **GIVEN** a round rest after Biceps' last round, with Triceps next
- **WHEN** the island shows the rest
- **THEN** it shows ROUND REST and AFTER BICEPS · NEXT TRICEPS

#### Scenario: Block transition on the island
- **GIVEN** a rest after the last Biceps block set with the Triceps block next
- **WHEN** the island shows the rest
- **THEN** it names Biceps as finished and Triceps as next
