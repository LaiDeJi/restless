# Spec Delta

## MODIFIED Requirements

### Requirement: The wrist shows where the session is

The watch SHALL show the phase label, the current movement, the round and set, one continuous progress bar for the current block, the block's completed-set count, and completed sets out of the session total. The bar SHALL represent the current block, not the whole session. Every block size SHALL use the same bar; the wrist SHALL NOT switch to dots. Neither the bar nor either count is a clock.

#### Scenario: Resting between sets

- **GIVEN** round 2 of 4, set 2 of 4, a 16-set block, and 5 sets completed
- **WHEN** a set rest runs
- **THEN** the wrist reads SET REST, the movement name, ROUND 2 OF 4 · SET 2 OF 4, a bar filled to 5 / 16, 5 / 16 · SETS IN THIS BLOCK, and 5 OF 16 SETS

#### Scenario: A later block in a longer session

- **GIVEN** two blocks with 16 and 8 sets, and 5 sets completed in the first block
- **WHEN** the wrist shows the rest
- **THEN** the bar is filled to 5 / 16, the block count reads 5 / 16, and the session count reads 5 OF 24 SETS

#### Scenario: A finished session

- **GIVEN** the last set completed
- **WHEN** the done phase is shown
- **THEN** the wrist reads SESSION COMPLETE, the bar is full, both counts are at their total, and the session's block and movement counts are shown

#### Scenario: A movement switch

- **GIVEN** a rest that ends one movement and begins another in the same block
- **WHEN** the rest is shown on the wrist
- **THEN** the movement named is the one the rest leads into, and the bar keeps the block's completed-set count instead of resetting at the movement

#### Scenario: A block of any size

- **GIVEN** a block with many rounds or many sets per round
- **WHEN** the wrist shows its progress
- **THEN** it uses the same bar with the block count and session count, and draws no dots or alternate form

#### Scenario: Before the first set

- **GIVEN** a session that has not been started
- **WHEN** the wrist shows the start gate
- **THEN** the bar is empty, the block count reads 0 / the block total, and the session count reads 0 OF the session total
