# Proposal

## Why

Restless times rests but cannot count reps. Before this change, the watch lab counted a dumbbell curl and nothing else, and it was disconnected from the timer, so every set was a manual tap. That could not express how people actually train: straight sets, supersets, circuits, timed holds, and sets with no target at all. Recording a movement once on the watch and managing it on the phone removes the per-exercise code and makes automatic counting a property of the user's own library.

## What Changes

- **Movement library.** The watch records a 15-second window of a movement; the phone derives a profile, names it, and can edit or delete it. A movement is reused across sessions.
- **Session blocks.** A session becomes an ordered list of blocks. A block is either **straight** (all sets of one movement, then the next) or **circuit** (one set of each movement, repeated for rounds). A two-movement circuit is labelled **SUPERSET**; three or more is **CIRCUIT**. A block may hold any recorded movements.
- **Set end conditions.** Every set ends on one of three conditions: a rep target, a duration, or a manual tap. The condition belongs to the movement's use in the session; the library has no default.
- **Timed sets.** A duration set runs a work countdown in a new `performing` phase, then starts the same rest as any other set.
- **Watch counting.** The phone arms the set with a movement profile and target; the watch counts reps and reports progress; reaching the target applies the same set-done transition as the button and the island link. The timer shows whether the watch is armed.
- **Copy and model rename.** `PART` becomes `BLOCK`; the prototype is updated first, then the skill and code.
- **BREAKING** — the persisted plan changes from parts to blocks with movements. Existing plans migrate to one straight block with one manual movement, preserving name, rounds, sets and rests.
- **BREAKING** — Live Activity attributes carry blocks and movements instead of parts.

## Capabilities

### New Capabilities

- `movement-library`: recording, naming, muscle-group filing, profile derivation, editing and deletion of reusable movements.
- `watch-rep-counting`: arming a set from the phone, counting on the watch, rep progress, target completion, connection state and fallback.

### Modified Capabilities

- `workout-sessions`: parts become blocks of movements; straight/circuit arrangement; per-movement targets and end conditions; muscle-group copy.
- `rest-timer`: set end conditions, the `performing` phase for timed sets, and rest and position rules across blocks.
- `live-activity`: block and movement content, timed set countdown, and watch-armed state.

## Impact

- `Shared/`: `WorkoutPreset`/`WorkoutPart`, `SessionSnapshot`, `SessionTransitions`, activity attributes, store.
- `Restless/`: session engine, draft store, SwiftData record and migration, timer/sessions/part editor screens, watch receiver.
- `RestlessWidget/`: island and Lock Screen content.
- `RestlessWatch/`: motion recorder, rep detector, profile capture, haptics, two-way transfer.
- `prototype-workout-timer.html`, `.agents/skills/restless-rest-timer/SKILL.md`, `RestlessTests/`.
- WatchConnectivity becomes two-way; the watch runs an `HKWorkoutSession` so counting continues with the wrist down. No App Group.
