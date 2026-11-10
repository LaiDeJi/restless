# Spec Delta

## MODIFIED Requirements

### Requirement: Foreground completion is a haptic

While Restless is the active app, a countdown that reaches zero SHALL produce one phone haptic and SHALL NOT show a notification banner, play the completion sound, expand the Dynamic Island, or send an app-level watch haptic. The foreground alert plays no sound and follows the system haptics setting.

#### Scenario: A rest ends while the timer is open

- **GIVEN** Restless in the foreground with a rest running
- **WHEN** the rest reaches zero
- **THEN** the phone plays one haptic and the timer shows the next set

#### Scenario: A timed work set ends while the timer is open

- **GIVEN** Restless in the foreground with a timed work set running
- **WHEN** the work countdown reaches zero
- **THEN** the phone plays one haptic and the rest begins

#### Scenario: No watch app receives a foreground alert

- **GIVEN** a paired watch and Restless in the foreground
- **WHEN** a countdown reaches zero
- **THEN** the phone plays one haptic and the app sends no watch message or watch-specific haptic

## REMOVED Requirements

### Requirement: A paired watch alerts with the phone

**Reason**: The watch app and the watch link are removed. Foreground completion is a phone-only haptic; the app has no watch surface to notify.

**Migration**: Delete the app-level watch alert hook and its sent message. Do not replace it with another watch signal. A background completion still reaches a paired watch through the system's mirroring of the local notification, which the app does not duplicate.
