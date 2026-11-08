# Workout Sessions Specification

## Purpose

Saved workout sessions made of ordered body-part blocks, each with its own rounds, sets, and rest values, managed through the app's timer and sessions pages.

## Requirements

### Requirement: Session plans are ordered blocks

A session SHALL have a stable identifier, a name, and one or more ordered blocks. Each block SHALL have a stable identifier, a name, rounds, sets per round, set rest, round rest, and one or more block movements. Rounds and sets per round SHALL be 1 or more. Blocks SHALL run in the order shown in the session.

#### Scenario: A session stores blocks in order

- **GIVEN** a session containing Biceps followed by Triceps
- **WHEN** the session is opened
- **THEN** Biceps is the first block and Triceps is the second block

#### Scenario: A session never has zero blocks

- **WHEN** the only block in a session is deleted
- **THEN** the deletion is refused and the block remains

### Requirement: Block structure has no arrangement mode

A block SHALL define its schedule only by rounds, sets per round, and its ordered movements. It SHALL NOT store or expose a straight/circuit arrangement. One movement SHALL repeat that movement; two or more movements SHALL run each movement's sets-per-round sets in order within each round. A sequential pair SHALL be two blocks.

#### Scenario: One movement, four rounds of four sets

- **GIVEN** a block with one movement, rounds 4, sets per round 4
- **WHEN** the block is shown
- **THEN** it reports 16 sets and contains no arrangement label

#### Scenario: Two movements, two rounds of one set each

- **GIVEN** a block with Biceps and Triceps, rounds 2, sets per round 1
- **WHEN** the block runs
- **THEN** each round runs Biceps then Triceps and the block reports 4 sets

#### Scenario: Sequential pair

- **GIVEN** a user wants Biceps three sets followed by Triceps three sets
- **WHEN** they build the plan
- **THEN** it is two blocks, each with rounds 1 and sets per round 3

### Requirement: Rounds and sets have no upper limit

Rounds and sets per round SHALL accept any integer of 1 or more. The editor MUST NOT disable increase at 6 or at any other product cap. Set rest SHALL be 0 or 15–600 seconds in 15-second steps; round rest SHALL be 15–600 seconds in 15-second steps.

#### Scenario: Increasing past six

- **GIVEN** a block with 6 rounds
- **WHEN** the user taps increase on ROUNDS
- **THEN** the value becomes 7 and the increase control stays enabled

#### Scenario: Typing a large sets value

- **WHEN** the user types 120 into SETS PER ROUND and confirms
- **THEN** the block stores 120 sets per round

#### Scenario: Rest limits are unchanged

- **GIVEN** a block with set rest 600 seconds
- **WHEN** the user tries to increase set rest
- **THEN** the value stays at 600 and the increase control is disabled

#### Scenario: Zero set rest

- **GIVEN** a block with set rest 0
- **WHEN** the user increases set rest once
- **THEN** it becomes 15 seconds

#### Scenario: Large plan totals are exact

- **GIVEN** a block with 40 rounds, 25 sets per round, and one movement
- **WHEN** the block summary is shown
- **THEN** it reports 1000 total sets with no overflow or wrapped number

### Requirement: Exact numeric entry for rounds and sets

Tapping a rounds or sets-per-round value SHALL open numeric entry for that value. Committing an integer of 1 or more SHALL set the value exactly. Committing a number below 1 SHALL clamp it to 1. Empty or non-numeric input SHALL leave the previous value unchanged.

#### Scenario: Entering an exact value

- **GIVEN** a block with 3 sets per round
- **WHEN** the user taps the value, types 12, and confirms
- **THEN** the block has 12 sets per round

#### Scenario: Entering zero

- **WHEN** the user types 0 and confirms
- **THEN** the value becomes 1

#### Scenario: Leaving the field empty

- **GIVEN** a block with 4 rounds
- **WHEN** the user clears the field and confirms without typing
- **THEN** rounds remains 4

### Requirement: Bottom tab navigation

