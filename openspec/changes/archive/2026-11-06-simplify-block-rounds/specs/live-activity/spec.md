# Spec Delta

## ADDED Requirements

### Requirement: Attributes carry the block plan
Activity attributes SHALL carry the session name and the ordered blocks, including each block's name, rounds, sets per round, set rest, round rest, and movements. They SHALL NOT carry a straight/circuit arrangement. Content state SHALL carry only changing values: phase, completed sets, rest kind, duration, deadline, paused remaining, and the timed set's deadline.

#### Scenario: Starting a multi-block session
- **GIVEN** a session with a Biceps block and a Triceps block
- **WHEN** the Live Activity starts
- **THEN** its attributes contain both blocks in order with their own rounds, sets per round, and rests

#### Scenario: Plan changes replace the activity
- **GIVEN** a running activity for the Chest session
- **WHEN** the active session changes to Arms
- **THEN** the Chest activity is ended and a new Arms activity contains the Arms blocks

#### Scenario: No arrangement field
- **GIVEN** a block with two movements
- **WHEN** the activity attributes are built
- **THEN** they contain no SUPERSET or CIRCUIT field

### Requirement: Block-aware island content
Expanded content SHALL identify the active block and the current round and set. It SHALL hide the round when rounds is 1 and the set when sets per round is 1. Compact content SHALL identify the active block with a short label. The done state SHALL summarize the whole session instead of a block.

#### Scenario: Ready in a later block
- **GIVEN** block 2 named Triceps, round 1 set 1
- **WHEN** the expanded and compact islands are shown
- **THEN** the expanded island shows Triceps, round 1, and set 1, and the compact island shows a short Triceps label

#### Scenario: Four rounds of four sets
- **GIVEN** block 1 named Biceps, round 2 of 4, set 3 of 4
- **WHEN** the expanded island is shown
- **THEN** it shows round 2 of 4 and set 3 of 4

#### Scenario: One set per round
- **GIVEN** a block with 2 rounds and 1 set per round
- **WHEN** the expanded island is shown
- **THEN** it shows round 2 of 2 and no set segment

#### Scenario: Session done
- **GIVEN** a completed 3-block session
- **WHEN** the island is shown
- **THEN** it shows DONE with the completed sets total, not a block position

### Requirement: Rest copy names the transition
During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and an in-block round rest SHALL state what finished. A movement switch inside a round SHALL name the finished and next movements. A rest between blocks SHALL name the finished and next blocks.

#### Scenario: Set rest on the island
- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Movement switch on the island
- **GIVEN** a set rest after Biceps inside a superset round, with Triceps next
- **WHEN** the island shows the rest
- **THEN** it shows SET REST and AFTER BICEPS · NEXT TRICEPS

#### Scenario: Block transition on the island
- **GIVEN** a rest after the last Biceps block set with the Triceps block next
- **WHEN** the island shows the rest
- **THEN** it names Biceps as finished and Triceps as next

### Requirement: Island controls use action links
Island controls SHALL remain Links to `restless://set-done`, `restless://pause`, `restless://resume`, `restless://skip`, and `restless://restart`. Tapping SHALL open the app, which SHALL apply the action through the same session transition entry point as the in-app controls. Set done during rest SHALL be ignored.

#### Scenario: Marking the last set of a block done
- **GIVEN** the island is ready at the last set of the Biceps block
- **WHEN** the user taps the set-done link
- **THEN** the app completes that set and starts the round rest before the Triceps block

#### Scenario: Double tapping set done
- **WHEN** the set-done link is applied twice while a rest is running
- **THEN** only the first application completes a set

### Requirement: Accent follows the rest and transition
The island accent SHALL be the set-rest green while waiting for a set rest, the round-rest amber while waiting for or taking a round rest or block transition, and the set-rest green when done.

#### Scenario: Block transition colour
- **GIVEN** the rest after the last set of the Biceps block
- **WHEN** the island is shown
- **THEN** its accent is the round-rest amber

## REMOVED Requirements

### Requirement: Attributes carry the part plan
**Reason**: Attributes now carry blocks with rounds and sets per round instead of parts with one set count.
**Migration**: See Attributes carry the block plan.

### Requirement: Part-aware island content
**Reason**: The island now shows block, round, and set, with no arrangement label.
**Migration**: See Block-aware island content.

### Requirement: Rest display names the transition
**Reason**: The requirement is renamed and its copy uses blocks and movement switches.
**Migration**: See Rest copy names the transition.

### Requirement: Island controls use links
**Reason**: The requirement is renamed to describe the action links and the block copy.
**Migration**: See Island controls use action links.

### Requirement: Accent follows the rest kind
**Reason**: The requirement is renamed and covers block transitions.
**Migration**: See Accent follows the rest and transition.
