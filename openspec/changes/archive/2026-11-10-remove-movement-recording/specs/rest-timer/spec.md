# Spec Delta

## MODIFIED Requirements

### Requirement: Session start gate

A session selected for the first time, and the app with no saved run, SHALL open in a not-started state. The timer's primary action in that state SHALL be START SESSION, and the session MUST NOT count sets or start a Live Activity before it is started.

#### Scenario: Launching a fresh session

- **GIVEN** a stored active session and no saved run
- **WHEN** the app launches
- **THEN** the timer is not started with zero completed sets

#### Scenario: Activating another session

- **GIVEN** Chest is active with completed sets
- **WHEN** the user activates Arms
- **THEN** the timer is not started at Arms with zero completed sets

#### Scenario: The gate runs nothing

- **GIVEN** a not-started session
- **WHEN** the timer is shown
- **THEN** no set is counted and no Live Activity exists

### Requirement: Stable timer hero

The timer's countdown ring SHALL keep one fixed vertical centre in the timer viewport on every block and phase. The block strip, position strip, and set map SHALL NOT move that centre as their copy wraps or their row count changes. When the top chrome and the ring cannot both fit, the ring SHALL sit below the chrome and the page SHALL scroll.

#### Scenario: Moving from a short block to a tall block

- **GIVEN** block 1 with one round and a one-row set map, and block 2 with three rounds and a three-row set map
- **WHEN** the timer leaves block 1 and counts down from block 2
- **THEN** the countdown ring keeps the same vertical centre

#### Scenario: A wrapping position strip

- **GIVEN** block 2 whose position strip needs two lines while block 1's needs one
- **WHEN** block 2 becomes active
- **THEN** the additional line stays above the ring and the ring does not move

#### Scenario: Starting and ending a rest

- **GIVEN** a ready set and the rest that follows it
- **WHEN** the rest starts and later returns to ready
- **THEN** the countdown ring keeps the same vertical centre throughout

#### Scenario: Chrome and ring cannot both fit

- **GIVEN** a viewport whose top chrome and countdown ring cannot both fit at the same time
- **WHEN** the timer appears
- **THEN** the ring sits below the chrome and the rest of the page is reachable by scrolling

### Requirement: Timer content sits below the ring

The set map SHALL render below the countdown ring. When the content below the ring cannot fit, the timer page SHALL scroll rather than move the ring.

#### Scenario: A map too tall for one screen

- **GIVEN** a block whose set map and caption extend below the available space
- **WHEN** the timer shows that block
- **THEN** the ring keeps its centre on first display and the rest of the page is reachable by scrolling

#### Scenario: Accessibility text sizes

- **GIVEN** an accessibility text size
- **WHEN** the timer first appears
- **THEN** the ring is centred and the content that no longer fits is reachable by scrolling
