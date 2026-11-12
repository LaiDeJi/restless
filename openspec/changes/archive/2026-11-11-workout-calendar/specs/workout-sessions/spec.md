# Spec Delta

## MODIFIED Requirements

### Requirement: Bottom tab navigation

The app SHALL have three persistent bottom tabs, TIMER, SESSIONS, and CALENDAR, in that order. TIMER SHALL be the default tab. Switching tabs MUST NOT pause, reset, or lose a running rest. The timer's EDIT action SHALL open the active session in SESSIONS.

#### Scenario: Launch opens the timer

- **WHEN** the app launches
- **THEN** the TIMER tab is selected

#### Scenario: The tab order

- **WHEN** the tab bar is shown
- **THEN** the tabs read TIMER, SESSIONS, CALENDAR from left to right

#### Scenario: Switching tabs during rest

- **GIVEN** a set rest with 40 seconds remaining
- **WHEN** the user switches to SESSIONS for 10 seconds and returns to TIMER
- **THEN** approximately 30 seconds remain and the rest is still running

#### Scenario: EDIT opens the active session

- **GIVEN** the active session is Chest
- **WHEN** the user taps EDIT on the timer
- **THEN** SESSIONS opens on the Chest session editor

### Requirement: Session management

From the session editor a user SHALL be able to rename, activate, and delete a session. The last remaining session MUST NOT be deleted. Deleting a session SHALL require two taps on the delete action. Deleting a session SHALL remove it from the CALENDAR rotation and keep the history records made from it.

#### Scenario: Activating a session

- **GIVEN** Chest is active with sets completed
- **WHEN** the user activates Arms
- **THEN** Arms becomes active and the timer is not started at its first set with no completed sets

#### Scenario: Deleting a session in two steps

- **GIVEN** two saved sessions
- **WHEN** the user taps delete once and then confirms
- **THEN** the session is removed and another session becomes active

#### Scenario: Deleting a session updates the rotation

- **GIVEN** the order Chest, Arms, Legs with Arms records on past days
- **WHEN** the user deletes Arms
- **THEN** upcoming days use Chest and Legs only and the Arms records remain

#### Scenario: Refusing to delete the last session

- **GIVEN** one saved session
- **WHEN** the session editor is shown
- **THEN** no enabled delete action is offered

### Requirement: Sessions are ordered manually

The SESSIONS list SHALL show saved sessions in a persisted manual order. Drag and drop SHALL reorder the list, a new session SHALL append at the end, and the order SHALL survive relaunch. The active session SHALL keep its ACTIVE badge on its own card and MUST NOT be pinned to the top. The order SHALL define the CALENDAR rotation. Reordering SHALL NOT activate, edit, or reset any session or record, and SHALL recalculate only unstarted upcoming days.

#### Scenario: Dragging a session to the top

- **GIVEN** sessions in the order Chest, Arms, Core
- **WHEN** the user drags Core above Chest
- **THEN** the list reads Core, Chest, Arms and the order survives relaunch

#### Scenario: The active session moves with its card

- **GIVEN** Arms is active and sits second
- **WHEN** the user drags Arms to first
- **THEN** Arms is first and still carries the ACTIVE badge, and the running timer is unchanged

#### Scenario: A reorder changes only upcoming days

- **GIVEN** a Monday Chest record, a running Legs session, and Thursday as the next unstarted day
- **WHEN** the user moves Legs above Chest
- **THEN** Monday keeps its Chest record, the running Legs session is unchanged, and Thursday follows the new order

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