The app SHALL have two persistent bottom tabs, TIMER and SESSIONS. TIMER SHALL be the default tab. Switching tabs MUST NOT pause, reset, or lose a running rest. The timer's EDIT action SHALL open the active session in SESSIONS.

#### Scenario: Launch opens the timer

- **WHEN** the app launches
- **THEN** the TIMER tab is selected

#### Scenario: Switching tabs during rest

- **GIVEN** a set rest with 40 seconds remaining
- **WHEN** the user switches to SESSIONS for 10 seconds and returns to TIMER
- **THEN** approximately 30 seconds remain and the rest is still running

#### Scenario: EDIT opens the active session

- **GIVEN** the active session is Chest
- **WHEN** the user taps EDIT on the timer
- **THEN** SESSIONS opens on the Chest session editor

### Requirement: Sessions page

SESSIONS SHALL list every saved session, mark the active one, and open a session editor when a session is selected. The page SHALL offer creating a new session as an unsaved draft; the list SHALL NOT change until the draft is committed.

#### Scenario: Listing sessions

- **GIVEN** sessions named Chest and Arms with Arms active
- **WHEN** SESSIONS opens
- **THEN** both are listed and Arms is marked active

#### Scenario: Creating a session

- **WHEN** the user taps the add control
- **THEN** a session editor opens on an unsaved draft, the list still shows the same saved sessions, and the active session is unchanged

### Requirement: A new session is committed by DONE or USE THIS SESSION

A new session SHALL NOT be saved when its editor opens. DONE at the top-right SHALL save exactly one session with the edited name, blocks, and values, leave it inactive, and return to SESSIONS. Back and swipe-back SHALL discard the draft without saving. USE THIS SESSION SHALL save the draft and activate it. The default name SHALL receive its unique suffix when the session is saved.

#### Scenario: DONE saves the draft

- **GIVEN** the add control opened an editor on a draft named New session with one block
- **WHEN** the user edits the name and taps the center of DONE
- **THEN** SESSIONS lists exactly one new session with that name and block, it is not active, and the timer is unchanged

#### Scenario: Back discards the draft

- **GIVEN** the add control opened an editor on a draft
- **WHEN** the user taps back
- **THEN** the draft closes, no session is saved, and the list and active session are unchanged

#### Scenario: Swipe-back discards the draft

- **GIVEN** the add control opened an editor on a draft
- **WHEN** the user swipes back
- **THEN** the draft closes, no session is saved, and the list and active session are unchanged

#### Scenario: USE THIS SESSION commits and activates

- **GIVEN** a draft with an edited name and block
- **WHEN** the user taps USE THIS SESSION
- **THEN** the draft is saved, becomes the active session, and the timer shows its ready gate

#### Scenario: The default name is unique at save time

- **GIVEN** saved sessions include New session
- **WHEN** the user taps DONE on a draft whose name was not changed
- **THEN** the saved session is named New session 2

#### Scenario: Backgrounding does not save the draft

- **GIVEN** an unsaved draft with edits
- **WHEN** the app goes to the background and returns
- **THEN** no session was saved and the draft still shows its edits

#### Scenario: DONE saves once

- **GIVEN** an unsaved draft
- **WHEN** the user taps DONE once
- **THEN** exactly one session is saved

### Requirement: Session management

From the session editor a user SHALL be able to rename, activate, and delete a session. The last remaining session MUST NOT be deleted. Deleting a session SHALL require two taps on the delete action.

#### Scenario: Activating a session

- **GIVEN** Chest is active with sets completed
- **WHEN** the user activates Arms
- **THEN** Arms becomes active and the timer is not started at its first set with no completed sets

#### Scenario: Deleting a session in two steps

- **GIVEN** two saved sessions
- **WHEN** the user taps delete once and then confirms
- **THEN** the session is removed and another session becomes active

#### Scenario: Refusing to delete the last session

- **GIVEN** one saved session
- **WHEN** the session editor is shown
- **THEN** no enabled delete action is offered

### Requirement: One-tap add from the movement library

