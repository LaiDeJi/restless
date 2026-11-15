# Spec Delta

## ADDED Requirements

### Requirement: First run seeds one neutral session

An empty store SHALL be seeded with exactly one session named `Session 1`, holding one block named `Block 1` with one movement named `Movement 1`. Seeding MUST NOT create any other session, movement, history record or demo data. A store that already holds a session SHALL NOT be seeded.

#### Scenario: First launch on an empty store

- **GIVEN** a store with no sessions and no movements
- **WHEN** the app opens
- **THEN** SESSIONS lists one session named Session 1 and the app opens on it
- **AND** the movement library holds one movement named Movement 1
- **AND** the timer shows Block 1 ready to start

#### Scenario: A store that already has sessions

- **GIVEN** a store that holds at least one session
- **WHEN** the app opens
- **THEN** no session and no movement is created

## REMOVED Requirements

### Requirement: Stored plans migrate to rounds and sets per round

**Reason**: The store reset retires every older plan shape, so no stored plan in that shape can reach the app.

**Migration**: Retype the sessions from the project note after the update. A store in an older shape is discarded rather than read; nothing is migrated in place.

### Requirement: Stored REPS sets become MANUAL

**Reason**: Movement monitoring is removed, and no store that survives the update can hold a `reps` end condition.

**Migration**: Nothing to migrate. A new store is written only with `manual` and `time`.

### Requirement: Duplicate movement rows collapse

**Reason**: Duplicate rows only appeared when decoding a stored circuit, and circuits no longer exist in any readable plan.

**Migration**: Nothing to migrate. A block is created with the movements it is given, and adjacent duplicates are kept as separate movements.
