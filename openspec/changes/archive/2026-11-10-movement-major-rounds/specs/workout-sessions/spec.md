# Spec Delta

## MODIFIED Requirements

### Requirement: Block structure has no arrangement mode

A block SHALL define its schedule only by rounds, sets per round, and its ordered movements. It SHALL NOT store or expose a straight/circuit arrangement. One movement SHALL repeat that movement across its rounds. Two or more movements SHALL run in the order listed, and each movement SHALL complete all of its rounds, with its sets per round in each round, before the next movement starts. A sequential pair SHALL be two blocks.

#### Scenario: One movement, four rounds of four sets
- **GIVEN** a block with one movement, rounds 4, sets per round 4
- **WHEN** the block is shown
- **THEN** it reports 16 sets and contains no arrangement label

#### Scenario: Two movements, two rounds of one set each
- **GIVEN** a block with Biceps and Triceps, rounds 2, sets per round 1
- **WHEN** the block runs
- **THEN** Biceps runs round 1 and round 2, then Triceps runs round 1 and round 2, and the block reports 4 sets

#### Scenario: Sequential pair
- **GIVEN** a user wants Biceps three sets followed by Triceps three sets
- **WHEN** they build the plan
- **THEN** it is two blocks, each with rounds 1 and sets per round 3

#### Scenario: Two movements, three rounds of two sets each
- **GIVEN** a block with Biceps and Triceps, rounds 3, sets per round 2
- **WHEN** the block runs
- **THEN** Biceps runs its three rounds of two sets, then Triceps runs its three rounds of two sets, and the block reports 12 sets

## REMOVED Requirements

### Requirement: One-tap add from the movement library

**Reason**: The scenario "A second movement raises rounds" encodes the two-round floor this change removes. A MODIFIED block cannot drop a scenario, so the behaviour is restated under a new name.

**Migration**: The requirement "Library movements append to a block" below replaces it when the change is archived.

## ADDED Requirements

### Requirement: Library movements append to a block

The block editor SHALL show an `ADD FROM LIBRARY` list of library movements that are not already in the block. Tapping one SHALL append that movement with MANUAL and no target in one edit, keep the add-movement sheet closed, and leave ROUNDS and SETS PER ROUND unchanged. The list SHALL be hidden while editing is locked and absent when no unused movement remains. The add-movement sheet SHALL remain for several movements, custom ends and targets, and typed names.

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

#### Scenario: A second movement keeps the rounds
- **GIVEN** a one-round block with one movement
- **WHEN** the user adds a second movement from the library
- **THEN** the block has two movements and rounds stays 1

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
