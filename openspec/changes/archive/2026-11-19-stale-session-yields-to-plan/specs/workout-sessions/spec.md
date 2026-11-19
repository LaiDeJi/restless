# Spec Delta

## MODIFIED Requirements

### Requirement: The active session follows the calendar day

The active session SHALL follow the session the calendar plans for today. On launch, foreground, and a local day change, the app SHALL activate today's plan when the current session has no completed sets, is done, or sits at the gate with completed sets from an earlier local day. A performing, resting, or paused session SHALL NOT be replaced, and a session whose completed sets are from today SHALL NOT be replaced. A manual activation SHALL hold for the rest of that day. A rest, closed, skipped, or unplanned day SHALL leave the active session unchanged.

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

#### Scenario: A stale partial session yields to the new day

- **GIVEN** yesterday's session at the gate with some sets done and today planned as Arms
- **WHEN** the app opens or returns to the foreground today
- **THEN** Arms becomes active at its start gate and yesterday's partial run keeps its record

#### Scenario: A stale partial session that is today's plan starts fresh

- **GIVEN** the order holds only Chest, yesterday's Chest sits at the gate with some sets done, and today is planned as Chest
- **WHEN** the app opens today
- **THEN** Chest is active at its start gate with zero completed sets and yesterday's partial run keeps its record

#### Scenario: Progress from today keeps the session

- **GIVEN** today planned as Arms and a Legs session at the gate with sets completed today
- **WHEN** the app returns to the foreground today
- **THEN** Legs stays active at the gate with its completed sets, and no set is lost or skipped

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
