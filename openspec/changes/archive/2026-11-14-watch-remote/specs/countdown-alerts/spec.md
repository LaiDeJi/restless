# Spec Delta

## MODIFIED Requirements

### Requirement: Tapping a completion alert opens Restless

Tapping a delivered rest or timed-work completion alert SHALL open the app on the device where it was tapped: on the phone, Restless in the foreground on the TIMER tab; on the watch, the watch app on the running session. Neither tap SHALL start, pause, complete or skip anything, SHALL NOT terminate the app, and SHALL NOT raise a second completion alert.

#### Scenario: The app is suspended in the background

- **GIVEN** Restless suspended with a delivered SET REST OVER alert and the next set ready
- **WHEN** the user taps the alert
- **THEN** Restless opens on the TIMER tab at the next set, the alert is cleared, and the app does not abort

#### Scenario: The app was terminated

- **GIVEN** Restless not running and a delivered alert for a rest that has since finished
- **WHEN** the user taps the alert
- **THEN** Restless cold-launches from the stored session, shows the next set on the TIMER tab, and does not abort during launch

#### Scenario: The app is already open on SESSIONS

- **GIVEN** Restless open on the SESSIONS tab with an alert delivered while it was away
- **WHEN** the user taps the alert
- **THEN** Restless switches to the TIMER tab without pausing, skipping, or completing anything

#### Scenario: The alert belongs to a timed work set

- **GIVEN** a delivered WORK SET OVER alert for the last timed set of a block
- **WHEN** the user taps the alert
- **THEN** Restless opens on the TIMER tab showing the rest that followed or the finished session, with the same completed-set count as before the tap

#### Scenario: The alert is tapped on the watch

- **GIVEN** a running rest with a watch app installed and the phone locked
- **WHEN** the user taps the rest-end alert on the watch
- **THEN** the watch app opens on the current phase with its buttons, the phone stays locked, and neither device changes the completed-set count

#### Scenario: The watch has no app installed

- **GIVEN** a running rest and a paired watch without the watch app
- **WHEN** the rest reaches zero
- **THEN** the alert appears on the watch as before and tapping it offers no watch app to open
