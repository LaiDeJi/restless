# Proposal

## Why

The movement-change rest label reads `NEXT TRICEPS`: the fixed word `NEXT` runs straight into the variable movement name, so the two read as one run of words. The app's copy already separates segments with a middle dot (`2 BLOCKS · 12 SETS · 4:00 TOTAL REST`, the position strip's `UP NEXT · <movement> · ROUND 2 OF 4`, alert copy `AFTER CURL · NEXT PUSHDOWN`), so the one label without a separator reads as a mistake rather than a style.

## What Changes

- Change the movement-switch rest label from `NEXT <next movement>` to `NEXT · <next movement>` (e.g. `NEXT · TRICEPS`) on the timer, Dynamic Island and Lock Screen. All three come from the one shared copy function.
- Apply the same dot to the block-transition rest label, `NEXT <next block>` → `NEXT · <next block>`, so the two transition cases stay consistent. (Assumption — the trigger names the movement-change label, but leaving block transitions without the dot would give the same kind of rest two different copy styles; flag at review if block transitions should be left alone.)
- Keep `AFTER SET n` and `AFTER ROUND n` unchanged; the dot belongs to the `NEXT` label only.
- Keep the nil-name fallback coherent: `NEXT MOVEMENT` becomes `NEXT · MOVEMENT`.
- Update the rest-copy lines in `.agents/skills/restless-rest-timer/SKILL.md`. They still carry the pre-`simplify-movement-rest-label` phrasing (`AFTER BICEPS · NEXT TRICEPS`); this change takes them straight to the final dotted copy, fixing that drift.
- Update the movement-switch checkpoint in `.argent/e2e/movement-major-timer-walk.yaml` (`AFTER BICEPS · NEXT TRICEPS`), which is stale against the implemented `simplify-movement-rest-label` change, to `NEXT · TRICEPS`.
- Update the prototype (the source of truth for copy) first, then the skill, then the shared implementation and tests.

This change builds on the implemented but unarchived `simplify-movement-rest-label` change; its delta specs rewrite the same requirements on top of that change's pending deltas.

Out of scope: completion-alert copy (`AFTER CURL · NEXT PUSHDOWN · …`, a separate decided surface that already dots its segments), the watch remote (it names the next movement through its own payload), the position strip's `UP NEXT` segment, and the ready screen's `NEXT` hero text on a zero set rest.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `rest-timer`: requirement `Rest copy names what finished` — a movement switch SHALL read `NEXT · <next movement>` and a block transition `NEXT · <next block>`, instead of the undotted `NEXT <name>`.
- `live-activity`: requirements `Rest copy names the transition` and `Lock Screen state row copy` — the island and Lock Screen SHALL show the same dotted transition label, which they draw from the shared copy function.

## Impact

- Prototype: `prototype-workout-timer.html` — `restLabelFor()` movement and block branches.
- Skill copy: `.agents/skills/restless-rest-timer/SKILL.md` — rest-label and island/Lock Screen rest-context lines (not its completion-alert lines).
- Shared copy: `Shared/Theme.swift` — `restContext(movementName:)` movement and block cases and the nil-name fallback; `RestlessWidget/RestlessLiveActivity.swift` doc comment.
- Tests: `RestlessTests/SessionTests.swift`, `RestlessTests/LiveActivityTests.swift` — expected transition copy.
- E2E: `.argent/e2e/movement-major-timer-walk.yaml` — the movement-switch rest-context checkpoint.
- Specs: `openspec/specs/rest-timer/spec.md`, `openspec/specs/live-activity/spec.md` (delta specs in this change).
