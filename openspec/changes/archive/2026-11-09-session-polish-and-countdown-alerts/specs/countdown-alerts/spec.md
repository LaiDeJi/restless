# Spec Delta

## Purpose

Defines how Restless notices the user when a rest or timed work countdown reaches zero, across the phone, the paired watch, the Live Activity, and background alerts.

## ADDED Requirements

### Requirement: A countdown that reaches zero raises one completion alert

A rest or timed work countdown that reaches its deadline SHALL raise exactly one completion alert. The alert SHALL NOT complete a set by itself, skip a rest, or create a second transition; the deadline reconciliation remains the only state change.

#### Scenario: A rest reaches zero

- **GIVEN** a rest with a stored deadline
- **WHEN** the deadline passes
- **THEN** the rest ends once, the next set is ready, and one completion alert is raised

#### Scenario: A timed work set reaches zero

- **GIVEN** a timed work set with a stored deadline
- **WHEN** the deadline passes
- **THEN** the set is completed once and one completion alert is raised for the rest that follows or for the finished session

#### Scenario: The alert does not consume another set

- **GIVEN** a rest that has just expired
- **WHEN** the completion alert is delivered
- **THEN** completed sets is unchanged by the alert and the timer shows the next set once

### Requirement: Paused, skipped, or replaced countdowns raise no alert

A countdown that is paused, skipped, restarted, replaced by a plan change, or ended before its deadline SHALL raise no completion alert. Resuming a paused rest SHALL arm its alert again for the resumed deadline.

#### Scenario: Skipping a rest

- **GIVEN** a running rest with 40 seconds left
- **WHEN** the user skips the rest
- **THEN** the session is ready at the next set and no completion alert is raised at the original deadline

#### Scenario: Pausing and resuming

- **GIVEN** a running rest with 30 seconds left
- **WHEN** the user pauses, waits two minutes, and resumes
- **THEN** no alert fires while paused and one alert is armed for 30 seconds after the resume

#### Scenario: Restarting the session

- **GIVEN** a running rest
- **WHEN** the user confirms a restart
- **THEN** the pending completion alert is cancelled and the ready session raises none

#### Scenario: A zero set rest

- **GIVEN** a set whose rest has zero duration
- **WHEN** the set is completed
- **THEN** the next set is ready immediately and no completion alert is scheduled

### Requirement: Foreground completion is a haptic

While Restless is the active app, a countdown that reaches zero SHALL produce one phone haptic and SHALL NOT show a notification banner, play the completion sound, or expand the Dynamic Island. The foreground alert plays no sound and follows the system haptics setting.

#### Scenario: A rest ends while the timer is open

- **GIVEN** Restless in the foreground with a rest running
- **WHEN** the rest reaches zero
- **THEN** the phone plays one haptic and the timer shows the next set

#### Scenario: A timed work set ends while the timer is open

- **GIVEN** Restless in the foreground with a timed work set running
- **WHEN** the work countdown reaches zero
- **THEN** the phone plays one haptic and the rest begins

### Requirement: Background completion is one local notification

Restless SHALL schedule one local notification for the deadline when it moves to the background during a countdown. It SHALL leave a notification whose deadline is reached in the background pending, even while the app is still executing, so the system delivers it exactly once. The system SHALL mirror it to the paired watch. Restless SHALL NOT send an alerting Live Activity update and SHALL NOT schedule a system alarm.

#### Scenario: The app still runs at the deadline

- **GIVEN** a running rest and Restless still executing in the background
- **WHEN** the rest reaches zero
- **THEN** one local notification is delivered, its pending request is not cancelled, and no alerting Live Activity update is sent

#### Scenario: The app is suspended during a long rest

- **GIVEN** a two-minute rest and another app in the foreground
- **WHEN** the rest reaches zero after Restless is suspended
- **THEN** one local notification appears and opening it returns to the TIMER tab at the next set

#### Scenario: A rest ends with the phone locked

- **GIVEN** a running rest and the phone locked
- **WHEN** the rest reaches zero after Restless is suspended
- **THEN** the local notification appears on the Lock Screen

#### Scenario: The app returns before the deadline

- **GIVEN** a running rest and the user returns to Restless with 10 seconds left
- **WHEN** the app becomes active
- **THEN** the pending notification is cancelled and the rest continues in the foreground

### Requirement: The completion alert names what finished

A completion alert SHALL state what finished and what comes next: the rest kind or work set, the finished set or round, and the next movement or session completion. The system surface decides whether that copy is split across a title and body.

#### Scenario: A set rest ends

- **GIVEN** a set rest after set 2 of a block whose next movement is Bench Press
- **WHEN** the alert is raised
- **THEN** it names the set rest and Bench Press as next, with the next round and set

#### Scenario: A timed work set ends

- **GIVEN** a timed work set that is the last set of the block and another block follows
- **WHEN** the alert is raised
- **THEN** it names the work set as finished and the next block as what follows

#### Scenario: The final set ends

- **GIVEN** the last set of the last block
- **WHEN** the completion alert is raised
- **THEN** it names the session as complete and does not promise a next set

### Requirement: A paired watch alerts with the phone

When the phone raises a foreground completion and the watch app is reachable, the watch SHALL also play one notification haptic. For a background completion, the local notification is the watch notice through the system's mirroring, and the app SHALL NOT add a second watch notification. The watch alert SHALL NOT count reps, complete a set, or change the armed set.

#### Scenario: The watch is on the wrist for a foreground rest end

- **GIVEN** a paired watch, a reachable watch app, and Restless in the foreground
- **WHEN** the rest reaches zero
- **THEN** the watch plays one alert haptic and the armed set state is unchanged

#### Scenario: A background rest end does not double-buzz

- **GIVEN** a paired watch and a rest that ends while Restless is in another app
- **WHEN** the system mirrors the local notification to the watch
- **THEN** the app sends no second watch notification or haptic

#### Scenario: The watch app is not running

- **GIVEN** a paired watch whose watch app is not running
- **WHEN** the rest reaches zero while Restless is suspended
- **THEN** the system notification still reaches the watch

### Requirement: Alert permission is requested once and denial is survivable

Restless SHALL request notification permission when the first countdown is armed. A denial SHALL NOT block the session, complete a set, or show a repeat prompt; later countdowns SHALL run without a background alert unless the user enables permission in Settings.

#### Scenario: Denying the permission

- **GIVEN** a user who denies notification permission
- **WHEN** a rest runs and reaches zero
- **THEN** the session still advances to the next set and no alert is attempted

#### Scenario: The prompt is not repeated

- **GIVEN** a denied permission
- **WHEN** later countdowns start
- **THEN** no permission prompt is shown again

### Requirement: No alert outlives its countdown

A pending completion alert SHALL be cancelled when its countdown is paused, skipped, restarted, completed early, replaced by a plan change, or found expired at launch. A relaunch or plan change MUST NOT deliver an alert from an earlier session.

#### Scenario: Launch after an expired alert

- **GIVEN** a stored snapshot whose deadline passed and a stale pending alert
- **WHEN** Restless launches
- **THEN** the stale alert is cancelled and the session reconciles without alerting for the missed deadline

#### Scenario: Changing the active plan

- **GIVEN** a running countdown with a pending alert
- **WHEN** the user activates another session or commits a plan edit
- **THEN** the pending alert is cancelled before the new session starts
