# Spec Delta

## REMOVED Requirements

### Requirement: Attributes carry the part plan

**Reason**: Activity attributes now carry blocks and their movements, not parts.

**Migration**: The block plan requirement below preserves the plan-in-attributes rule and adds arrangement, end conditions, and targets.

### Requirement: Part-aware island content

**Reason**: The island now presents a block, a movement, and either a set or a round.

**Migration**: The block-aware content requirement below replaces the part content.

### Requirement: Rest display names the transition

**Reason**: The island now names a movement transition or a block transition instead of a part transition.

**Migration**: The new rest display requirement below keeps the same rule with block and movement names.

### Requirement: Island controls use links

**Reason**: The island gains a start-set link for timed sets, and the control set now covers sets and rests.

**Migration**: The new link requirement below keeps every existing link and adds start-set.

### Requirement: Accent follows the rest kind

**Reason**: The island also shows a work countdown, which is not a rest.

**Migration**: The new accent requirement below keeps the rest colours and adds the work colour.

## ADDED Requirements

### Requirement: Attributes carry the block plan

Activity attributes SHALL carry the session name and the ordered blocks, including each block's name, arrangement, set rest, round rest, and movements with name, end condition, and target. Content state SHALL carry only changing values: phase, completed sets, rest kind, duration, deadline, paused remaining, and timed-set deadline.

#### Scenario: Starting a multi-block session

- **GIVEN** a session with a Chest block and an Arms block
- **WHEN** the Live Activity starts
- **THEN** its attributes contain both blocks in order with their movements

#### Scenario: Plan changes replace the activity

- **GIVEN** a running activity for the Chest session
- **WHEN** the active session changes to Arms
- **THEN** the Chest activity is ended and a new Arms activity contains the Arms blocks

### Requirement: Block-aware island content

Expanded content SHALL identify the active block, the active movement, and the current set or round. Compact content SHALL identify the active movement with a short label that fits the compact region. The done state SHALL summarize the whole session.

#### Scenario: Ready in a later block

- **GIVEN** block 2 named Arms, incline press set 2 of 3
- **WHEN** the expanded and compact islands are shown
- **THEN** the expanded island shows Arms, incline press, and set 2, and the compact island shows a short movement label

#### Scenario: Performing a timed set

- **GIVEN** a 60 second plank with 43 seconds remaining
- **WHEN** the island is shown
- **THEN** it shows the work countdown and the movement

#### Scenario: Session done

- **GIVEN** a completed 2-block session
- **WHEN** the island is shown
- **THEN** it shows DONE with the completed sets total, not a block position

### Requirement: Rest display names the movement or block

During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and a round rest SHALL state what finished. A movement transition SHALL name the finished movement and the next movement. A block transition SHALL name the finished block and the next block.

#### Scenario: Set rest on the island

- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Circuit round rest on the island

- **WHEN** a round rest is running after round 1 of a circuit
- **THEN** the island shows ROUND REST, the countdown, and AFTER ROUND 1

#### Scenario: Movement transition on the island

- **GIVEN** a straight block with bench press then incline press
- **WHEN** the last bench set is done and its round rest runs
- **THEN** the island names bench press as finished and incline press as next

#### Scenario: Block transition on the island

- **GIVEN** a rest after Chest with Arms next
- **WHEN** the island shows the rest
- **THEN** it names Chest as finished and Arms as next

### Requirement: Island controls use links for sets and rests

Island controls SHALL remain Links to `restless://set-done`, `restless://pause`, `restless://resume`, `restless://skip`, `restless://restart`, and `restless://start-set`. Tapping SHALL open the app, which SHALL apply the action through the same session transition entry point as the in-app controls. Set done during rest SHALL be ignored. Start set SHALL apply only to a ready timed set.

#### Scenario: Marking the last set of a block done

- **GIVEN** the island is ready at the last set of Chest
- **WHEN** the user taps the set-done link
- **THEN** the app completes that set and starts the Chest round rest before Arms

#### Scenario: Starting a timed set from the island

- **GIVEN** the island is ready at a 60 second plank
- **WHEN** the user taps the start-set link
- **THEN** the app starts the timed set and the island shows the work countdown

#### Scenario: Double tapping set done

- **WHEN** the set-done link is applied twice while a rest is running
- **THEN** only the first application completes a set

### Requirement: Accent follows the rest or work kind

The island accent SHALL be the set-rest green while waiting for a set rest, the round-rest amber while waiting for or taking a round rest, a movement transition, or a block transition, and the set-rest green when done. A work countdown SHALL use the set-rest green; it is not a rest.

#### Scenario: Block transition colour

- **GIVEN** the rest after the last Chest set
- **WHEN** the island is shown
- **THEN** its accent is the round-rest amber

#### Scenario: Work countdown colour

- **GIVEN** a performing timed set
- **WHEN** the island is shown
- **THEN** its accent is the set-rest green

## MODIFIED Requirements

### Requirement: Updates only on transitions

The activity SHALL update on set done, start set, pause, resume, skip, rest finish, timed set finish, restart, completion, and once when the plan changes. It MUST NOT request an update for every second. Countdowns SHALL be rendered from their deadlines.

#### Scenario: No per-second pushes

- **GIVEN** a two minute rest
- **WHEN** the rest runs
- **THEN** the activity updates on the transition into the rest and the transition out of it, not once per second

#### Scenario: Timed set updates

- **GIVEN** a 60 second timed set
- **WHEN** it runs
- **THEN** the activity updates when the set starts and when it finishes, not once per second