The block editor SHALL show an `ADD FROM LIBRARY` list of recorded movements that are not already in the block. Tapping one SHALL append that movement with MANUAL and no target in one edit, keep the add-movement sheet closed, and apply the existing two-movement rounds rule. The list SHALL be hidden while editing is locked and absent when no unused movement remains. The add-movement sheet SHALL remain for several movements, custom ends and targets, and typed names.

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
- **THEN** its end condition and target can be changed to TIME or REPS

#### Scenario: Locked block editor

- **GIVEN** a session resting, with editing locked
- **WHEN** the block editor is shown
- **THEN** the ADD FROM LIBRARY list is not offered

### Requirement: Block management

From the session editor a user SHALL add, rename, reorder, and delete blocks. Each saved block row SHALL be draggable by a grip and SHALL offer delete except when it is the only block. A session MUST keep one block. Delete SHALL require two taps; drag and delete SHALL be disabled while editing is locked.

#### Scenario: Reordering blocks

- **GIVEN** blocks Biceps, Triceps, Back
- **WHEN** the user drags Back above Biceps
- **THEN** the session order is Back, Biceps, Triceps

#### Scenario: Deleting the last block

- **GIVEN** a session with one block
- **WHEN** the user looks for a block delete action
- **THEN** no enabled delete action is offered

#### Scenario: Locked block rows

- **GIVEN** a running rest
- **WHEN** the session editor is shown
- **THEN** neither drag nor delete is available on a block row

### Requirement: A new block opens the block editor layout

`+ ADD BLOCK` SHALL open a new block in the same editor layout used to edit a saved block: block name, summary, rounds, sets per round, set rest, round rest, ordered movements, order preview, and `+ ADD MOVEMENT`. Editing a saved block SHALL show the same fields and actions.

#### Scenario: Adding a block uses the block editor layout

- **GIVEN** a session with one saved block
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the page shows the block name field, rounds, sets per round, set rest, round rest, the movement list, the order preview, and `+ ADD MOVEMENT`, matching the page shown when a saved block is opened

### Requirement: A new block starts from the previous block's rests

A new block SHALL start as `Untitled block` with rounds 1, sets per round 3, the previous block's set and round rests, and no movements. Its movements SHALL be added through the block editor's `ADD FROM LIBRARY` list or the same add-movement picker a saved block uses.

#### Scenario: Adding a block does not clone movements

- **GIVEN** a session whose last block is Biceps
- **WHEN** the user taps `+ ADD BLOCK`, adds Triceps, and taps DONE
- **THEN** the new block contains only Triceps and inherits the last block's set and round rests

#### Scenario: A new block starts from the documented defaults

- **GIVEN** a session whose last block has set rest 45 and round rest 90
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the new block is named `Untitled block` with rounds 1, sets per round 3, set rest 45, round rest 90, and no movements

### Requirement: A new block is staged until DONE

The new block MUST NOT be part of the session until DONE appends it. Back, cancel, or closing the new block SHALL discard it, and backgrounding MUST NOT add it to the session. DONE SHALL stay disabled until the new block has at least one movement.

#### Scenario: Adding a block waits for DONE

- **GIVEN** a session with one block
- **WHEN** the user taps `+ ADD BLOCK`
- **THEN** the block editor opens and the session still has one block until DONE

#### Scenario: DONE appends the staged block

- **GIVEN** a staged block named Arms with rounds 4, sets per round 3, set rest 45, round rest 90, and one movement
- **WHEN** the user taps DONE
- **THEN** the session appends that block with those values and flushes the plan

#### Scenario: Cancelling the add-block picker adds no block

- **GIVEN** the new block editor is open from `+ ADD BLOCK` with one movement added
- **WHEN** the user goes back or cancels
- **THEN** the session still has the same blocks and no new block is saved

#### Scenario: A new block needs a movement before DONE

- **GIVEN** the new block editor is open with nothing added
- **WHEN** the user looks at DONE
- **THEN** DONE is disabled

#### Scenario: A staged block does not survive leaving the editor

