# Spec Delta

## Purpose

Reusable exercise movements recorded on the watch and named on the phone, each carrying a counting profile the watch can apply.

## ADDED Requirements

### Requirement: Recording starts from the phone

The phone SHALL queue a movement recording; the watch SHALL start it when it becomes active. The watch SHALL capture 15 seconds of accelerometer samples in the background with `CMSensorRecorder`, so the wrist may be down, then fetch the batch, play a haptic, and send the trace. It SHALL NOT count reps while recording. It SHALL NOT count reps while recording. The phone SHALL derive the profile from the whole trace.

#### Scenario: A recording captures a window of movement

- **GIVEN** the phone has started a recording and the watch is active
- **WHEN** the 15-second window ends
- **THEN** the watch stops recording, plays a haptic, and sends the trace to the phone

#### Scenario: Watch asleep

- **GIVEN** the watch app is not active
- **WHEN** the user starts a recording
- **THEN** the request is queued and the watch starts the 15-second capture when the app is opened

### Requirement: A recording produces a profile

The phone SHALL derive a counting profile from the trace: the forearm elevation rise and fall in degrees, and the minimum period. The signal is the angle between gravity and the watch's +Y axis, so turning the watch face around the forearm does not change it. It SHALL reject a trace with fewer than three complete cycles, amplitude below the floor, or period variance above the cap.

#### Scenario: A clean recording

- **GIVEN** a trace with five complete cycles at a steady period
- **WHEN** the phone derives the profile
- **THEN** the movement is created with a profile

#### Scenario: Too few cycles

- **GIVEN** a trace with two complete cycles
- **WHEN** the phone validates it
- **THEN** the recording is rejected and no movement is created

### Requirement: Movements are named and recorded

A movement SHALL have a trimmed name of at most 18 characters and a profile. It SHALL NOT carry a muscle group or a default end condition and target; those belong to the block that uses it. The phone SHALL allow add, rename, re-record, and delete.

#### Scenario: Naming a movement

- **GIVEN** a recorded trace
- **WHEN** the user names it Hammer curl and saves it
- **THEN** the movement appears in the library as Hammer curl

#### Scenario: Empty name

- **WHEN** the user clears a movement name and leaves the field
- **THEN** the name becomes Untitled movement

### Requirement: Deleting a movement in use is refused

The phone SHALL refuse to delete a movement referenced by any session block and SHALL explain why.

#### Scenario: Used movement

- **GIVEN** a movement used by the active session
- **WHEN** the user tries to delete it
- **THEN** the deletion is refused and the movement remains

#### Scenario: Unused movement

- **GIVEN** a movement used by no session
- **WHEN** the user confirms deletion
- **THEN** the movement and its profile are removed

### Requirement: The library persists

Movements and their profiles SHALL persist locally across launches.

#### Scenario: Relaunch

- **GIVEN** a library with three movements
- **WHEN** the app relaunches
- **THEN** all three movements and their profiles are present

### Requirement: Recording failure is explicit

If the watch reports no motion, fewer than three cycles, or no trace arrives within the timeout, the phone SHALL report the failure and leave the library unchanged.

#### Scenario: No trace arrives

- **GIVEN** a recording has started
- **WHEN** no trace arrives within the timeout
- **THEN** the phone reports the failure and no movement is created

#### Scenario: No motion

- **GIVEN** a recording has started
- **WHEN** the watch detects no motion for the timeout
- **THEN** the recording ends without a profile and the phone reports it
