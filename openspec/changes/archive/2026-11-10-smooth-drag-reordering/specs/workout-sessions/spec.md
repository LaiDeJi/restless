# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Dragged plan rows show a lifted card

While a block, movement, or session row is dragged by its grip, the app SHALL
float a card showing the whole row under the pointer from the start of the lift,
leave the row's home slot as an empty gap without drawing a second card, and
outline the row currently under the drag. The card SHALL be the size of the row
card it lifts, SHALL start at that card's position, and SHALL keep the grabbed
point under the pointer for the whole gesture without trailing it or being
clamped to the window edge. At most one row SHALL be shown as the source and one
as the drop target. The treatment SHALL clear when the row is dropped or the
drag is cancelled. No floating card SHALL appear while editing is locked.

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

## ADDED Requirements

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
