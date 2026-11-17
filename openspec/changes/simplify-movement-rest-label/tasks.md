# Tasks

## 1. Prototype copy (source of truth)

- [x] 1.1 Change the movement and block branches of `restLabelFor()` in `prototype-workout-timer.html` so a movement switch reads `NEXT <next movement>` and a block transition reads `NEXT <next block>`; keep the set and round branches unchanged. Verify by reading the edited function.
- [x] 1.2 Add or adapt a prototype driver (run with `python3 tools/prototype-check.py <driver>`) that reaches a movement-switch rest and asserts the rest label reads `NEXT TRICEPS` with no `AFTER` text. Verify the DOM dump shows the new label.

## 2. Shared copy and its tests

- [x] 2.1 Change the `.movement` and `.block` cases of `restContext(movementName:)` in `Shared/Theme.swift` to return `NEXT <next>` and `NEXT <next block>`, with the nil-name movement fallback becoming `NEXT MOVEMENT`; leave the `.set` and `.round` cases and the missing-index guards unchanged. Verify by reading the edited function.
- [x] 2.2 Update the movement-switch, block-transition and nil-fallback expectations in `RestlessTests/SessionTests.swift` (`AFTER CURL · NEXT PUSHDOWN` → `NEXT PUSHDOWN`, `AFTER BICEPS · NEXT TRICEPS` → `NEXT TRICEPS`, `AFTER ARMS · NEXT MOVEMENT` → `NEXT MOVEMENT`). Verify with a targeted run of those tests.
- [x] 2.3 Update the expectation in `RestlessTests/LiveActivityTests.swift` (`AFTER BICEPS · NEXT TRICEPS` → `NEXT TRICEPS`) and confirm no completion-alert expectation in `CompletionAlertCopyTests.swift` or `CompletionAlertCenterTests.swift` was changed. Verify with a targeted test run.

## 3. Integration verification

- [x] 3.1 Confirm the phone timer, Dynamic Island and Lock Screen all draw their rest context from the shared function with no separate copy literals; verify by building and checking a movement-change rest on the `iPhone 18 Pro` simulator with `xcodebuild ... test` (all suites pass).
- [x] 3.2 Run `swiftlint lint --quiet --reporter summary` from the repo root and `openspec validate simplify-movement-rest-label --strict`; verify both report no errors.
