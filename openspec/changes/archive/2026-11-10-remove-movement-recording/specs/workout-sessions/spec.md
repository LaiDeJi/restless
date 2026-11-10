# Spec Delta

## ADDED Requirements

### Requirement: The movement library is name-only

The movement library SHALL store only a movement's name. It SHALL NOT store, derive, display, or request a motion profile, recording state, or watch count. A movement SHALL still be created by typing its name in the add-movement picker and SHALL be managed from `MOVEMENTS`.

#### Scenario: A new typed movement is name-only

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** the user types Cable Fly and commits it
- **THEN** the library lists Cable Fly with its name and provides no profile or recording action

#### Scenario: The library has no recording controls

- **GIVEN** a library containing Chest and Curl
- **WHEN** the user opens MOVEMENTS
- **THEN** each row offers only rename and delete, and the page has no record, re-record, profile, or watch control

#### Scenario: An empty library points to the picker

- **GIVEN** a library with no movements
- **WHEN** the user opens MOVEMENTS
- **THEN** the page explains that movements are added from a block's add-movement picker and offers no recording control

### Requirement: Stored REPS sets become MANUAL

A stored block movement whose end condition is the removed `reps` value SHALL decode as `manual` with no target. Decoding SHALL preserve its movement id, order, block, rounds, sets, and rests, so a saved session and a saved running snapshot remain usable.

#### Scenario: A stored REPS row decodes as MANUAL

- **GIVEN** a stored block movement with `endCondition` set to `reps` and target 10
- **WHEN** the block is decoded
- **THEN** its end condition is MANUAL and its target is empty

#### Scenario: A saved session keeps all blocks

- **GIVEN** a stored session whose second block contains a REPS movement
- **WHEN** the session is opened
- **THEN** both blocks, every movement, rounds, sets, and rests remain, and the REPS movement is MANUAL

#### Scenario: A running snapshot survives

- **GIVEN** a saved running snapshot whose plan contains a REPS movement
- **WHEN** the app launches
- **THEN** the snapshot loads at the same position with the REPS movement shown as MANUAL

## MODIFIED Requirements

### Requirement: One-tap add from the movement library

The block editor SHALL show an `ADD FROM LIBRARY` list of library movements that are not already in the block. Tapping one SHALL append that movement with MANUAL and no target in one edit, keep the add-movement sheet closed, and apply the existing two-movement rounds rule. The list SHALL be hidden while editing is locked and absent when no unused movement remains. The add-movement sheet SHALL remain for several movements, custom ends and targets, and typed names.

#### Scenario: One tap adds a movement

- **GIVEN** a block containing Chest, and a library with Chest, Bench Press, and Curl
- **WHEN** the user taps Bench Press under ADD FROM LIBRARY
- **THEN** the block contains Chest then Bench Press with MANUAL and no target
- **AND** no sheet opens and the plan is flushed once

#### Scenario: A staged block gains its first movement

- **GIVEN** a staged block with no movements
- **WHEN** the user taps a library movement
- **THEN** the movement row appears, DONE becomes enabled, and the session still has no new block until DONE

#### Scenario: Used movements leave the list

- **GIVEN** every library movement is already in the block
- **WHEN** the block editor is shown
- **THEN** no ADD FROM LIBRARY list is offered

#### Scenario: A second movement raises rounds

- **GIVEN** a one-round block with one movement
- **WHEN** the user adds a second movement from the library
- **THEN** the block has two movements and rounds becomes 2

#### Scenario: The sheet still batches several movements

- **GIVEN** the add-movement sheet with two movements queued
- **WHEN** the user taps DONE
- **THEN** both movements are appended in order as before

#### Scenario: The added movement stays editable

- **GIVEN** a movement added from the library with MANUAL
- **WHEN** the user opens its row
- **THEN** its end condition and target can be changed to TIME

#### Scenario: Locked block editor

- **GIVEN** a session resting, with editing locked
- **WHEN** the block editor is shown
- **THEN** the ADD FROM LIBRARY list is not offered

### Requirement: DONE commits the add-movement queue

DONE SHALL create or reuse the typed library movements, append every queued movement to the block in the displayed order, flush the plan, and close the picker. CANCEL SHALL close without changing the block or the library.

#### Scenario: Creating a movement and appending it

- **GIVEN** the picker has pending Cable Fly with MANUAL and Bench Press with TIME 0:45, and the library has Bench Press
- **WHEN** the user taps DONE
- **THEN** the library gains Cable Fly, the block appends Cable Fly then Bench Press in that order, the plan is flushed, and the picker closes

#### Scenario: Cancel discards the pending movements

- **GIVEN** a pending Cable Fly that does not exist in the library
- **WHEN** the user taps CANCEL
- **THEN** the library still has no Cable Fly, the block is unchanged, and the picker closes

#### Scenario: A new movement has no profile

- **GIVEN** a block movement created from a typed name
- **WHEN** the block movement editor is shown
- **THEN** the movement is usable with MANUAL or TIME and no profile warning or watch prompt is shown

### Requirement: Set-end choices start with MANUAL

The add-movement picker and the block movement editor SHALL list MANUAL and TIME in that order and SHALL start with MANUAL selected. The block movement editor SHALL select the movement's stored condition. Neither page SHALL offer a REPS condition or a rep target.

#### Scenario: The picker opens on MANUAL

- **GIVEN** the add-movement picker is opened
- **WHEN** the set-end control is shown
- **THEN** MANUAL is selected and the order is MANUAL, TIME

#### Scenario: The movement editor uses the same order

- **GIVEN** a block movement in the movement editor
- **WHEN** the set-end control is shown
- **THEN** the order is MANUAL, TIME with the movement's stored condition selected

#### Scenario: No rep condition is offered

- **GIVEN** either the add-movement picker or the block movement editor
- **WHEN** the set-end control is shown
- **THEN** no REPS choice or rep target is present

## REMOVED Requirements

### Requirement: The no-profile warning follows the set end

**Reason**: Movement profiles and the REPS end condition are removed, so there is no profile that could be missing and no watch count that a profile could enable.

**Migration**: Delete the warning from the add-movement picker and the block movement editor. A typed movement is usable immediately with MANUAL or TIME, and no profile prompt replaces the warning.