- **GIVEN** the new block editor is open with a name and values but no movements
- **WHEN** the app is backgrounded and returns
- **THEN** the session still has its original blocks and no empty block

### Requirement: Block copy is numeric

Block rows and summaries SHALL describe a block with movements, rounds, sets per round, total sets, and the two rest values. They SHALL NOT show STRAIGHT, SUPERSET, or CIRCUIT.

#### Scenario: Two-movement block row

- **GIVEN** a block with 2 movements, 2 rounds, 1 set per round
- **WHEN** the session editor shows the row
- **THEN** it reads 2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS, with no SUPERSET or CIRCUIT

#### Scenario: One-movement block row

- **GIVEN** a block with 1 movement, 4 rounds, 4 sets per round
- **WHEN** the session editor shows the row
- **THEN** it reads 1 MOVEMENT · 4 ROUNDS · 4 SETS EACH · 16 SETS

### Requirement: Movement list editing

Within a block editor a user SHALL be able to reorder and delete the block's movements from the movement list. Each movement row SHALL be draggable by a grip handle and SHALL offer a delete action except when it is the only movement. Tapping a row SHALL open its movement editor. A block MUST keep at least one movement, deletion SHALL require two taps, and drag and delete SHALL be disabled while editing is locked.

#### Scenario: Reordering movements by drag

- **GIVEN** a block with movements Bench Press, Incline Press, Fly
- **WHEN** the user drags Fly above Bench Press
- **THEN** the block order is Fly, Bench Press, Incline Press

#### Scenario: Deleting a movement from the list

- **GIVEN** a block with two movements
- **WHEN** the user taps a movement's delete action once and then again
- **THEN** that movement is removed and the block keeps the other one

#### Scenario: The last movement has no delete

- **GIVEN** a block with one movement
- **WHEN** the movement list is shown
- **THEN** no delete action is offered on that row

#### Scenario: Locked movement rows

- **GIVEN** a running rest
- **WHEN** the block editor is shown
- **THEN** neither drag nor delete is available on a movement row

### Requirement: Destructive actions use red

DELETE SESSION and the block and movement row delete actions SHALL use the destructive red. The first tap SHALL arm the action with a stronger red and the copy TAP AGAIN TO DELETE.

#### Scenario: DELETE SESSION is red

- **GIVEN** two saved sessions
- **WHEN** the session editor is shown
- **THEN** DELETE SESSION is red

#### Scenario: A block row delete arms in red

- **GIVEN** a session with two blocks
- **WHEN** the user taps a block's delete action once
- **THEN** the row shows TAP AGAIN TO DELETE in the stronger red

#### Scenario: A movement row delete arms in red

- **GIVEN** a block with two movements
- **WHEN** the user taps a movement's delete action once
- **THEN** the row shows TAP AGAIN TO DELETE in the stronger red

### Requirement: Stored plans migrate to rounds and sets per round

Stored plans SHALL read into the new block shape without losing sets or rest. A legacy part R × S SHALL become one block with rounds R, sets per round S, one manual movement, and its name and rests. A straight block with count C SHALL become rounds 1, sets per round C; with several movements it SHALL split into one block per movement. A circuit with count C SHALL become rounds C, sets per round 1. The active session SHALL survive; an unreadable plan SHALL fall back to the Chest seed.

#### Scenario: Legacy part

- **GIVEN** a stored part named Chest with 3 rounds, 3 sets, 60 set rest, 120 round rest
- **WHEN** the app opens it after the update
- **THEN** it is one block named Chest with rounds 3, sets per round 3, and those rests

#### Scenario: Straight block

- **GIVEN** a stored straight block with count 9 and one movement
- **WHEN** it is read
- **THEN** it has rounds 1 and sets per round 9

#### Scenario: Straight block with two movements

- **GIVEN** a stored straight block with Bench and Incline, count 3
- **WHEN** it is read
- **THEN** it becomes two blocks, Bench then Incline, each with rounds 1 and sets per round 3

