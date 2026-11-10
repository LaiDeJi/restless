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

### Requirement: Sessions are ordered manually

The SESSIONS list SHALL show saved sessions in a persisted manual order. Drag and drop SHALL reorder the list, a new session SHALL append at the end, and the order SHALL survive relaunch. The active session SHALL keep its ACTIVE badge on its own card and MUST NOT be pinned to the top. Reordering SHALL NOT activate, edit, or reset any session.

#### Scenario: Dragging a session to the top

- **GIVEN** sessions in the order Chest, Arms, Core
- **WHEN** the user drags Core above Chest
- **THEN** the list reads Core, Chest, Arms and the order survives relaunch

#### Scenario: The active session moves with its card

- **GIVEN** Arms is active and sits second
- **WHEN** the user drags Arms to first
- **THEN** Arms is first and still carries the ACTIVE badge, and the running timer is unchanged

#### Scenario: A new session appends

- **GIVEN** saved sessions Chest and Arms
- **WHEN** the user saves a new session Core
- **THEN** Core is listed after Arms

#### Scenario: Reordering is not editing

- **GIVEN** a session running a rest
- **WHEN** the session list is shown
- **THEN** its grip and drop actions are disabled like the other plan controls

#### Scenario: Legacy sessions keep their creation order

- **GIVEN** sessions saved before manual ordering existed
- **WHEN** the list first appears after the update
- **THEN** they are ordered by creation time until the user reorders them

#### Scenario: Drag is accessible

- **GIVEN** a session card with VoiceOver
- **WHEN** the user invokes Move up or Move down
- **THEN** the card moves one place in the persisted order

### Requirement: Editor restart confirms before resetting

The session editor's RESTART SESSION action SHALL open the same confirmation as the timer: completed sets are cleared, any rest is cancelled, and the session returns to the start gate at block 1, set 1 with no Live Activity. Cancelling SHALL leave the session, its completed sets, and any pending edit unchanged.

#### Scenario: Confirming an editor restart

- **GIVEN** the active session with four completed sets
- **WHEN** the user taps RESTART SESSION and confirms
- **THEN** the session is not started at block 1, set 1 with zero completed sets, the timer shows START SESSION, and no Live Activity remains

#### Scenario: Cancelling an editor restart

- **GIVEN** the active session with four completed sets
- **WHEN** the user taps RESTART SESSION and cancels
- **THEN** the session keeps its four completed sets and its current phase

#### Scenario: The editor restart is not shown before a set

- **GIVEN** the active session with zero completed sets
- **WHEN** the session editor is shown
- **THEN** no RESTART SESSION action is offered

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

### Requirement: Stored REPS sets become MANUAL

A stored block movement whose end condition is the removed `reps` value SHALL decode as `manual` with no target. Decoding SHALL preserve its movement id, order, block, rounds, sets, and rests, so a saved session and a saved running snapshot remain usable.

#### Scenario: A stored REPS row decodes as MANUAL

- **GIVEN** a stored block movement with `endCondition` set to `reps` and target 10
- **WHEN** the block is decoded
- **THEN** its end condition is MANUAL and its target is empty

#### Scenario: A saved session keeps all blocks

- **GIVEN** a stored session whose second block contains a REPS movement
- **WHEN** the session is opened
- **THEN** both blocks, every movement, rounds, sets, and rests remain, and the REPS movement is MANUAL

#### Scenario: A running snapshot survives

- **GIVEN** a saved running snapshot whose plan contains a REPS movement
- **WHEN** the app launches
- **THEN** the snapshot loads at the same position with the REPS movement shown as MANUAL

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

Session and block names SHALL be trimmed and limited to 40 characters. An empty session name SHALL become Untitled. An empty block name SHALL become Untitled block.

#### Scenario: Empty session name

- **WHEN** the user clears the session name and leaves the field
- **THEN** the name becomes Untitled

#### Scenario: Long block name

- **WHEN** the user types more than 40 characters into a block name
- **THEN** only the first 40 characters are kept

#### Scenario: A forty-character name is kept whole

- **WHEN** the user types exactly 40 characters into a session or block name
- **THEN** all 40 characters are kept

