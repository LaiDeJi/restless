# Tasks

## 1. Behaviour reference

- [x] 1.1 Update `prototype-workout-timer.html` to the block shape (`rounds`, `setsPerRound`, no kind or count), remove the arrangement control and STRAIGHT/SUPERSET/CIRCUIT copy, update the block sheet, block meta, timer position, map, and demo data. Verify by opening the prototype and walking a 4 × 4 block, a 2 × 2 superset, and a 3-set block; `rg` finds no arrangement control or label.
- [x] 1.2 Update `.agents/skills/restless-rest-timer/SKILL.md` with the model, order and rest rules, formulas, worked examples, copy, and test list. Verify the examples against the prototype: 4 × 4 = 16 sets and 1080 seconds of rest at 60/120; 2 × 2 superset = 4 sets and 180 seconds at 30/120; 3 sets = 3 sets and 120 seconds at 60/0.
- [x] 1.3 Update `AGENTS.md` rule 7 to "rounds and sets per round are unbounded (minimum 1)" and check the persistence rule still describes the legacy columns and split. Verify by reading the rules against the skill.

## 2. Core model and math

- [x] 2.1 Replace `kind` and `count` with `rounds` and `setsPerRound` across `Shared/`, `Restless/`, `RestlessWidget/`, and `RestlessTests/`: model fields, Codable keys, constructors, editor fields (ROUNDS and SETS PER ROUND), block meta, movement subtitle, timer position stubs, map inputs, widget count, and test fixtures. Remove `BlockKind`, `arrangementLabel`, `BlockKindPicker`, `WorkoutPosition.blockKind`, `isCircuit`, `currentPart`, and the writable `parts` bridge. Verify `xcodebuild build` succeeds.
- [x] 2.2 Implement the new `position(at:)`, `rest(after:)`, `totalSets`, and `totalRest` formulas, including the seed (`rounds 1`, `setsPerRound 9`). Verify the updated `SessionTests` and `RestPlanTests` pass for 4 × 4, 2 × 2, 1 × N, N × 1, and block boundaries.
- [x] 2.3 Add one shared round/set copy helper and update `SessionSnapshot.restContext` for movement switches and block transitions. Verify copy tests for R > 1/S > 1, R > 1/S = 1, R = 1/S > 1, R = 1/S = 1, movement switch, round rest, and block transition.
- [x] 2.4 Add model tests for 4 × 4 (16 sets, 1080 seconds at 60/120), 2 × 2 (4 sets, 180 seconds at 30/120), zero set rest, large safe totals, and position clamps. Verify the full shared test suite passes.

## 3. Persistence and migration

- [x] 3.1 Add the shared `StoredBlock` decoder and migration helper: new keys first, legacy straight and circuit, straight multi-movement split, adjacent duplicate collapse, and legacy part. Verify fixture tests for each mapping.
- [x] 3.2 Update `PresetRecord.blocks`, `apply`, and `legacyShape` for the new shape and legacy columns; remove the `parts` projection. Verify round-trip, legacy-column, `partsData`, duplicate-collapse, and active-id tests.
- [x] 3.3 Move `SessionStore` to `restless.session.v4`, discard v3, and keep the legacy key cleanup. Verify a v3 snapshot is ignored and the gate opens, and a v4 snapshot keeps its phase.
- [x] 3.4 Update the Live Activity attributes and coordinator for the new preset shape; end stale activities on launch. Verify the attributes/snapshot round-trip test and the widget build.
- [x] 3.5 Verify migration totals: the parts example (3 × 3 at 60/120 then 2 × 4 at 45/90) is 17 sets and 1080 seconds; a straight multi-movement split keeps its block-transition rest; four duplicate circuit rows become one movement with sets per round 4 and the same total rest.

## 4. Editors and numeric copy

- [x] 4.1 Finish `BlockEditorScreen`: no arrangement section, ROUNDS and SETS PER ROUND steppers, numeric summary, movement list. Verify building a 4 × 4 block in the simulator shows 16 sets and the correct rests.
- [x] 4.2 Update `SessionEditorScreen`: numeric block meta, added blocks inherit rests but copy no movements, the picker creates the first movement, and adding a second movement to a one-round block raises rounds to 2. Verify those three flows in the simulator.
- [x] 4.3 Update `MovementPickerSheet` and `BlockMovementEditorScreen` for the block-creation path and the rounds/sets-per-round subtitle. Verify adding a block never clones the previous movement and the movement editor shows no arrangement.
- [x] 4.4 Check live copy for STRAIGHT, SUPERSET, CIRCUIT, and "part"; `rg` the app sources, the widget, the prototype, and the skill, allowing only historical text in OpenSpec change files.

## 5. Timer, map, widget, and watch

- [x] 5.1 Update `TimerScreen` position copy and remove the arrangement segment; hide the round or set segment when its count is 1. Verify the four copy states in the simulator and the timer build.
- [x] 5.2 Update `SetMap` to rounds × (movements × setsPerRound), with movement gaps, the 12/12/72 limits, and the bar fallback. Verify 4 × 4, 2 × 2, and a large block.
- [x] 5.3 Update `RestlessWidget` position copy for rounds and sets, and confirm `restCopy` names movement switches and block transitions. Verify the widget build and the island states.
- [x] 5.4 Build the watch scheme to confirm the shared model, preset, and snapshot compile without a watch UI change.

## 6. Integration

- [x] 6.1 Run the full `xcodebuild test` suite on the iPhone simulator and fix failures.
- [x] 6.2 Run `swiftlint` and fix new warnings introduced by the change.
- [x] 6.3 Walk the end-to-end flow on the simulator: build the 4 × 4 block, start, complete a set and a round rest, build a 2 × 2 superset, check the map and island, and restart. Verify the expected copy and totals at each step.
- [x] 6.4 Run `rg` for `STRAIGHT|SUPERSET|CIRCUIT` in `Shared`, `Restless`, `RestlessWidget`, `RestlessWatch`, `prototype-workout-timer.html`, and `.agents/skills`; only historical change and spec text may match.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived specs describe blocks with rounds and sets per round, not parts.