#### Scenario: Circuit block

- **GIVEN** a stored circuit block with Biceps and Triceps, count 3
- **WHEN** it is read
- **THEN** it has rounds 3 and sets per round 1

### Requirement: Duplicate movement rows collapse

Adjacent duplicate movements in a stored circuit SHALL collapse into one movement with sets per round equal to the duplicate count when they share the same library movement, end condition, and target. Duplicates that are not adjacent or differ SHALL remain separate movements.

#### Scenario: Four Biceps rows

- **GIVEN** a stored circuit with four adjacent Biceps rows, count 4, same end condition and target
- **WHEN** it is read
- **THEN** it becomes one Biceps movement with rounds 4 and sets per round 4

#### Scenario: Different targets

- **GIVEN** a stored circuit with two adjacent Biceps rows with different targets
- **WHEN** it is read
- **THEN** both movements remain

### Requirement: Steppers use their whole surface and repeat while held

A stepper's minus and plus SHALL change the value when tapped anywhere on the visible control, including its center. Holding a direction SHALL repeat its step after 500 ms and every 100 ms until release or the range limit. Every repeat SHALL update the displayed value immediately, while persistence stays coalesced after the burst.

#### Scenario: A center tap on plus increases the value

- **GIVEN** a block with 9 sets per round
- **WHEN** the user taps the center of the plus
- **THEN** sets per round becomes 10 and the plus stays enabled

#### Scenario: A center tap on minus decreases the value

- **GIVEN** a block with 9 sets per round
- **WHEN** the user taps the center of the minus
- **THEN** sets per round becomes 8 and the minus stays enabled

#### Scenario: Holding plus repeats

- **GIVEN** a block with 1 round
- **WHEN** the user presses and holds the plus for two seconds
- **THEN** rounds increases repeatedly and ends above 2

#### Scenario: Releasing stops the repeat

- **GIVEN** the user is holding a stepper
- **WHEN** the user releases it
- **THEN** no further change occurs

#### Scenario: A rest stepper stops at its limit

- **GIVEN** set rest is 600 seconds
- **WHEN** the user holds the plus
- **THEN** the value stays at 600

#### Scenario: A held set rest leaves zero

- **GIVEN** set rest is 0
- **WHEN** the user holds the plus
- **THEN** the value advances through 15, 30, and higher without wrapping

#### Scenario: A lock blocks tap and hold

- **GIVEN** the session is performing or resting
- **WHEN** the user taps or holds a stepper
- **THEN** the value does not change

### Requirement: Responsive editing

A stepper tap or numeric commit SHALL update the displayed value on the same interaction. Persistence, session reset, and Live Activity refresh SHALL be coalesced after a short idle period and applied at most once per burst. Leaving the editor SHALL flush any pending edit. No Live Activity request SHALL start for each tap.

#### Scenario: Rapid stepper taps

- **GIVEN** set rest is 60 seconds
- **WHEN** the user taps increase five times quickly
- **THEN** the display advances on every tap and ends at 75 seconds without a visible freeze

#### Scenario: One commit per burst

- **WHEN** the user edits a value several times in quick succession
- **THEN** the plan is saved once after the taps stop, not once per tap

#### Scenario: Leaving with a pending edit

- **GIVEN** an edit burst that has not yet reached its idle commit
- **WHEN** the user leaves the editor
- **THEN** the pending change is saved before the editor closes

### Requirement: Session and block summaries

A session SHALL summarize its number of blocks, total sets, and total rest. A block SHALL summarize its movements, rounds, sets per round, total sets, and its two rest values. A total rest of 60 minutes or more SHALL be shown with hours.

#### Scenario: Summarizing a multi-block session

- **GIVEN** Biceps 3 rounds × 3 sets with 60/120 and Triceps 2 rounds × 4 sets with 45/90
- **WHEN** the session summary is shown
- **THEN** it reports 2 blocks and 17 total sets, and total rest is 1080 seconds

#### Scenario: Long total rest