#### Scenario: An existing short name is unchanged

- **GIVEN** a stored session or block whose name was written under the old 18-character limit
- **WHEN** the app opens it after the update
- **THEN** the stored name is unchanged

### Requirement: Long names stay readable where space allows

Session, block, and movement names of up to 40 characters SHALL wrap to at most two lines in the sessions list, block editor, and movement lists. Compact surfaces MAY scale or truncate a long name to one line; they MUST NOT move the timer ring or grow the Lock Screen panel beyond its height budget.

#### Scenario: A long session name in the list

- **GIVEN** a session named Single-arm cable lateral raise
- **WHEN** the SESSIONS list shows it
- **THEN** the card shows the name across at most two lines without clipping the summary

#### Scenario: A long movement name in a block

- **GIVEN** a block movement named Single-arm cable lateral raise
- **WHEN** the block editor shows its row
- **THEN** the row shows the name across at most two lines

#### Scenario: A long name on the timer

- **GIVEN** a movement name at the 40-character limit
- **WHEN** the timer position strip is shown at the default text size
- **THEN** the strip stays on one line by scaling or truncating, and the ring keeps its centre

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

DONE SHALL create or reuse the typed library movements, append every queued movement to the block in the displayed order, flush the plan, and close the picker. CANCEL SHALL close without changing the block or the library.

#### Scenario: Creating a movement and appending it

- **GIVEN** the picker has pending Cable Fly with MANUAL and Bench Press with TIME 0:45, and the library has Bench Press
- **WHEN** the user taps DONE
- **THEN** the library gains Cable Fly, the block appends Cable Fly then Bench Press in that order, the plan is flushed, and the picker closes

#### Scenario: Cancel discards the pending movements

- **GIVEN** a pending Cable Fly that does not exist in the library
- **WHEN** the user taps CANCEL
- **THEN** the library still has no Cable Fly, the block is unchanged, and the picker closes

#### Scenario: A new movement has no profile

- **GIVEN** a block movement created from a typed name
- **WHEN** the block movement editor is shown
- **THEN** the movement is usable with MANUAL or TIME and no profile warning or watch prompt is shown

### Requirement: The movement library is name-only

The movement library SHALL store only a movement's name. It SHALL NOT store, derive, display, or request a motion profile, recording state, or watch count. A movement SHALL still be created by typing its name in the add-movement picker and SHALL be managed from `MOVEMENTS`.

#### Scenario: A new typed movement is name-only

- **GIVEN** the add-movement picker with MANUAL selected
- **WHEN** the user types Cable Fly and commits it
- **THEN** the library lists Cable Fly with its name and provides no profile or recording action

#### Scenario: The library has no recording controls

- **GIVEN** a library containing Chest and Curl
- **WHEN** the user opens MOVEMENTS
- **THEN** each row offers only rename and delete, and the page has no record, re-record, profile, or watch control

#### Scenario: An empty library points to the picker

- **GIVEN** a library with no movements
- **WHEN** the user opens MOVEMENTS
- **THEN** the page explains that movements are added from a block's add-movement picker and offers no recording control

### Requirement: Typed movement names are validated

A typed movement name SHALL be trimmed and capped at 40 characters. The confirmation control SHALL stay disabled while the trimmed name is empty.

#### Scenario: An empty name cannot be confirmed

- **GIVEN** the new movement name is empty or only spaces
- **WHEN** the user looks at the confirmation control
- **THEN** it is disabled and no library movement is created

#### Scenario: The name follows the plan name rules

- **WHEN** the user types a name longer than 40 characters with surrounding spaces
- **THEN** the created name is trimmed and keeps only its first 40 characters

### Requirement: Library movement names share the plan name rules

A library movement rename SHALL be trimmed and limited to 40 characters. An empty movement name SHALL become Untitled movement. Renaming a movement MUST NOT reset or alter the running session.

#### Scenario: Renaming a long movement name

- **GIVEN** a library movement named Curl
- **WHEN** the user types a 40-character name and leaves the field
- **THEN** the movement keeps all 40 characters and every block using it shows the new name

#### Scenario: Empty movement name

