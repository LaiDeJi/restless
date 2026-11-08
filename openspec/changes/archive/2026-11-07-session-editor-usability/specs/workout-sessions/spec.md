# Spec Delta

## ADDED Requirements

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

### Requirement: Movement creation in the add-movement picker

The add-movement picker SHALL let a user type a new movement name and add it
with the selected set end and target in one step. Confirming SHALL save the
movement to the library, append a block movement that uses it, and close the
picker. A created movement SHALL carry no watch profile.

#### Scenario: Creating a movement and appending it

- **GIVEN** the add-movement picker with TIME selected and a 45 second target
- **WHEN** the user types Cable Fly and confirms
- **THEN** the library gains Cable Fly with no profile, the block appends Cable Fly with TIME 0:45, and the picker closes

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
