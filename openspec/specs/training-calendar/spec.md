# training-calendar Specification

## Purpose
The CALENDAR tab: projects the ordered session list onto training days, draws
the month grid and day sheet, and owns the rest-gap and exception settings.

## Requirements

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

### Requirement: Edits recalculate only unstarted days

Reordering sessions, adding or deleting a session, changing the rest gap, or adding or removing an exception SHALL recalculate planned days from the next unstarted training day. Every earlier day and a session already in progress SHALL keep their record. A reorder SHALL restart the sequence at the first session of the new order. A gap change SHALL keep the anchor.

#### Scenario: A reorder changes tomorrow

- **GIVEN** a rest gap of 0, the order Chest, Arms, Legs and Thursday as the next unstarted day
- **WHEN** the user drags Legs to the top
- **THEN** Thursday is Legs, Friday is Chest, and Saturday is Arms

#### Scenario: A past record is fixed

- **GIVEN** Monday recorded as Chest
- **WHEN** the user reorders the list
- **THEN** Monday still shows Chest with the same record

#### Scenario: A session in progress is fixed

- **GIVEN** Wednesday's Legs session with three completed sets
- **WHEN** the user reorders the list
- **THEN** Wednesday still shows the Legs record and Thursday uses the new order

#### Scenario: Today changes before the first set

- **GIVEN** today is planned as Arms and no set has been completed
- **WHEN** the user drags Legs to the top
- **THEN** today is planned as Legs

### Requirement: Exceptions are dated or weekly

An exception SHALL be either a dated range or one repeating weekday. A dated range SHALL have a start and an end day, the same day allowed and the end not before the start. A covered day SHALL show CLOSED with the exception's optional label, plan no session, and keep its slot, so the session it would have taken is skipped. Dated ranges MAY overlap and MUST NOT repeat; a weekday MUST NOT be added twice. A record on a covered day SHALL still show.

#### Scenario: A four-day closure skips its sessions

- **GIVEN** the order Chest, Arms, Legs, a rest gap of 0 and Thursday planned as Arms
- **WHEN** the user closes Thursday to Sunday as GYM CLOSED
- **THEN** those four days show CLOSED with the label, plan no session, and Monday is Legs

#### Scenario: A record survives a closure

- **GIVEN** a Chest record on 24 November
- **WHEN** the user closes 24–27 November
- **THEN** 24 November still shows the Chest record alongside the closure

#### Scenario: An invalid range is refused

- **WHEN** the user sets an end date before the start date
- **THEN** the range is not saved and the previous range is unchanged

#### Scenario: Removing a closure restores its slots

- **GIVEN** 24–27 November closed
- **WHEN** the user deletes the range
- **THEN** those dates show their planned sessions again

#### Scenario: A repeating weekday closes every week

- **GIVEN** the order Chest, Arms, a rest gap of 0 and no dated ranges
- **WHEN** the user adds Sunday as a weekday exception
- **THEN** every Sunday shows CLOSED and each Monday is Arms

#### Scenario: A duplicate weekday is refused

- **GIVEN** Sunday already closed
- **WHEN** the user adds Sunday again
- **THEN** the second weekday is not saved

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

### Requirement: Month grid marks

The month grid SHALL show the month inline above the weekday row and one cell per day: a recorded day with its session code and set bar, a planned day with an amber code and a hollow bar, a rest, closed or skipped day with a word, today with a ring, and an adjacent-month day as a muted number. A record SHALL replace a plan in the same cell.

#### Scenario: A recorded day and a planned day

- **GIVEN** Tuesday recorded as Chest and Thursday planned as Arms
- **WHEN** the month is shown
- **THEN** Tuesday carries the Chest code and a filled set bar, and Thursday carries the Arms code and a hollow bar

#### Scenario: A record replaces its plan

- **GIVEN** today planned as Legs and recorded as Arms
- **WHEN** the month is shown
- **THEN** today shows the Arms record

#### Scenario: Adjacent-month days are inert

