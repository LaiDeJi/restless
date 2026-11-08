# Spec Delta

## Purpose

Saved workout sessions made of ordered body-part blocks, each with its own rounds, sets, and rest values, managed through the app's timer and sessions pages.

## ADDED Requirements

### Requirement: Session plans are ordered parts

A session SHALL have a stable identifier, a name, and one or more ordered parts. Each part SHALL have a stable identifier, a name, rounds, sets per round, set rest, and round rest. Parts SHALL run in the order shown in the session.

#### Scenario: A session stores parts in order

- **GIVEN** a session containing Biceps followed by Triceps
- **WHEN** the session is opened
- **THEN** Biceps is the first part and Triceps is the second part

#### Scenario: A session never has zero parts

- **WHEN** the only part in a session is deleted
- **THEN** the deletion is refused and the part remains

### Requirement: Rounds and sets have no upper limit

Rounds and sets per round SHALL accept any integer of 1 or more. The editor MUST NOT disable increase at 6 or at any other product cap. Rest values SHALL remain between 15 and 600 seconds in steps of 15.

#### Scenario: Increasing past six

- **GIVEN** a part with 6 rounds
- **WHEN** the user taps increase on ROUNDS
- **THEN** the value becomes 7 and the increase control stays enabled

#### Scenario: Typing a large sets value

- **WHEN** the user types 120 into SETS PER ROUND and confirms
- **THEN** the part stores 120 sets per round

#### Scenario: Rest limits are unchanged

- **GIVEN** a part with set rest 600 seconds
- **WHEN** the user tries to increase set rest
- **THEN** the value stays at 600 and the increase control is disabled

#### Scenario: Large plan totals are exact

- **GIVEN** a part with 40 rounds and 25 sets per round
- **WHEN** the part summary is shown
- **THEN** it reports 1000 total sets with no overflow or wrapped number

### Requirement: Exact numeric entry for rounds and sets

Tapping a rounds or sets value SHALL open numeric entry for that value. Committing an integer of 1 or more SHALL set the value exactly. Committing a number below 1 SHALL clamp it to 1. Empty or non-numeric input SHALL leave the previous value unchanged.

#### Scenario: Entering an exact value

- **GIVEN** a part with 3 sets per round
- **WHEN** the user taps the value, types 12, and confirms
- **THEN** the part has 12 sets per round

#### Scenario: Entering zero

- **WHEN** the user types 0 and confirms
- **THEN** the value becomes 1

#### Scenario: Leaving the field empty

- **GIVEN** a part with 4 rounds
- **WHEN** the user clears the field and confirms without typing
- **THEN** rounds remains 4

### Requirement: Bottom tab navigation

The app SHALL have two persistent bottom tabs, TIMER and SESSIONS. TIMER SHALL be the default tab. Switching tabs MUST NOT pause, reset, or lose a running rest. The timer's EDIT action SHALL open the active session in SESSIONS.

#### Scenario: Launch opens the timer

- **WHEN** the app launches
- **THEN** the TIMER tab is selected

#### Scenario: Switching tabs during rest

- **GIVEN** a set rest with 40 seconds remaining
- **WHEN** the user switches to SESSIONS for 10 seconds and returns to TIMER
- **THEN** approximately 30 seconds remain and the rest is still running

#### Scenario: EDIT opens the active session

- **GIVEN** the active session is Chest
- **WHEN** the user taps EDIT on the timer
- **THEN** SESSIONS opens on the Chest session editor

### Requirement: Sessions page

SESSIONS SHALL list every saved session, mark the active one, and open a session editor when a session is selected. The page SHALL offer creating a new session.

#### Scenario: Listing sessions

- **GIVEN** sessions named Chest and Arms with Arms active
- **WHEN** SESSIONS opens
- **THEN** both are listed and Arms is marked active

#### Scenario: Creating a session

- **WHEN** the user adds a session
- **THEN** a new session is saved and opened in its editor without changing the active session

### Requirement: Session management

From the session editor a user SHALL be able to rename, activate, and delete a session. The last remaining session MUST NOT be deleted. Deleting a session SHALL require two taps on the delete action.

