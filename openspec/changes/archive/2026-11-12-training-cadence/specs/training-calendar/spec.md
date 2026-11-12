# Spec Delta

## ADDED Requirements

### Requirement: Rest gap sets the days between sessions

The user SHALL set one rest gap of 0 to 6 days, the number of days between one session and the next. The app MUST clamp the value to that range. Changing the gap SHALL keep the rotation anchor and recalculate every planned day.

#### Scenario: A gap change reshapes the week

- **GIVEN** the anchor on Monday, the order Chest, Arms, Legs and a rest gap of 0
- **WHEN** the user sets the gap to 1
- **THEN** Tuesday is REST, Wednesday is Arms, and Friday is Legs

#### Scenario: The gap stops at six

- **GIVEN** a rest gap of 6
- **WHEN** the user steps up again
- **THEN** the gap stays 6

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

Any open date on or after today SHALL offer a new round from that date. Starting a round SHALL make that date the first session of the persisted SESSIONS order, recalculate every later slot from there, and clear skipped days and per-date exercise changes. It MUST NOT activate a session, change a record, or alter a session in progress.

#### Scenario: A round starts on a rest day

- **GIVEN** a rest gap of 1 and Monday shown as REST
- **WHEN** the user starts a new round on Monday
- **THEN** Monday is Chest, Tuesday is REST, and Wednesday is Arms

#### Scenario: A round moves the upcoming order

- **GIVEN** a rest gap of 1 and Thursday planned as Legs
- **WHEN** the user starts a new round on Thursday
- **THEN** Thursday is Chest, Friday is REST, and Saturday is Arms

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

A planned day from today forward SHALL offer a change of exercise. Choosing a session SHALL plan that session on that date only, mark the date CHANGED, and leave the order, the anchor, the gap, the dates and every other day unchanged. The slot SHALL still consume the session the schedule assigned. Choosing the scheduled session SHALL clear the change; a new round SHALL clear every change.

#### Scenario: A change leaves the schedule

- **GIVEN** a rest gap of 2, the order Chest, Arms, Legs, Sat 14 planned as Arms and Tue 17 as Legs
- **WHEN** the user changes Sat 14 to Chest
- **THEN** Sat 14 shows Chest with CHANGED, and Tue 17 is still Legs

#### Scenario: The scheduled session clears the change

- **GIVEN** Sat 14 changed to Chest
- **WHEN** the user chooses Arms
- **THEN** Sat 14 shows Arms and no CHANGED mark remains

#### Scenario: A rest day offers no change

- **GIVEN** Fri 13 is a rest day
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

A planned day SHALL offer SKIP from its sheet. A skipped date SHALL show a skip mark, offer no START, and persist. Skipping MUST NOT change the rest gap, the rotation anchor, the order, or another day's plan. A skipped date SHALL offer UNSKIP, and clearing the skip SHALL restore its plan.

#### Scenario: Skipping keeps the next session

- **GIVEN** a rest gap of 0, the order Chest, Arms, Legs, Thursday planned as Arms and Friday as Legs
- **WHEN** the user skips Thursday
- **THEN** Thursday shows the skip mark and Friday is still Legs

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

## MODIFIED Requirements

### Requirement: Training days take the rotation in order

The cadence SHALL give every local day an offset from the rotation anchor. A day whose offset is a multiple of the rest gap plus one SHALL be a session slot. An open slot SHALL be a training day and plan the next session in the persisted SESSIONS order, wrapping. A day without a slot SHALL be REST and plan no session.

#### Scenario: Three sessions cycle over four training days

- **GIVEN** the order Chest, Arms, Legs, a rest gap of 0 and no exceptions
- **WHEN** four consecutive days are shown
- **THEN** they are planned as Chest, Arms, Legs, Chest

#### Scenario: One session repeats

- **GIVEN** a single saved session named Chest
- **WHEN** consecutive training days are shown
- **THEN** every training day is planned as Chest

#### Scenario: Rest days do not consume a session

- **GIVEN** the order Chest, Arms, Legs and a rest gap of 1
- **WHEN** Monday is Chest, Tuesday is shown, and Wednesday follows
- **THEN** Tuesday is REST and Wednesday is Arms

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

## REMOVED Requirements

### Requirement: Week starts is a display setting

**Reason**: The grid follows the device's first weekday instead. The round's first day is the anchor, which the user sets with a new round, so a manual column order was a second, unrelated way to line the month up.

**Migration**: The stored week-start choice is dropped from the v2 document and ignored when a v1 document is read. The grid uses the device's first weekday; no user action is needed.

### Requirement: Rest weekdays

**Reason**: The weekday-rest model is replaced by the rest gap, and weekday regularity by a repeating-weekday exception. Keeping both would be two sources of truth for a day off.

**Migration**: Each stored rest weekday becomes a weekday exception on the same weekday, and the gap starts at 0. A closed slot consumes its session where a rest weekday paused the order, so the first cycle after the upgrade can shift by one session.

### Requirement: Exception date ranges

**Reason**: Exceptions now cover a dated range or a repeating weekday; the dated-range requirement is folded into the broader exception requirement.

**Migration**: Stored ranges keep their start, end and label as dated exceptions. No user action is needed.
