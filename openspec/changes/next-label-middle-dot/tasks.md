# Tasks

## 1. Prototype copy (source of truth)

- [x] 1.1 Change the movement and block branches of `restLabelFor()` in `prototype-workout-timer.html` so a movement switch reads `NEXT · <next movement>` and a block transition reads `NEXT · <next block>`; keep the set and round branches and the debug strip's trailing position readout unchanged. Verify by reading the edited function.
- [x] 1.2 Update `tools/prototype-driver-rest-label.js` to assert `NEXT · TRICEPS` for the movement-switch rest and `NEXT · CHEST` for the block transition (header comment included), then run `python3 tools/prototype-check.py tools/prototype-driver-rest-label.js` and confirm the dump shows both PASS markers with no AFTER text.

## 2. Skill copy

- [x] 2.1 Update the rest-label copy lines in `.agents/skills/restless-rest-timer/SKILL.md` — the movement-switch and block-transition examples in the rest rules, the phone state table, the island expanded rest-context line, the Lock Screen state row, the worked example, and the two transition phrases in the copy vocabulary list — from the pre-simplification `AFTER <x> · NEXT <y>` to the final `NEXT · <name>`. Leave the completion-alert lines (`AFTER CURL · NEXT PUSHDOWN`, `SET REST OVER`, `WORK SET OVER`) unchanged. Verify by grepping the skill for `NEXT ·` on rest-label lines while the alert lines still read `AFTER CURL · NEXT PUSHDOWN`.

## 3. Shared copy and its tests

- [x] 3.1 Change the `.movement` and `.block` cases of `restContext(movementName:)` in `Shared/Theme.swift` to return `NEXT · <next>` and `NEXT · <next block>`, with the nil-name movement fallback becoming `NEXT · MOVEMENT`; leave the `.set` and `.round` cases and the missing-index guards unchanged. Update the `NEXT TRICEPS` example in the `restLine` doc comment in `RestlessWidget/RestlessLiveActivity.swift` to `NEXT · TRICEPS`. Verify by reading both edits.
- [x] 3.2 Update the transition expectations in `RestlessTests/SessionTests.swift` (`NEXT PUSHDOWN` → `NEXT · PUSHDOWN`, `NEXT TRICEPS` → `NEXT · TRICEPS`, `NEXT MOVEMENT` → `NEXT · MOVEMENT`). Verify with a targeted run of those tests.
- [x] 3.3 Update the expectation in `RestlessTests/LiveActivityTests.swift` (`NEXT TRICEPS` → `NEXT · TRICEPS`) and confirm no completion-alert expectation in `CompletionAlertCopyTests.swift` or `CompletionAlertCenterTests.swift` was changed. Verify with a targeted test run.
- [x] 3.4 Update the movement-switch checkpoint in `.argent/e2e/movement-major-timer-walk.yaml` (`AFTER BICEPS · NEXT TRICEPS` → `NEXT · TRICEPS`) and its header note if it names the label. Verify by grepping the file for the new text.

## 4. Integration verification

- [x] 4.1 Run the full `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test` and confirm all suites pass.
- [x] 4.2 Run `swiftlint lint --quiet --reporter summary` from the repo root and `openspec validate next-label-middle-dot --strict`; verify both report no errors.

## Workflow follow-up

- Archive the change after review; note that `simplify-movement-rest-label` is still unarchived and must archive first so the two deltas land in order.
