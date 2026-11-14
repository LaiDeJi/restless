# Spec Delta

## ADDED Requirements

### Requirement: The active session follows the calendar day

The active session SHALL follow the session the calendar plans for today. On launch, foreground, and a local day change, the app SHALL activate today's plan when the current session has no completed sets or is done. A performing, resting, or paused session SHALL NOT be replaced. A manual activation SHALL hold for the rest of that day. A rest, closed, skipped, or unplanned day SHALL leave the active session unchanged.

#### Scenario: A new day at the start gate

- **GIVEN** the order Chest, Arms, Legs, today planned as Arms, and Chest active with no completed sets
- **WHEN** the app opens today
- **THEN** Arms becomes active at its start gate, the ACTIVE badge moves to Arms, and TIMER shows Arms

#### Scenario: A running session is protected

- **GIVEN** today planned as Arms and a Legs session paused, performing, or resting from an earlier day
- **WHEN** the app returns to the foreground on the new day
- **THEN** Legs stays active, keeps its completed sets and phase, and no set is lost or skipped

#### Scenario: A finished session yields to the new day

- **GIVEN** a session marked done yesterday and today planned as Arms
- **WHEN** the app opens or returns to the foreground today
- **THEN** Arms becomes active at its start gate

#### Scenario: A one-session rotation starts fresh

- **GIVEN** Chest is the only session, it was marked done yesterday, and today is planned as Chest
- **WHEN** the app opens or returns to the foreground today
- **THEN** Chest is active at its start gate with zero completed sets

#### Scenario: A manual pick holds for the day

- **GIVEN** today planned as Arms
- **WHEN** the user activates Legs in SESSIONS or from a calendar day sheet
- **THEN** Legs stays active for the rest of that day, including after backgrounding and foregrounding

#### Scenario: The next day follows the plan again

- **GIVEN** the user manually activated Legs on a day planned as Arms
- **WHEN** the next day starts and today's plan is Chest
- **THEN** Chest becomes active at its start gate

#### Scenario: A rest day keeps the session

- **GIVEN** today is a rest day and Chest is active
- **WHEN** the app opens or returns to the foreground
- **THEN** Chest remains active and the timer keeps its state

#### Scenario: A per-date change is honoured

- **GIVEN** today's planned Arms was changed to Legs on the calendar and Chest is active with no sets
- **WHEN** the app opens today
- **THEN** Legs becomes active at its start gate

#### Scenario: The day changes while the app is open

- **GIVEN** Chest active at the start gate today, tomorrow planned as Arms, and the app left open
- **WHEN** the local day changes to tomorrow
- **THEN** Arms becomes active at its start gate without a relaunch
