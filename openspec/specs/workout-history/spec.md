# workout-history Specification

## Purpose
Durable records of the workouts actually started, keeping what was planned, how
far it got, and when it stopped, independent of later session edits and deletes.

## Requirements

### Requirement: A record starts with the first set

A record SHALL be created when the first set of a run is completed. Starting a session, resting, or pausing without a completed set MUST NOT create one. Every later set in the run SHALL update that same record.

#### Scenario: The gate creates nothing

- **GIVEN** a session at the start gate
- **WHEN** the user taps START SESSION and does not complete a set
- **THEN** no history record exists

#### Scenario: The first set creates one record

- **GIVEN** a ready session
- **WHEN** the user completes the first set
- **THEN** exactly one record exists with one set done

#### Scenario: Later sets reuse it

- **GIVEN** a run with one record and two sets done
- **WHEN** the user completes a third set
- **THEN** the same record shows three sets done

### Requirement: The record keeps its own snapshot

Each record SHALL store its own copy of the run's session name, blocks, movements, rounds, sets per round, rests, set end conditions and targets, plus the sets done, the position reached, and the phase at the last change.

#### Scenario: Editing the session later

- **GIVEN** a Chest record made with two blocks
- **WHEN** the user renames Chest, deletes a block, and changes its rests
- **THEN** the record still shows the old name, both blocks, and the old rests

#### Scenario: The active session is not the record

- **GIVEN** a Legs record
- **WHEN** the user activates a different session
- **THEN** the Legs record is unchanged and still shown on its date

### Requirement: Every state change updates the record

The record SHALL update at every state change of the run, including a rest or timed set that completes by deadline and a change applied through the Live Activity.

#### Scenario: Stopping during a rest

- **GIVEN** a record with six sets done and a running rest
- **WHEN** the user pauses and leaves the app
- **THEN** the record shows six sets, the rest position, and paused as its last phase

#### Scenario: A deadline transition

- **GIVEN** a timed set whose deadline passes with the app in the background
- **WHEN** the app returns
- **THEN** the record shows the completed set and the phase reached at the deadline

#### Scenario: An island control

- **GIVEN** a running session and a completed set
- **WHEN** the user taps SET DONE in the Live Activity
- **THEN** the record gains that set without a duplicate record

### Requirement: Done finalizes the record

Reaching the done phase SHALL finalize the record with the finish time, the full set count, and done as its last phase.

#### Scenario: The last set

- **GIVEN** a record with one set left
- **WHEN** the user completes it
- **THEN** the record shows every set, a finish time, and done

#### Scenario: Finalized once

- **GIVEN** a session already done
- **WHEN** the user taps START AGAIN
- **THEN** the finished record is unchanged and the next completed set starts a new record

### Requirement: A record belongs to its start date

A record SHALL belong to the device's local calendar date of the run's start. A run that crosses midnight SHALL stay on the date it started.

#### Scenario: Across midnight

- **GIVEN** a run that starts at 23:50 and finishes at 00:20
- **WHEN** the calendar shows the following day
- **THEN** the record appears on the start date and not on the finish date

### Requirement: Records are read-only

A record's content MUST NOT be edited. Deleting a record SHALL require two taps and MUST NOT change the session, the rotation, or any other record.

#### Scenario: Deleting a record

- **GIVEN** a Chest record on a Tuesday
- **WHEN** the user taps delete once and then confirms
- **THEN** the Tuesday cell no longer shows the record and the session and upcoming plans are unchanged

#### Scenario: No edit affordance

- **GIVEN** a recorded day's sheet
- **WHEN** it is shown
- **THEN** no field or action can change its content

### Requirement: Deleting a session keeps its records

Deleting a session MUST NOT delete or alter any record made from it.

#### Scenario: Session removed, record kept

- **GIVEN** an Arms session with two records
- **WHEN** the user deletes Arms
- **THEN** both records remain on their dates with the Arms name and plan snapshot
