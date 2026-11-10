# Proposal

## Why

Movement recording is the most complex, least reliable part of Restless. It needs a separate watch app, motion and HealthKit permissions, background sensor capture, calibration thresholds, a profile data model, and a second path for completing a set. Every session already works with a tap or a phone countdown, so the recording and watch-counting features no longer earn that surface area.

## What Changes

- **BREAKING** Remove the watch app, the watch link, and the watch rep-counting path.
- **BREAKING** Remove the `REPS` end condition. A set ends on `MANUAL` (SET DONE) or `TIME` (a phone countdown).
- Remove the phone recording sheet, re-record action, trace view model, watch recording service, and WatchConnectivity transport.
- Remove `MovementProfile`, profile derivation, the forearm rep counter, `WatchMessage`, and the curl lab with its CSV export, live monitor, and tools.
- Keep the movement library as a name-only library. Movements are still created by typing a name in the add-movement picker and can be renamed or deleted from `MOVEMENTS`.
- Existing saved sessions keep their blocks, rounds, sets, rests, and movement names. Stored `REPS` movements become `MANUAL` with their targets dropped, and stored profiles are ignored.
- Remove the timer's watch strip and its layout role; the countdown ring stays fixed with the set map and actions below it.
- Keep the phone completion haptic and the background local notification. Remove only the app-level watch haptic; iOS still mirrors the local notification to a paired watch.
- Remove watch build configuration, watch permission copy, file-sharing keys that existed for the curl CSV, and watch references from docs, the prototype, tests, and e2e fixtures.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: end conditions become MANUAL/TIME only, the movement library loses recording and profiles, and stored REPS sets migrate to MANUAL.
- `rest-timer`: the timer no longer arms a watch or draws a watch strip, and the start gate no longer reports watch state.
- `countdown-alerts`: the app no longer sends a paired-watch haptic; foreground phone haptics and background local notifications remain.

## Impact

- `RestlessWatch/` is deleted; `project.yml`, `.swiftlint.yml`, and the generated Xcode project lose the watch target, scheme, deployment target, permissions, and embed dependency.
- Shared model loses `MovementProfile`, `MovementAxis`, `MovementProfileDerivation`, `ProfileRepCounter`, `WatchMessage`, and the `reps` end condition.
- Phone app loses the recording UI and service, watch transport, watch link, watch strip and arming, watch alert hook, and profile display/edit paths.
- `MovementRecord` keeps its legacy profile columns as dormant storage so existing SwiftData stores open; the app no longer reads or writes them.
- The prototype, the rest-timer skill, `AGENTS.md`, the watch README, tests, and the affected e2e fixture change with the feature.
