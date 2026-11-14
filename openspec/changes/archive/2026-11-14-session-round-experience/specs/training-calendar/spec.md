# Spec Delta

## MODIFIED Requirements

### Requirement: Training days take the rotation in order

The cadence SHALL give every local day an offset from the rotation anchor. A
session round SHALL consist of one consecutive session day for each saved
session, in SESSIONS order, followed by the configured number of rest days. An
open session day SHALL be a training day and plan that round's session. A rest
day SHALL be REST and plan no session. The order SHALL wrap after the last
saved session, and the next round SHALL start after the rest days.

#### Scenario: Three sessions cycle over four training days

- **GIVEN** the order Chest, Arms, Legs, a rest gap of 0 and no exceptions
- **WHEN** four consecutive days from the anchor are shown
- **THEN** they are planned as Chest, Arms, Legs, Chest

#### Scenario: The gap follows the whole round

- **GIVEN** the order Chest, Arms, Legs and a rest gap of 1
- **WHEN** five consecutive days from the anchor are shown
- **THEN** Monday is Chest, Tuesday is Arms, Wednesday is Legs, Thursday is
  REST, and Friday is Chest

#### Scenario: Two rest days follow two sessions

- **GIVEN** the order Chest, Arms and a rest gap of 2
- **WHEN** four consecutive days from the anchor are shown
- **THEN** Monday is Chest, Tuesday is Arms, Wednesday is REST, and Thursday is
  REST

#### Scenario: Rest days do not consume a session

- **GIVEN** the order Chest, Arms, Legs and a rest gap of 1
- **WHEN** Monday is Chest, Tuesday is Arms, and Wednesday is Legs
- **THEN** Thursday is REST and Friday is Chest

#### Scenario: One session repeats

- **GIVEN** a single saved session named Chest and a rest gap of 0
- **WHEN** consecutive days from the anchor are shown
- **THEN** every day is planned as Chest

#### Scenario: One session still takes the gap

- **GIVEN** a single saved session named Chest and a rest gap of 1
- **WHEN** three consecutive days from the anchor are shown
- **THEN** Monday is Chest, Tuesday is REST, and Wednesday is Chest

### Requirement: Rest gap sets the rest days between rounds

The user SHALL set one rest gap of 0 to 6 days, the number of rest days after
the last session of a round and before the next round. The app MUST clamp the
value to that range. Changing the gap SHALL keep the rotation anchor and
recalculate every planned day. The CALENDAR row SHALL read BETWEEN ROUNDS.

#### Scenario: A gap change reshapes the week

- **GIVEN** the anchor on Monday, the order Chest, Arms, Legs and a rest gap of 0
- **WHEN** the user sets the gap to 1
- **THEN** Monday is Chest, Tuesday is Arms, Wednesday is Legs, Thursday is
  REST, and Friday is Chest

#### Scenario: The gap stops at six

- **GIVEN** a rest gap of 6
- **WHEN** the user steps up again
- **THEN** the gap stays 6

#### Scenario: The setting names rounds

- **GIVEN** a rest gap of 1
- **WHEN** the CALENDAR screen is shown
- **THEN** the REST DAYS row reads BETWEEN ROUNDS with the value 1, and its
  summary reads 1 REST DAY BETWEEN ROUNDS

### Requirement: Start a new round from a date

Any open date on or after today SHALL offer a new round from that date. Starting
a round SHALL make that date the first session of the persisted SESSIONS order,
recalculate every later session and rest day from there, and clear skipped days
and per-date exercise changes. It MUST NOT activate a session, change a record,
or alter a session in progress.

#### Scenario: A round starts on a rest day

- **GIVEN** a rest gap of 1 and Monday shown as REST
- **WHEN** the user starts a new round on Monday
- **THEN** Monday is Chest, Tuesday is Arms, Wednesday is Legs, Thursday is
  REST, and Friday is Chest

#### Scenario: A round moves the upcoming order

- **GIVEN** a rest gap of 1 and Thursday planned as Legs
- **WHEN** the user starts a new round on Thursday
- **THEN** Thursday is Chest, Friday is Arms, Saturday is Legs, Sunday is REST,
  and Monday is Chest

