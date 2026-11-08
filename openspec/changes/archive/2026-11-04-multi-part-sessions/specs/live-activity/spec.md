# Spec Delta

## Purpose

Mirrors a multi-part session on the Lock Screen and Dynamic Island, showing the active part, the next rest, and controls that stay in step with the in-app session.

## ADDED Requirements

### Requirement: Attributes carry the part plan

Activity attributes SHALL carry the session name and the ordered parts, including each part's name, rounds, sets per round, set rest, and round rest. Content state SHALL carry only changing values: phase, completed sets, rest kind, duration, deadline, and paused remaining.

#### Scenario: Starting a multi-part session

- **GIVEN** a session with Biceps and Triceps
- **WHEN** the Live Activity starts
- **THEN** its attributes contain both parts in order with their own values

#### Scenario: Plan changes replace the activity

- **GIVEN** a running activity for the Chest session
- **WHEN** the active session changes to Arms
- **THEN** the Chest activity is ended and a new Arms activity contains the Arms parts

### Requirement: One activity at a time

At most one session activity SHALL exist. Launch and plan changes SHALL end stale activities before requesting a new one.

#### Scenario: Cleaning stale activities

- **GIVEN** more than one session activity exists
- **WHEN** the app starts or restarts the activity
- **THEN** all are ended and exactly one new activity is requested

### Requirement: Part-aware island content

Expanded content SHALL identify the active part and the current round and set. Compact content SHALL identify the active part with a short label that fits the compact region. The done state SHALL summarize the whole session instead of a part.

#### Scenario: Ready in a later part

- **GIVEN** part 2 named Triceps, round 1 set 1
- **WHEN** the expanded and compact islands are shown
- **THEN** the expanded island shows Triceps, round 1, and set 1, and the compact island shows a short Triceps label

#### Scenario: Session done

- **GIVEN** a completed 3-part session
- **WHEN** the island is shown
- **THEN** it shows DONE with the completed sets total, not a part position

### Requirement: Rest display names the transition

During a rest the island SHALL show the rest kind, remaining time, and progress. A set rest and an in-part round rest SHALL state what finished. A rest between parts SHALL name the finished part and the next part.

#### Scenario: Set rest on the island

- **WHEN** a set rest is running after set 2
- **THEN** the island shows SET REST, the countdown, and AFTER SET 2

#### Scenario: Part transition on the island

- **GIVEN** a rest after the last Biceps set with Triceps next
- **WHEN** the island shows the rest
- **THEN** it names Biceps as finished and Triceps as next

### Requirement: Island controls use links

Island controls SHALL remain Links to `restless://set-done`, `restless://pause`, `restless://resume`, `restless://skip`, and `restless://restart`. Tapping SHALL open the app, which SHALL apply the action through the same session transition entry point as the in-app controls. Set done during rest SHALL be ignored.

#### Scenario: Marking the last set of a part done

- **GIVEN** the island is ready at the last set of Biceps
- **WHEN** the user taps the set-done link
- **THEN** the app completes that set and starts the Biceps round rest before Triceps

#### Scenario: Double tapping set done

- **WHEN** the set-done link is applied twice while a rest is running
- **THEN** only the first application completes a set

### Requirement: Updates only on transitions

The activity SHALL update on set done, pause, resume, skip, rest finish, restart, completion, and once when the plan changes. It MUST NOT request an update for every second. The countdown SHALL be rendered from the deadline.

#### Scenario: No per-second pushes

- **GIVEN** a two minute rest
- **WHEN** the rest runs
- **THEN** the activity updates on the transition into the rest and the transition out of it, not once per second

### Requirement: Accent follows the rest kind

The island accent SHALL be the set-rest green while waiting for a set rest, the round-rest amber while waiting for or taking a round rest or part transition, and the set-rest green when done.

#### Scenario: Part transition colour

- **GIVEN** the rest after the last Biceps set
- **WHEN** the island is shown
- **THEN** its accent is the round-rest amber
