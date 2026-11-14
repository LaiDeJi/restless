# Watch Remote Specification

## Purpose

The Apple Watch as a control surface for the session running on the phone: what the wrist shows, which actions it may send, how a tap reaches the phone, and what it must never do on its own.

## Requirements

### Requirement: The watch is a remote, never an authority

The watch app SHALL send one session action per tap and SHALL NOT apply a transition, change a completed-set count, run a countdown, or advance a phase on its own. Every action it sends SHALL be applied by the phone through the same transition used by the phone's button, the island link and the URL handler.

#### Scenario: A tap reaches the phone

- **GIVEN** a running rest and the watch showing SKIP REST
- **WHEN** the rest is skipped on the wrist
- **THEN** the phone applies the skip once and the next set is ready on both devices

#### Scenario: The phone cannot be reached

- **GIVEN** the phone is out of range or the app cannot be launched
- **WHEN** the user taps a watch button
- **THEN** the watch shows that the action did not reach the phone, changes nothing on its own screen, and does not queue the action for later

#### Scenario: A double tap

- **GIVEN** a running set
- **WHEN** SET DONE is tapped twice before the session advances
- **THEN** the phone counts one set, and at a block boundary the second tap consumes no further set

### Requirement: The wrist shows no time

The watch SHALL NOT show a countdown, a remaining time, or any value that changes as time passes. A remaining time that does not tick MAY be shown while a rest is paused, because the phase itself has stopped.

#### Scenario: The wrist drops mid-rest

- **GIVEN** a running rest and the watch app open
- **WHEN** the user lowers their wrist and raises it later
- **THEN** no displayed value is stale, and the screen differs only by what the phone published in between

#### Scenario: A paused rest

- **GIVEN** a rest paused with 12 seconds left
- **WHEN** the wrist app is opened two minutes later
- **THEN** it still reads 12 seconds, and that number is not described as remaining time on a running clock

### Requirement: The wrist shows where the session is

The watch SHALL show, for a running session, the phase label, the current movement's name, the position within the block as round and set, and a count of completed sets out of the session total. The completed-set count SHALL be shown as a segmented bar rather than as a clock.

#### Scenario: Resting between sets

- **GIVEN** round 2 of 3, set 2 of 4, with 5 of 12 sets completed
- **WHEN** a set rest runs
- **THEN** the wrist reads SET REST, the movement name, ROUND 2 OF 3 · SET 2 OF 4, and five filled segments of twelve

#### Scenario: A finished session

- **GIVEN** the last set completed
- **WHEN** the done phase is shown
- **THEN** the wrist reads SESSION COMPLETE, a full bar, and the session's block and movement counts

#### Scenario: A movement switch

- **GIVEN** a rest that ends one movement and begins another
- **WHEN** the rest is shown on the wrist
- **THEN** the movement named is the one the rest leads into

### Requirement: The buttons are the phase's own actions

The watch SHALL offer the phase's primary action with the same title the phone uses, and during a rest SHALL also offer skip. It SHALL NOT offer an action the phase does not accept.

#### Scenario: Resting

- **GIVEN** a running rest
- **WHEN** the wrist screen is shown
- **THEN** the labelled button pauses the rest and the secondary control skips it

#### Scenario: Paused

- **GIVEN** a paused rest
- **WHEN** the wrist screen is shown
- **THEN** the only control resumes, and no skip is offered while the phase is paused

#### Scenario: Ready before the first set

- **GIVEN** a session that has not been started and a plan published by the phone
- **WHEN** the wrist screen is shown
- **THEN** START SESSION starts the session, and no SET DONE is offered before it starts

### Requirement: A tap carries the time it was tapped

An action sent from the watch SHALL carry the instant of the tap. The phone SHALL apply the transition at that instant rather than at the moment the message arrives, so delivery delay does not move a deadline.

#### Scenario: A delayed skip

- **GIVEN** a rest skipped on the wrist at 10:00:00
- **WHEN** the phone receives the action at 10:00:03
- **THEN** the phone applies the skip as if it happened at 10:00:00 and starts nothing from the later timestamp

#### Scenario: A delayed set done

- **GIVEN** SET DONE tapped at 10:00:00 with a 90 second rest
- **WHEN** the phone receives the action four seconds later
- **THEN** the rest deadline is 90 seconds after 10:00:00, not after its arrival

### Requirement: The watch is fed, not synchronised

The phone SHALL publish the running snapshot and the active plan to the watch, and the watch SHALL render the last published values. The watch MAY reconcile a published deadline to decide what to display after a suspension, but the result SHALL NOT be sent back as state and SHALL NOT be treated as a completed set.

#### Scenario: The deadline passed while the wrist was down

- **GIVEN** a rest whose deadline passed while the watch app was suspended
- **WHEN** the wrist app is raised before a new snapshot arrives
- **THEN** it shows the phase the deadline implies, and the phone's state is unchanged by that display

#### Scenario: No plan has ever been published

- **GIVEN** a watch app that has received nothing from the phone
- **WHEN** the app opens
- **THEN** it asks the user to open Restless on the phone and offers no control

#### Scenario: The phone is uninstalled or the session cleared

- **GIVEN** a published running session
- **WHEN** the phone's session is cleared or the app is removed
- **THEN** the next published value leaves the wrist without a session to control

### Requirement: The watch never alerts

The watch app SHALL NOT play a haptic, a sound or a notification of its own when a countdown reaches zero, and SHALL NOT request notification permission. The completion alert remains the phone's haptic in the foreground or the one mirrored local notification in the background.

#### Scenario: A countdown ends while the wrist app is open

- **GIVEN** the watch app open on a running rest
- **WHEN** the rest reaches zero
- **THEN** the watch app adds no haptic, sound or notification of its own

### Requirement: Tapping the wrist notification opens the remote

Tapping the rest-end notification on the watch SHALL open the watch app on the running session and SHALL NOT start, pause, complete or skip anything, either on the watch or on the phone.

#### Scenario: Opening from the notification

- **GIVEN** a delivered rest-end notification on the watch
- **WHEN** the user taps it
- **THEN** the watch app opens on the current phase with its buttons, and the phone's session is unchanged by the tap