- **WHEN** the user clears a movement name and leaves the field
- **THEN** the name becomes Untitled movement

#### Scenario: A rename does not reset the timer

- **GIVEN** an active session with completed sets
- **WHEN** the user renames one of its movements
- **THEN** the session keeps its completed sets and current rest

### Requirement: A matching library movement is reused

A typed name that matches an existing library movement, ignoring case and
surrounding whitespace, SHALL reuse that movement instead of creating a
duplicate.

#### Scenario: Reusing an existing name

- **GIVEN** the library already contains Chest
- **WHEN** the user types chest and confirms
- **THEN** no second Chest is created and the block appends the existing movement

### Requirement: Set-end choices start with MANUAL

The add-movement picker and the block movement editor SHALL list MANUAL and TIME in that order and SHALL start with MANUAL selected. The block movement editor SHALL select the movement's stored condition. Neither page SHALL offer a REPS condition or a rep target.

#### Scenario: The picker opens on MANUAL

- **GIVEN** the add-movement picker is opened
- **WHEN** the set-end control is shown
- **THEN** MANUAL is selected and the order is MANUAL, TIME

#### Scenario: The movement editor uses the same order

- **GIVEN** a block movement in the movement editor
- **WHEN** the set-end control is shown
- **THEN** the order is MANUAL, TIME with the movement's stored condition selected

#### Scenario: No rep condition is offered

- **GIVEN** either the add-movement picker or the block movement editor
- **WHEN** the set-end control is shown
- **THEN** no REPS choice or rep target is present

### Requirement: Dragged plan rows show a lifted card

While a block, movement, or session row is dragged by its grip, the app SHALL
float a card of the row card's size under the pointer from the start of the lift,
grabbed at the touched point. The row's home slot SHALL become an empty gap and
the row under the pointer SHALL be outlined. At most one row SHALL be the source
and one the drop target, and the treatment SHALL clear on drop or cancel. No
card SHALL appear while editing is locked.

#### Scenario: Dragging a block row floats it

- **GIVEN** a session with several blocks
- **WHEN** the user drags a block by its grip
- **THEN** a card with that block's number, name, and meta floats under the
  pointer, its home slot is left as an empty gap, and the row under the pointer
  is outlined

#### Scenario: Dragging a movement row floats it

- **GIVEN** a block with several movements
- **WHEN** the user drags a movement by its grip
- **THEN** a card with that movement's number, name, and condition floats under
  the pointer and the movement's home slot is left as an empty gap

#### Scenario: The card appears as the lift begins

- **GIVEN** a grip on an unlocked row
- **WHEN** the user holds the grip until the drag lift begins
- **THEN** the floating card is visible and the source row is removed from its
  slot as the lift starts, before the pointer moves

#### Scenario: The card stays under a moving pointer

- **GIVEN** a block or movement row being dragged
- **WHEN** the user moves the pointer quickly across the list and back
- **THEN** the floating card stays under the pointer for the whole gesture,
  keeps the point it was grabbed by on the same spot of the finger, and does
  not trail behind the pointer

#### Scenario: The card is the row card's size

- **GIVEN** a drag lifted from a row whose card is narrower than its row
- **WHEN** the card appears
- **THEN** the card covers that row card exactly instead of spanning the grip
  and the trash, and it moves sideways with the finger instead of stopping at
  the window edge

#### Scenario: Dragging into the header drops at the top

- **GIVEN** a drag that has crossed one or more rows
- **WHEN** the user moves the pointer into the header above the first row and
  releases
- **THEN** the dragged row is placed at the top of the list, the order is saved
  once, and the floating card clears

#### Scenario: Dragging into the footer drops at the bottom

- **GIVEN** a drag that has crossed one or more rows
- **WHEN** the user moves the pointer below the last row and releases
- **THEN** the dragged row is placed at the bottom of the list, the order is
  saved once, and the floating card clears

#### Scenario: Dropping clears the drag treatment

- **WHEN** the user drops a dragged row onto another row
- **THEN** the order changes, the floating card disappears, and both rows return
  to their normal styling

#### Scenario: Cancelling clears the drag treatment

