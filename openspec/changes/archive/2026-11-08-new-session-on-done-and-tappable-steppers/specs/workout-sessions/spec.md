# Spec Delta

## MODIFIED Requirements

### Requirement: Sessions page

SESSIONS SHALL list every saved session, mark the active one, and open a session editor when a session is selected. The page SHALL offer creating a new session as an unsaved draft; the list SHALL NOT change until the draft is committed.

#### Scenario: Listing sessions

- **GIVEN** sessions named Chest and Arms with Arms active
- **WHEN** SESSIONS opens
- **THEN** both are listed and Arms is marked active

#### Scenario: Creating a session

- **WHEN** the user taps the add control
- **THEN** a session editor opens on an unsaved draft, the list still shows the same saved sessions, and the active session is unchanged

## ADDED Requirements

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