#### Scenario: Activating a session

- **GIVEN** Chest is active with sets completed
- **WHEN** the user activates Arms
- **THEN** Arms becomes active and the timer is ready at its first set with no completed sets

#### Scenario: Deleting a session in two steps

- **GIVEN** two saved sessions
- **WHEN** the user taps delete once and then confirms
- **THEN** the session is removed and another session becomes active

#### Scenario: Refusing to delete the last session

- **GIVEN** one saved session
- **WHEN** the session editor is shown
- **THEN** no enabled delete action is offered

### Requirement: Part management

From the session editor a user SHALL be able to add, rename, reorder, and delete parts. Adding a part SHALL append it and inherit the previous part's rest values. A session MUST keep at least one part. Deleting a part SHALL require two taps.

#### Scenario: Adding a part

- **GIVEN** a session whose last part has set rest 60 and round rest 120
- **WHEN** the user adds a part
- **THEN** the new part is last and starts with set rest 60 and round rest 120

#### Scenario: Reordering parts

- **GIVEN** parts Biceps, Triceps, Back
- **WHEN** the user moves Back before Biceps
- **THEN** the session order is Back, Biceps, Triceps

#### Scenario: Deleting the last part

- **GIVEN** a session with one part
- **WHEN** the user looks for a part delete action
- **THEN** no enabled delete action is offered

### Requirement: Existing presets migrate to one-part sessions

Each saved preset SHALL become a session with one part that preserves its name, rounds, sets per round, set rest, and round rest. The active preset SHALL remain the active session. A missing or unreadable stored plan SHALL fall back to the seeded Chest session.

#### Scenario: Upgrading a saved preset

- **GIVEN** a stored preset named Chest with 3 rounds, 3 sets, 60 set rest, and 120 round rest
- **WHEN** the app first launches after the update
- **THEN** it contains one session named Chest with one part named Chest and those values

#### Scenario: Missing or unreadable plan

- **WHEN** the app launches with no readable saved plan
- **THEN** it seeds a Chest session with one 3 × 3 part using 60 and 120 second rests

### Requirement: Responsive editing

A stepper tap or numeric commit SHALL update the displayed value on the same interaction. Persistence, session reset, and Live Activity refresh SHALL be coalesced after a short idle period and applied at most once per burst. Leaving the editor SHALL flush any pending edit. No Live Activity request SHALL start for each tap.

#### Scenario: Rapid stepper taps

- **GIVEN** set rest is 60 seconds
- **WHEN** the user taps increase five times quickly
- **THEN** the display advances on every tap and ends at 75 seconds without a visible freeze

#### Scenario: One commit per burst

- **WHEN** the user edits a value several times in quick succession
- **THEN** the plan is saved once after the taps stop, not once per tap

#### Scenario: Leaving with a pending edit

- **GIVEN** an edit burst that has not yet reached its idle commit
- **WHEN** the user leaves the editor
- **THEN** the pending change is saved before the editor closes

### Requirement: Session and part summaries

A session SHALL summarize its number of parts, total sets, and total rest. A part SHALL summarize rounds × sets and its two rest values. A total rest of 60 minutes or more SHALL be shown with hours.

#### Scenario: Summarizing a multi-part session

- **GIVEN** Biceps 3 × 3 with 60/120 and Triceps 2 × 4 with 45/90
- **WHEN** the session summary is shown
- **THEN** it reports 2 parts and 17 total sets, and total rest equals the sum of both parts

#### Scenario: Long total rest

- **GIVEN** a session whose total rest exceeds one hour
- **WHEN** the summary is shown
- **THEN** the duration includes an hours component

### Requirement: Name rules

Session and part names SHALL be trimmed and limited to 18 characters. An empty session name SHALL become Untitled. An empty part name SHALL become Untitled part.

#### Scenario: Empty session name

- **WHEN** the user clears the session name and leaves the field
- **THEN** the name becomes Untitled

#### Scenario: Long part name

- **WHEN** the user types more than 18 characters into a part name
- **THEN** only the first 18 characters are kept