- **GIVEN** a session whose total rest exceeds one hour
- **WHEN** the summary is shown
- **THEN** the duration includes an hours component

### Requirement: Name rules for sessions and blocks

Session and block names SHALL be trimmed and limited to 18 characters. An empty session name SHALL become Untitled. An empty block name SHALL become Untitled block.

#### Scenario: Empty session name

- **WHEN** the user clears the session name and leaves the field
- **THEN** the name becomes Untitled

#### Scenario: Long block name

- **WHEN** the user types more than 18 characters into a block name
- **THEN** only the first 18 characters are kept

### Requirement: Session name editing dismisses by page tap

The session editor SHALL NOT show a keyboard accessory bar or its Done button
while editing the session name. A tap on the page outside the focused name
field SHALL end editing and dismiss the keyboard, while a tap inside the focused
field SHALL keep the keyboard. Ending editing SHALL commit the trimmed name.

#### Scenario: Tapping the page dismisses the keyboard

- **GIVEN** the session editor with the keyboard open in the name field
- **WHEN** the user taps an empty part of the session page
- **THEN** the keyboard is dismissed and the trimmed name is committed

#### Scenario: The keyboard has no accessory Done button

- **GIVEN** the session editor with the name field focused
- **WHEN** the keyboard is shown
- **THEN** no Done button or other accessory bar appears above it

#### Scenario: Tapping a block row dismisses and opens

- **GIVEN** the session editor with the keyboard open in the name field
- **WHEN** the user taps a block row
- **THEN** the name is committed, the keyboard is dismissed, and the block editor opens

#### Scenario: Tapping the name field keeps the keyboard

- **GIVEN** the session editor with the keyboard open in the name field
- **WHEN** the user taps inside the name field
- **THEN** the keyboard stays open and name editing continues

### Requirement: Text-entry pages dismiss the keyboard on a page tap

On an editor page with a focused text field, a tap on the page outside that
field SHALL end editing and dismiss the keyboard. A tap inside the focused field
SHALL keep the keyboard. The typed text SHALL remain in the field.

#### Scenario: Tapping the add-movement page dismisses the keyboard

- **GIVEN** the add-movement picker with the keyboard open in the new movement field
- **WHEN** the user taps the page outside the field
- **THEN** the keyboard is dismissed and the typed name stays in the field

#### Scenario: Tapping a block or movement page dismisses the keyboard

- **GIVEN** the block name field is focused with the keyboard open
- **WHEN** the user taps an empty part of the page
- **THEN** the keyboard is dismissed and the trimmed block name is committed

#### Scenario: Tapping the focused field keeps the keyboard

- **GIVEN** the keyboard is open in a focused text field
- **WHEN** the user taps inside that field
- **THEN** the keyboard stays open

### Requirement: Queueing in the add-movement picker

The add-movement picker SHALL let a user queue a typed movement name or a
library movement with the selected set end and target. ADD MOVEMENT SHALL queue
the typed name without saving it. Tapping a library row SHALL queue that
movement. The picker SHALL stay open while movements are queued.

#### Scenario: Queueing a typed movement

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** the user types Cable Fly and taps ADD MOVEMENT
- **THEN** Cable Fly appears in the pending list with MANUAL, no library movement is created yet, and the picker stays open

### Requirement: DONE commits the add-movement queue

DONE SHALL create or reuse the typed library movements, append every queued
movement to the block in the displayed order, flush the plan, and close the
picker. CANCEL SHALL close without changing the block or the library. A created
movement SHALL carry no watch profile.

#### Scenario: Creating a movement and appending it

- **GIVEN** the picker has pending Cable Fly with MANUAL and Bench Press with REPS 10, and the library has Bench Press
- **WHEN** the user taps DONE
- **THEN** the library gains Cable Fly with no profile, the block appends Cable Fly then Bench Press in that order, the plan is flushed, and the picker closes

#### Scenario: Cancel discards the pending movements

- **GIVEN** a pending Cable Fly that does not exist in the library
- **WHEN** the user taps CANCEL
- **THEN** the library still has no Cable Fly, the block is unchanged, and the picker closes

