# Tasks

## 1. Neutral seed and a fresh store

- [x] 1.1 Add `WorkoutPreset.seeded` (session "Session 1", block "Block 1", movement "Movement 1") and a fixed placeholder movement id, then delete `WorkoutPreset.chest`, `Movement.chest` and `WorkoutPreset.chestID`; `WorkoutBlock.fallback` and both seed functions use the new constant. Verify: `xcodebuild build` succeeds and a unit test asserts the seeded plan is one block, one movement, nine sets resting 480 s.
- [x] 1.2 Update every fixture that built `.chest` — the tests, the watch preview fixtures and the engine defaults — to `.seeded`, and build a local fixture in `RestPlanTests` where the old demo totals were asserted. Verify: `xcodebuild test` passes with no reference to `chest` left in `grep -ri chest --include=*.swift`.
- [x] 1.3 Create the container with a `ModelConfiguration` at `restless-v2.store` and delete `default.store`, its `-wal` and its `-shm` before the container opens, ignoring failure. Verify: install over a build that still has the old store and confirm the app opens with one seeded session and no history.

## 2. One storage shape

- [x] 2.1 Decode `[WorkoutBlock]` directly in `PresetRecord.blocks`, `WorkoutRecord.blocks` and `WorkoutPreset.init(from:)`, and delete `StoredBlock`, its `Kind`, `migratedBlocks()`, `adjacentRuns` and the `kind`/`count` keys. Verify: `PresetRecordTests` and `WorkoutHistoryTests` read back a saved plan and a history snapshot unchanged.
- [x] 2.2 Delete `WorkoutPart`, `WorkoutBlock(legacyPart:)`, `PresetRecord`'s `rounds`, `setsPerRound`, `setRest`, `roundRest`, `partsData` and the `blocks` fallback chain, plus `MovementRepository.ensureLibrary`. Verify: `xcodebuild build` succeeds and `seedIfNeeded` still activates the first saved session.
- [x] 2.3 Drop `MovementRecord`'s `group`, `axisRaw`, `rise`, `fall`, `minPeriod`, `defaultConditionRaw` and `defaultTarget`, and remove the sentence about the removed `reps` condition from `EndCondition`'s comment, keeping its total decode. Verify: `MovementRecordTests` pass and a decode of an unknown end condition still lands on MANUAL.
- [x] 2.4 Delete `StoredBlockTests` and the REPS, legacy-part, straight/circuit and duplicate-row cases in `PresetRecordTests`, `SessionEngineTests` and `WorkoutHistoryTests`. Verify: `xcodebuild test` passes and `grep -rn "reps" --include=*.swift` finds nothing.
- [x] 2.5 Collapse `SessionStore`'s four legacy keys to a single cleared key. Verify: a snapshot saved by the previous build is discarded on launch and a fresh session saves and reloads.

## 3. Fixtures, docs and inventory

- [x] 3.1 Update the five e2e step lists that expect the Chest seed (`movement-major-timer-walk`, `calendar-reorder-reset`, `calendar-cadence`, `session-start-and-draggable-lists`, `calendar-day-sheet`) to the neutral seed, giving any flow that needs several movements its own setup steps. Verify: `movement-major-timer-walk.yaml` runs to its checkpoint on `iPhone 18 Pro`.
- [x] 3.2 Correct the purposes of `rest-timer`, `workout-sessions` and `app-typography` that still describe parts, and delete the `core-motion` agent skill and the todo claiming monitoring is still wired. Verify: `openspec validate --all --strict` reports 0 failed and `grep -rn "part" openspec/specs/*/spec.md | grep -i purpose` is empty.

## 4. Integration

- [x] 4.1 Build and test the whole scheme on `iPhone 18 Pro`; confirm the timer, SESSIONS, CALENDAR projection, Live Activity and watch remote work against a freshly typed session.
- [x] 4.2 Install on the phone, confirm the old store is gone and the seed appears, retype the four sessions and thirteen movements from the project note, and check for new `Restless-*.ips` reports afterwards.

## Workflow follow-up

- Archive the change once the project's review requirements are satisfied, then verify the archived result with `openspec validate --all --strict`.
