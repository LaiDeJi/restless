# Spec Delta

## MODIFIED Requirements

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

### Requirement: Typed movement names are validated

A typed movement name SHALL be trimmed and capped at 40 characters. The confirmation control SHALL stay disabled while the trimmed name is empty.

#### Scenario: An empty name cannot be confirmed

- **GIVEN** the new movement name is empty or only spaces
- **WHEN** the user looks at the confirmation control
- **THEN** it is disabled and no library movement is created

#### Scenario: The name follows the plan name rules

- **WHEN** the user types a name longer than 40 characters with surrounding spaces
- **THEN** the created name is trimmed and keeps only its first 40 characters

## ADDED Requirements

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