- **GIVEN** a day from the previous or next month shown in the grid
- **WHEN** the user taps it
- **THEN** no day sheet opens and no plan changes

### Requirement: Several records in one day

A day with more than one record SHALL show the latest record's mark and the number of records. The day sheet SHALL list every record on that date.

#### Scenario: Two workouts on one date

- **GIVEN** a Chest record at 09:00 and a Legs record at 18:00 on the same Tuesday
- **WHEN** the month is shown and Tuesday is opened
- **THEN** the cell shows Legs with a count of two and the sheet lists both records

### Requirement: No start action on the month

The month grid MUST NOT include a start action. Starting a planned session SHALL happen only from that day's sheet.

#### Scenario: The month has no start control

- **WHEN** the CALENDAR screen is shown
- **THEN** no START button appears on the screen above the settings

### Requirement: Session filter chips

The calendar SHALL offer an ALL chip and one chip per saved session, with ALL as the default. Filtering SHALL only dim days that do not match and MUST NOT change plans, records, or the actions offered by a day.

#### Scenario: Filtering to Chest

- **GIVEN** a month with Chest, Arms, and Legs days
- **WHEN** the user taps the Chest chip
- **THEN** Chest days stay legible and the other days dim, and tapping a dimmed day still opens its sheet

### Requirement: Day sheet

Selecting a day SHALL open a sheet. A planned day SHALL show its session, START, CHANGE and SKIP; START activates it and opens TIMER at its gate, asking first when another session has progress. A skipped day SHALL offer UNSKIP instead of START. A recorded day SHALL show its record read-only. Every day without a START SHALL show the next planned session. A rest or closed day MUST NOT offer START, and a closed day MUST NOT offer a new round.

#### Scenario: Starting a planned day

- **GIVEN** Thursday planned as Arms and no session in progress
- **WHEN** the user opens Thursday and taps START
- **THEN** Arms becomes active, TIMER opens at the start gate, and no set is completed

#### Scenario: Starting over a session in progress

- **GIVEN** a Legs session with five completed sets
- **WHEN** the user opens a planned Arms day and taps START
- **THEN** a confirmation names the discarded sets, and cancelling leaves Legs and its record unchanged

#### Scenario: A recorded day is read-only

- **GIVEN** a recorded Chest day
- **WHEN** the user opens its sheet
- **THEN** the session, sets and blocks are shown, the next session is shown, and no field can be edited

#### Scenario: A closed day has no start

- **GIVEN** a day inside a GYM CLOSED range
- **WHEN** the user opens its sheet
- **THEN** the label and the next session are shown, and no START or new-round action is offered

### Requirement: Settings below the grid

The CALENDAR screen SHALL show REST DAYS and EXCEPTIONS beneath the month with their current values. REST DAYS SHALL carry an inline 0–6 stepper in its row with no separate screen; EXCEPTIONS SHALL open an editor. Values SHALL persist and remain editable while a session is resting or performing, and no edit may change the running session.

#### Scenario: The summary reflects the values

- **GIVEN** two rest days and a dated closure with a weekday closure
- **WHEN** the CALENDAR screen is shown
- **THEN** the rows show two days and both exceptions

#### Scenario: Editing during a rest

- **GIVEN** a rest with 30 seconds remaining
- **WHEN** the user changes the rest gap
- **THEN** the rest keeps running and the upcoming days recalculate

#### Scenario: Settings survive relaunch

- **GIVEN** edited calendar settings
- **WHEN** the app is relaunched
- **THEN** the same values are shown

### Requirement: A deleted session leaves the rotation

Deleting a session SHALL remove it from the rotation, recalculate upcoming unstarted days, and keep its records. The last remaining session MUST NOT be deleted.

#### Scenario: Deleting a session that is planned

- **GIVEN** the order Chest, Arms, Legs with upcoming days planned in that order
- **WHEN** the user deletes Arms
- **THEN** upcoming days use Chest and Legs only and the Arms records remain

#### Scenario: The last session is protected

- **GIVEN** one saved session
- **WHEN** the user opens its editor
- **THEN** no enabled delete action is offered