#### Scenario: A new movement has no profile

- **GIVEN** a block movement created from a typed name with REPS selected
- **WHEN** the block movement editor is shown
- **THEN** it reports that the movement has no profile and the watch cannot count it

### Requirement: Typed movement names are validated

A typed movement name SHALL be trimmed and capped at 18 characters. The
confirmation control SHALL stay disabled while the trimmed name is empty.

#### Scenario: An empty name cannot be confirmed

- **GIVEN** the new movement name is empty or only spaces
- **WHEN** the user looks at the confirmation control
- **THEN** it is disabled and no library movement is created

#### Scenario: The name follows the plan name rules

- **WHEN** the user types a name longer than 18 characters with surrounding spaces
- **THEN** the created name is trimmed and keeps only its first 18 characters

### Requirement: A matching library movement is reused

A typed name that matches an existing library movement, ignoring case and
surrounding whitespace, SHALL reuse that movement instead of creating a
duplicate.

#### Scenario: Reusing an existing name

- **GIVEN** the library already contains Chest
- **WHEN** the user types chest and confirms
- **THEN** no second Chest is created and the block appends the existing movement

### Requirement: Set-end choices start with MANUAL

The add-movement picker SHALL list MANUAL, TIME, REPS in that order and SHALL
start with MANUAL selected. The block movement editor SHALL list the same order.

#### Scenario: The picker opens on MANUAL

- **GIVEN** the add-movement picker is opened
- **WHEN** the set-end control is shown
- **THEN** MANUAL is selected and the order is MANUAL, TIME, REPS

#### Scenario: The movement editor uses the same order

- **GIVEN** a block movement in the movement editor
- **WHEN** the set-end control is shown
- **THEN** the order is MANUAL, TIME, REPS with the movement's stored condition selected

### Requirement: The no-profile warning follows the set end

The add-movement page SHALL show the warning that a new movement cannot be
counted without a profile only while REPS is selected. With MANUAL or TIME
selected it SHALL show no profile warning. The existing PROFILE or NO PROFILE
tag on a library movement row SHALL remain.

#### Scenario: REPS shows the warning

- **GIVEN** the add-movement picker with REPS selected
- **WHEN** a new movement name is typed
- **THEN** the page warns that the watch cannot count the movement until it is recorded

#### Scenario: MANUAL and TIME hide the warning

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** a new movement name is typed
- **THEN** the page shows the manual tap-to-finish copy and no profile warning
- **AND** selecting TIME instead also hides the profile warning

### Requirement: Dragged plan rows show a lifted card

While a block or movement row is dragged by its grip, the app SHALL float a
card showing the whole row under the pointer, dim the row's home slot, and
outline the row currently under the drag. At most one row SHALL be shown as the
source and one as the drop target. The treatment SHALL clear when the row is
dropped or the drag is cancelled. No floating card SHALL appear while editing
is locked.

#### Scenario: Dragging a block row floats it

- **GIVEN** a session with several blocks
- **WHEN** the user drags a block by its grip
- **THEN** a card with that block's number, name, and meta floats under the pointer, its home slot is dimmed, and the row under the pointer is outlined

#### Scenario: Dragging a movement row floats it

- **GIVEN** a block with several movements
- **WHEN** the user drags a movement by its grip
- **THEN** a card with that movement's number, name, and condition floats under the pointer and the movement's home slot is dimmed

#### Scenario: Dropping clears the drag treatment

- **WHEN** the user drops a dragged row onto another row
- **THEN** the order changes, the floating card disappears, and both rows return to their normal styling

#### Scenario: Cancelling clears the drag treatment

- **WHEN** the user releases a dragged row outside any row or cancels the drag
- **THEN** the order is unchanged, the floating card disappears, and the dimmed and outlined rows return to normal

#### Scenario: Locked rows do not float

- **GIVEN** a running rest
- **WHEN** the user presses a block or movement grip
- **THEN** no drag starts and no floating card appears
