# Spec Delta

## Purpose

Counts reps of the armed movement on the watch and ends the set when the target is reached, with the phone as the source of truth and a manual fallback.

## ADDED Requirements

### Requirement: The phone arms a counting set

The phone SHALL arm a set only when the session is ready and the current movement's end condition is reps. The arm message SHALL carry a unique token, the movement profile, and the target.

#### Scenario: Arming a curl set

- **GIVEN** a ready set with end condition reps and target 10
- **WHEN** the set is armed
- **THEN** the watch receives the profile, the target 10, and the token

#### Scenario: A timed set is not armed

- **GIVEN** a ready set with end condition time
- **WHEN** the session becomes ready
- **THEN** no arm message is sent

### Requirement: The watch reports rep progress

The watch SHALL send each counted rep with the armed token. The phone SHALL ignore progress whose token does not match the armed set.

#### Scenario: Progress arrives

- **GIVEN** an armed set with target 10
- **WHEN** the watch counts the seventh rep
- **THEN** the phone shows 7 of 10

#### Scenario: Stale progress

- **GIVEN** a new set armed with token B
- **WHEN** a progress message with token A arrives
- **THEN** the phone ignores it

### Requirement: The target ends the set

When the count reaches the target, the watch SHALL send a completion event. The phone SHALL apply the same set-done transition as the button and the island link. A duplicate completion SHALL NOT consume a second set.

#### Scenario: Target reached

- **GIVEN** an armed set with target 10 and 9 counted reps
- **WHEN** the tenth rep is counted
- **THEN** the set is done and its rest starts

#### Scenario: Duplicate completion

- **GIVEN** a rest has started from a target completion
- **WHEN** the same completion arrives again
- **THEN** no second set is consumed

### Requirement: The set is disarmed

The phone SHALL disarm on rest start, pause, skip, restart, plan change, and set completion. The watch SHALL stop counting when disarmed.

#### Scenario: Rest disarms

- **GIVEN** an armed set that has just completed
- **WHEN** the rest starts
- **THEN** the watch stops counting and the arm token is cleared

### Requirement: Connection state and manual fallback

The timer SHALL show whether the watch is armed or unavailable. SET DONE SHALL remain available for every set, including a counting set.

#### Scenario: Watch unavailable

- **GIVEN** a counting set is ready
- **WHEN** the watch is not reachable
- **THEN** the timer shows the watch as unavailable and SET DONE still works

#### Scenario: Watch armed

- **GIVEN** a counting set is armed
- **WHEN** the timer is ready
- **THEN** it shows the watch as armed and the target

### Requirement: Counting survives the wrist going down

Counting SHALL run in an `HKWorkoutSession` so motion continues while the watch screen is off and the wrist is down. Only the watch arm SHALL be counted. If workout authorization is denied, counting SHALL fall back to the foreground.

#### Scenario: Screen off

- **GIVEN** an armed set with a running workout session
- **WHEN** the watch screen turns off
- **THEN** motion updates continue and reps are counted

#### Scenario: Authorization denied

- **GIVEN** an armed set and no workout authorization
- **WHEN** the watch app leaves the foreground
- **THEN** motion stops and no reps are counted until the app returns

#### Scenario: Other arm

- **GIVEN** an armed set
- **WHEN** the user moves the arm without the watch
- **THEN** the count does not change

### Requirement: No rest without a completion

The phone SHALL NOT start a rest for a reps set unless a target completion or a manual set done arrives.

#### Scenario: Target missed

- **GIVEN** an armed set with target 10
- **WHEN** the user stops at 7 reps
- **THEN** no rest starts until the user taps SET DONE