#### Scenario: Records and a running session stay

- **GIVEN** a Chest record on Tuesday and a Legs session with three completed sets
- **WHEN** a new round starts on Monday
- **THEN** the record and the running session are unchanged

#### Scenario: A new round clears skips

- **GIVEN** Friday skipped
- **WHEN** a new round starts on Monday
- **THEN** Friday is planned again

#### Scenario: A closed day offers no round

- **GIVEN** a day inside a closure
- **WHEN** its sheet is shown
- **THEN** no new-round action is offered

#### Scenario: A past date offers no round

- **GIVEN** yesterday, open and with no record
- **WHEN** its sheet is shown
- **THEN** no new-round action is offered

### Requirement: Change the exercise on a date

A planned day from today forward SHALL offer a change of exercise. Choosing a
session SHALL plan that session on that date only, mark the date CHANGED, and
leave the order, the anchor, the gap, the dates and every other day unchanged.
The slot SHALL still consume the session the schedule assigned. Choosing the
scheduled session SHALL clear the change; a new round SHALL clear every change.

#### Scenario: A change leaves the schedule

- **GIVEN** a rest gap of 2, the order Chest, Arms, Legs, Sat 14 planned as Arms
  and Sun 15 as Legs
- **WHEN** the user changes Sat 14 to Chest
- **THEN** Sat 14 shows Chest with CHANGED, and Sun 15 is still Legs

#### Scenario: The scheduled session clears the change

- **GIVEN** Sat 14 changed to Chest
- **WHEN** the user chooses Arms
- **THEN** Sat 14 shows Arms and no CHANGED mark remains

#### Scenario: A rest day offers no change

- **GIVEN** Mon 16 is a rest day
- **WHEN** its sheet is shown
- **THEN** no CHANGE action is offered

#### Scenario: A record cannot be changed

- **GIVEN** a recorded Chest day
- **WHEN** its sheet is shown
- **THEN** no CHANGE action is offered

#### Scenario: A new round clears changes

- **GIVEN** a rest gap of 0 and Sat 14 changed to Chest
- **WHEN** a new round starts on Thu 12
- **THEN** Sat 14 shows Legs and no CHANGED mark remains

### Requirement: Skip a planned session

A planned day SHALL offer SKIP from its sheet. A skipped date SHALL show a skip
mark, offer no START, and persist. Skipping MUST NOT change the rest gap, the
rotation anchor, the order, or another day's plan. A skipped date SHALL offer
UNSKIP, and clearing the skip SHALL restore its plan.

#### Scenario: Skipping keeps the next session

- **GIVEN** a rest gap of 0, the order Chest, Arms, Legs, Thursday planned as
  Arms and Friday as Legs
- **WHEN** the user skips Thursday
- **THEN** Thursday shows the skip mark and Friday is still Legs

#### Scenario: A skipped session keeps its place in the round

- **GIVEN** a rest gap of 1, the order Chest, Arms, Legs, Monday planned as
  Chest, Tuesday as Arms and Wednesday as Legs
- **WHEN** the user skips Tuesday
- **THEN** Wednesday is still Legs, Thursday is REST, and Friday is Chest

#### Scenario: A skip is reversible

- **GIVEN** Thursday skipped
- **WHEN** the user clears the skip
- **THEN** Thursday shows Arms and offers START

#### Scenario: A skipped day has no start

- **GIVEN** a skipped day
- **WHEN** its sheet opens
- **THEN** no START action is offered

#### Scenario: A skip persists

- **GIVEN** a skipped day
- **WHEN** the app is relaunched
- **THEN** the day is still skipped

#### Scenario: A recorded day cannot be skipped

- **GIVEN** a day with a Chest record
- **WHEN** its sheet opens
- **THEN** no SKIP action is offered

## RENAMED Requirements

- FROM: `### Requirement: Rest gap sets the days between sessions`
- TO: `### Requirement: Rest gap sets the rest days between rounds`
