# Spec Delta

## ADDED Requirements

### Requirement: A new session starts with an empty default block

A new session draft SHALL contain exactly one block named `Untitled block`.
That block SHALL carry zero movements and SHALL inherit the active session's
first block's rounds, sets per round, set rest and round rest. When no session
is active, the standard block defaults apply. Opening the draft MUST NOT copy a
movement from the active session or from the library.

#### Scenario: The draft copies the schedule but no movement

- **GIVEN** Chest is active with a first block of 1 round, 9 sets per round, set
  rest 60, round rest 120, and a Chest movement
- **WHEN** the user opens a new session draft
- **THEN** the draft has one `Untitled block` with 1 round, 9 sets per round,
  set rest 60, round rest 120 and zero movements

#### Scenario: The draft starts empty with no active session

- **GIVEN** no active session
- **WHEN** the user opens a new session draft
- **THEN** the block has the standard defaults of 1 round, 3 sets per round,
  set rest 60, round rest 120 and zero movements

#### Scenario: The empty block reports zero sets

- **GIVEN** a new session draft
- **WHEN** the session editor shows its block row and totals
- **THEN** the block reports 0 movements and the session reports 0 sets

### Requirement: An empty block cannot be committed

DONE and USE THIS SESSION SHALL be disabled while any block in the draft has no
movement, and the draft MUST NOT be saved through either action. The commit
path SHALL refuse such a draft so a saved session never contains an empty block.
Adding a movement SHALL enable both actions.

#### Scenario: The empty draft cannot be saved

- **GIVEN** a new session draft whose only block has no movement
- **WHEN** the user taps DONE or USE THIS SESSION
- **THEN** no session is saved, the draft remains open, and the list and active
  session are unchanged

#### Scenario: Adding a movement enables the commit

- **GIVEN** a new session draft whose only block has no movement
- **WHEN** the user adds a movement from the block editor and returns
- **THEN** DONE and USE THIS SESSION are enabled

#### Scenario: DONE saves after the block is filled

- **GIVEN** a new session draft named Legs whose block has one movement
- **WHEN** the user taps DONE
- **THEN** SESSIONS lists exactly one new session named Legs with that block
