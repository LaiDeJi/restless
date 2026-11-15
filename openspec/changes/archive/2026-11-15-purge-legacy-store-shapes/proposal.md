# Proposal

## Why

Every shape this app has ever written still has a decoder: parts, straight and circuit blocks, the `kind`/`count` pair, legacy single-part columns, and seven dormant movement-profile columns. Movement monitoring is already gone from the live code, but its storage shape still owns those columns and three spec requirements, so the model keeps a door open for sensors that are not coming back. One accepted store reset lets all of it go at once instead of layering a fourth migration on top.

## What Changes

- **BREAKING** The SwiftData store moves to a new file. The previous store is deleted on first launch, so workout history and any running snapshot start empty. The four saved sessions and thirteen movements are retyped from the project note; the seed "Chest" movement is not recreated.
- **BREAKING** Remove the legacy decode layer: `WorkoutPart`, `WorkoutBlock(legacyPart:)`, `StoredBlock` and its `kind`/`count` reading, `PresetRecord`'s `partsData` and single-part columns, `MovementRecord`'s profile columns, `MovementRepository.ensureLibrary`, and the tests that pin each of them.
- **BREAKING** First run seeds "Session 1" containing one "Movement 1", replacing the Chest demo. `Movement.chest`, `WorkoutPreset.chest`, their fixed ids, and the watch preview fixtures built on them change with it.
- `SessionStore` keeps one key, cleared once, instead of four versioned keys.
- Keep the `restless.calendar.v1` migration: `UserDefaults` outlives the store, and dropping the migration would discard the configured rest days.
- Remove the `core-motion` agent skill, since no sensor work remains, and the stale todo that claims monitoring is still wired.
- Correct the spec purposes that still describe "parts".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: a stored plan is read only in the current block shape. The requirements for migrating stored plans, stored `REPS` sets, and collapsing duplicate circuit rows are removed with the shapes they describe, and first run seeds a neutral session instead of the Chest demo.

## Impact

- `Restless/App/RestlessApp.swift` names the store file; `Restless/Data/PresetRecord.swift` and `MovementRecord.swift` lose their legacy columns, fallbacks and seed fixture.
- `Shared/WorkoutBlock.swift`, `Shared/WorkoutPreset.swift` and `Shared/SessionStore.swift` lose the legacy types, bridge, decoder keys and key sweep.
- `RestlessTests/` loses the stored-shape, REPS and snapshot migration tests, and the fixtures that build a Chest movement.
- `openspec/specs/workout-sessions/spec.md` loses three requirements; `rest-timer` and `app-typography` purposes stop saying "part".
- The user's program lives in a project note, not in the repository; first run creates an unnamed placeholder instead.