- **WHEN** the user releases a dragged row outside any row after crossing other
  rows, or cancels the drag
- **THEN** the order is unchanged, the floating card disappears, the empty gap
  closes, and the outlined row returns to normal

#### Scenario: Locked rows do not float

- **GIVEN** a running rest
- **WHEN** the user presses a block or movement grip
- **THEN** no drag starts and no floating card appears

### Requirement: Interactive reordering is provisional until drop

While a session, block, or movement drag is in progress, the list SHALL follow
the pointer through a provisional order held by the screen. The provisional
order SHALL be written to the session or saved record once when the drag ends.
The app MUST NOT save, reset the active session, or refresh the Live Activity
while the drag is in progress. A cancelled drag SHALL restore the order the list
had before the drag.

#### Scenario: Pausing mid-drag does not commit

- **GIVEN** the active session's editor with editing unlocked and a rest not running
- **WHEN** the user drags a block across another row and holds still
- **THEN** the list shows the crossed order, the active session keeps its phase,
  and no save or Live Activity update is made until the drag ends

#### Scenario: An edit already waiting is saved after the drag

- **GIVEN** the session editor with a name change inside the edit debounce
- **WHEN** the user starts a drag before that change is saved
- **THEN** the name change and the reordered plan are saved together when the
  drag ends, and neither is saved while the finger is down

#### Scenario: Dropping writes the order once

- **GIVEN** a block, movement, or session list with a provisional order
- **WHEN** the user drops the dragged row
- **THEN** the final order is applied once, the edit is flushed once, and the
  floating card and drop outline clear

#### Scenario: Dropping back into the empty slot commits

- **GIVEN** a drag that has crossed one or more rows
- **WHEN** the user releases over the empty slot left by the dragged row
- **THEN** the crossed order is applied and saved once, and the floating card
  clears

#### Scenario: Cancelling restores the pre-drag order

- **GIVEN** a drag that has crossed one or more rows
- **WHEN** the user releases outside a valid row or cancels the drag
- **THEN** the rows return to the order they had before the drag and no save is
  made

#### Scenario: A session-card drag does not change the active session

- **GIVEN** saved sessions in a manual order and one active session
- **WHEN** the user drags any session card across another card
- **THEN** the active session keeps its ACTIVE badge and its running timer is
  unchanged during the drag, and the dropped order is persisted once

#### Scenario: Locked rows do not create a provisional order

- **GIVEN** a running rest with editing locked
- **WHEN** the user presses a grip
- **THEN** no drag starts and no provisional order is created

### Requirement: Crossings move the rows like a native list

While a drag is in progress, a crossing that changes the provisional order SHALL
animate the rows and the empty slot into their new positions instead of
re-laying the list out in one frame. A cancelled drag SHALL return the rows to
the pre-drag order with the same motion, and a drop SHALL settle the card into
the row it lands on rather than removing it in one frame.

#### Scenario: Crossing a row glides the list

- **GIVEN** a block, movement, or session drag crossing its neighbour
- **WHEN** the drop target changes
- **THEN** the rows and the empty slot travel to their new slots over about a
  quarter second instead of jumping, and the floating card keeps following the
  pointer during the move

#### Scenario: Cancelling glides back

- **GIVEN** a drag that has crossed one or more rows
- **WHEN** the drag is cancelled
- **THEN** the rows animate back to the pre-drag order while the card returns
  to the slot it lifted from, and no save is made

#### Scenario: Dropping settles instead of flashing

- **GIVEN** a drag released over a row
- **WHEN** the drop completes
- **THEN** the floating card moves onto the row that takes its place, shrinks
  back to the row's size and fades as the row fades in, and the list keeps the
  dropped order

#### Scenario: A release without a crossing still ends the drag

- **GIVEN** a grip held until the card lifts
- **WHEN** the finger lifts without the pointer having crossed a row
- **THEN** the source row returns to its slot, the card clears, and the order is
  unchanged

#### Scenario: The card grows as it lifts

- **GIVEN** a grip on an unlocked row
- **WHEN** the lift begins
- **THEN** the card grows slightly over about a tenth of a second and shrinks
  back when it lands, so the lift reads as the row being picked up
