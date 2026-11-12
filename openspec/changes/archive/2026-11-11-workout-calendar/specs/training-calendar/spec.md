# Spec Delta

## Purpose

The CALENDAR tab: projects the ordered session list onto training days, draws
the month grid and day sheet, and owns the week-start, rest-day and exception
date settings.

## ADDED Requirements

### Requirement: Training days take the rotation in order

Each local calendar day that is not a rest weekday and not inside an exception range is a training day and SHALL plan exactly one session. Consecutive training days SHALL take consecutive sessions from the persisted SESSIONS order and SHALL wrap from the last session to the first.

#### Scenario: Three sessions cycle over four training days

- **GIVEN** SESSIONS in the order Chest, Arms, Legs with no rest days or exceptions
- **WHEN** four consecutive training days are shown
- **THEN** they are planned as Chest, Arms, Legs, Chest

#### Scenario: One session repeats

- **GIVEN** a single saved session named Chest
- **WHEN** consecutive training days are shown
- **THEN** every training day is planned as Chest

#### Scenario: Rest days do not consume a session

- **GIVEN** the order Chest, Arms, Legs and Sunday as the only rest day
- **WHEN** Saturday is Chest, Sunday is shown, and Monday follows
- **THEN** Sunday is REST and Monday is Arms

### Requirement: Edits recalculate only unstarted days

Reordering sessions, adding or deleting a session, changing rest weekdays, or adding or removing an exception SHALL recalculate planned days from the next local date with no started session. Every earlier day and a session already in progress SHALL keep their record. A reorder SHALL restart the sequence at the first session of the new order.

#### Scenario: A reorder changes tomorrow

- **GIVEN** the order Chest, Arms, Legs and Thursday as the next unstarted day
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

### Requirement: Week starts is a display setting

The month grid SHALL start its week on Monday or Sunday. The initial value SHALL be Sunday when the device's calendar starts on Sunday and Monday otherwise; the user's choice SHALL persist. Changing it MUST NOT move a plan or a record.

#### Scenario: Switching to Sunday

- **GIVEN** a Monday-first grid with Thursday planned as Arms
- **WHEN** the user changes WEEK STARTS to Sunday
- **THEN** the columns rotate and Thursday is still planned as Arms

#### Scenario: The choice persists

- **GIVEN** WEEK STARTS set to Sunday
- **WHEN** the app is relaunched
- **THEN** the grid still starts on Sunday

### Requirement: Rest weekdays

The user SHALL be able to mark any set of weekdays as rest days, from none up to six. The app MUST refuse a seventh selection so at least one training weekday remains. Rest days SHALL take no session, consume none, and show REST.

#### Scenario: Adding a rest day

- **GIVEN** no rest days and the next three training days planned as Chest, Arms, Legs
- **WHEN** the user sets Wednesday as a rest day
- **THEN** Wednesday shows REST and Thursday is still planned as the session Wednesday would have taken

#### Scenario: Refusing seven rest days

- **GIVEN** six weekdays already marked as rest
- **WHEN** the user selects the seventh
- **THEN** the selection is refused and six rest days remain

#### Scenario: Removing a rest day

- **GIVEN** Sunday marked as rest
- **WHEN** the user clears Sunday
- **THEN** Sunday becomes a training day and takes the next session in the order

### Requirement: Exception date ranges

An exception SHALL have a start date and an end date, the same day allowed and the end not before the start, plus an optional label. Every date in the range SHALL show CLOSED, plan no session, and consume none. Ranges MAY overlap and MUST NOT repeat. A record on a closed date SHALL still show.

#### Scenario: A four-day closure

- **GIVEN** the order Chest, Arms, Legs and Thursday planned as Arms
- **WHEN** the user adds 24–27 November as GYM CLOSED
- **THEN** those four days show CLOSED and the next open training day is still Arms

#### Scenario: A record survives a closure

- **GIVEN** a Chest record on 24 November
- **WHEN** the user closes 24–27 November
- **THEN** 24 November still shows the Chest record alongside the closure

#### Scenario: An invalid range is refused

- **WHEN** the user sets an end date before the start date
- **THEN** the range is not saved and the previous range is unchanged

#### Scenario: Removing a closure

- **GIVEN** 24–27 November closed
- **WHEN** the user deletes the range
- **THEN** those dates take their planned sessions again

### Requirement: Month grid marks

The month grid SHALL show the month inline above the weekday row and one cell per day: a recorded day with its session code and set bar, a planned day with an amber code and a hollow bar, a rest or closed day with a word, today with a ring, and an adjacent-month day as a muted number. A record SHALL replace a plan in the same cell.

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

Selecting a day SHALL open a sheet. A planned day SHALL show its session and START; START SHALL activate that session and open TIMER at its gate, asking first when another session has progress. A recorded day SHALL show its record read-only. A rest or closed day MUST NOT offer START.

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
- **THEN** the session, sets, and blocks are shown and no field can be edited

#### Scenario: A closed day has no start

- **GIVEN** a day inside a GYM CLOSED range
- **WHEN** the user opens its sheet
- **THEN** the label is shown and no START action is offered

### Requirement: Settings below the grid

The CALENDAR screen SHALL show WEEK STARTS, REST DAYS, and EXCEPTION DATES beneath the month with their current values, and each SHALL open an editor. Values SHALL persist. These settings SHALL remain editable while a session is resting or performing and MUST NOT change the running session.

#### Scenario: The summary reflects the values

- **GIVEN** week starts Monday, Sunday marked rest, and one closure
- **WHEN** the CALENDAR screen is shown
- **THEN** the three rows show Monday, Sunday, and the closure's dates

#### Scenario: Editing during a rest

- **GIVEN** a rest with 30 seconds remaining
- **WHEN** the user adds a rest day
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
