# Spec Delta

## MODIFIED Requirements

### Requirement: The completion alert names what finished

A completion alert SHALL state what finished and what comes next: the rest kind or work set, the finished set, round, or movement, and the next set, movement, block, or session completion. The system surface decides whether that copy is split across a title and body.

#### Scenario: A set rest ends
- **GIVEN** a set rest after set 2 inside a round, with set 3 next
- **WHEN** the alert is raised
- **THEN** it reads SET REST OVER, names AFTER SET 2 as what finished, and names the next round and set

#### Scenario: A movement switch ends
- **GIVEN** a round rest after Biceps' last round, with Triceps next
- **WHEN** the alert is raised
- **THEN** it reads ROUND REST OVER, names Biceps as finished, and names Triceps as next

#### Scenario: A timed work set ends
- **GIVEN** a timed work set that is the last set of the block and another block follows
- **WHEN** the alert is raised
- **THEN** it names the work set as finished and the next block as what follows

#### Scenario: The final set ends
- **GIVEN** the last set of the last block
- **WHEN** the completion alert is raised
- **THEN** it names the session as complete and does not promise a next set
