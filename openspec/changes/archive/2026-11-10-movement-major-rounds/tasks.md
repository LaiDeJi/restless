# Tasks

## 1. Prototype first

- [x] 1.1 In `prototype-workout-timer.html`, change `posAt` to the movement-major index in design §1, keeping the last-set clamp. Verify with `python3 tools/prototype-check.py <driver.js>` on a 2 movements × 3 rounds × 2 sets block: after six completed sets the position reads Triceps, round 1, set 1.
- [x] 1.2 Change `restAfter` to the rest table in design §2: a set rest inside a round, a round rest between rounds, a round rest with transition `movement` at a switch, and a round rest at a block transition. Verify with the same driver: the rest after the sixth set reads ROUND REST and AFTER BICEPS · NEXT TRICEPS, and the rest after the first set reads SET REST and AFTER SET 1.
- [x] 1.3 Change `blockRest` to design §3 so `sessionTotals` agrees. Verify with the driver: the 2 × 3 × 2 block at 60/120 shows a block rest of 16:00, and a 4 × 4 single-movement block still shows 18:00.
- [x] 1.4 Change `mapMarkup` and `paintMap` to one row per (movement, round) in run order, a gap between movements, and the caps in design §4. Verify with the driver: the 2 × 3 × 2 block draws six rows of two dots, and a single-movement 4 × 4 block draws four rows of four dots as before.
- [x] 1.5 Remove the rounds floor: `blockMin` returns 1, and the add-block, add-movement, and staged append paths stop raising `rounds`. Verify with the driver: adding a second movement to a one-round block leaves ROUNDS at 1.

## 2. Skill

- [x] 2.1 Update `.agents/skills/restless-rest-timer/SKILL.md` to design §1–§5 and the four delta specs: the order paragraph, the `position(at:)` and `rest(after:)` pseudo-code, the rest table, the totals formula and examples, the block map bullet, the editor rules that mention the two-round floor, the movement switch copy, and the list of tests worth writing. Verify with `grep -n "inside a round\|rounds ≥ 2\|two-movement rounds rule\|raises rounds\|superset round" .agents/skills/restless-rest-timer/SKILL.md`: the only matches left are retired-word lines or the explicit statement that the floor is gone.

## 3. Shared model and snapshot

- [x] 3.1 In `Shared/WorkoutPreset.swift`, rewrite `position(in:blockIndex:indexInBlock:)` for design §1 and `rest(after:)` for design §2, keeping the clamp and the done-state position, and update the doc comments on `WorkoutPosition` and `RestTransition`. Verify in `RestlessTests/RestPlanTests.swift`: every position and rest at every boundary of the 2 × 3 × 2 block passes, and the single-movement cases are unchanged.
- [x] 3.2 In `Shared/WorkoutBlock.swift`, rewrite `totalRest(hasNextBlock:)` for design §3 with `safeProduct` and `safeSum`, and keep `totalSets`. Verify: 960 s for 2 × 3 × 2 at 60/120, 360 s for 2 × 2 × 1 at 30/120, 1080 s for 4 × 4 at 60/120, and the existing 40 × 25 overflow test still passes.
- [x] 3.3 In `Shared/SessionStore.swift`, move the key to `restless.session.v5`, add `restless.session.v4` to `legacyKeys`, and update the comment in `load()`. Verify with a new `RestlessTests` case: a stored v4 snapshot is removed on load and `load()` returns nil, so the timer opens at the start gate; a v5 snapshot round-trips with its phase.
- [x] 3.4 Confirm that `Shared/CompletionAlertCopy.swift`, `Shared/SessionSnapshot.swift`, `Shared/Theme.swift`, and `RestlessWidget/RestlessLiveActivity.swift` need no code change, because they read the shared rest. Verify in `CompletionAlertCopyTests`, `TimerPositionCopyTests`, and `LiveActivityTests`: a movement switch reads ROUND REST, ROUND REST OVER, and AFTER BICEPS · NEXT TRICEPS. Change code only if one of those tests fails.

## 4. Editing without a rounds floor

- [x] 4.1 In `Restless/Session/SessionDraftStore.swift`, remove the `rounds` raise from `appendMovements(toBlock:)`, the staged `appendMovements`, and `appendBlock`. Verify in `SessionDraftStoreTests`, `LibraryAddTests`, and `NewSessionDraftTests`: ROUNDS is unchanged on the saved, staged, and add-block paths, and a one-tap add still makes one edit and one flush.
- [x] 4.2 In `Restless/UI/BlockEditorScreen.swift`, remove `minimumRounds` so ROUNDS has a minimum of 1 for every block. Verify on the simulator: a one-round block gains a second movement and still shows ROUNDS 1, and the minus control is disabled at 1.
- [x] 4.3 Check `Restless/UI/MovementPickerSheet.swift` and `Restless/UI/BlockLibrarySection.swift` for any other write to `rounds`. Verify with `grep -n "rounds" Restless/UI/MovementPickerSheet.swift Restless/UI/BlockLibrarySection.swift`: the matches are reads only.

## 5. Block map

- [x] 5.1 In `Restless/UI/SetMap.swift`, draw one row per (movement, round) in run order with a gap between movements, take the active row from `position.movementIndex` and `position.round`, compute done and current dots from the run-order index, and apply the caps in design §4. Verify with a new test in `RestlessTests/TimerStageLayoutTests.swift`: a 2 × 3 × 2 block gives six rows of two dots with the gap, the active row matches the position, and a block over the caps falls back to the bar.
- [x] 5.2 Keep single-movement blocks visually unchanged. Take before and after screenshots of a one-movement 4 × 4 block on the simulator and keep them with the implementation notes. Verify: the row count, dot spacing, and active dot match between the two.

## 6. Integration checks

- [x] 6.1 Run `xcodegen generate`, then build and test on `iPhone 18 Pro` with the commands in AGENTS.md. Verify: both succeed and the test count rises by the new cases.
- [x] 6.2 Walk one block with Biceps and Triceps, two rounds, and two sets at 60/120 on the simulator through one Argent e2e sequence. Verify at each checkpoint in the accessibility tree: Biceps round 1 set 1, SET REST, Biceps round 1 set 2, ROUND REST, Biceps round 2 set 1, then ROUND REST with AFTER BICEPS · NEXT TRICEPS, then Triceps round 1 set 1. Restore the fixture afterwards.
- [x] 6.3 With the app backgrounded during the switch rest, check the Dynamic Island. Verify: it shows ROUND REST with the round-rest amber accent and AFTER BICEPS · NEXT TRICEPS in the expanded view.
- [x] 6.4 Verify the closing gates. Verify: `swiftlint lint --quiet --reporter summary` from the repo root reports no new violations, and `openspec validate movement-major-rounds --strict` passes.

## Workflow follow-up

- Archive `movement-major-rounds` after implementation and verification. The archive applies the four delta specs to `openspec/specs/`.
