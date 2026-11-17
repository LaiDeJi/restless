# Proposal

## Why

During a rest between two movements, the timer label reads `AFTER BICEPS · NEXT TRICEPS`. The finished movement is redundant — the next movement is already shown in the position strip — and the two-part phrasing makes the label long on the Dynamic Island. Users only need to know which movement is coming next.

## What Changes

- Change the movement-switch rest label from `AFTER <finished movement> · NEXT <next movement>` to `NEXT <next movement>`. The word `NEXT` is kept because it is already in the app's copy vocabulary (`NEXT SET`, `NEXT ROUND`, `UP NEXT`) and is short enough for the island.
- Apply the same simplification to the block-transition rest label, `AFTER <finished block> · NEXT <next block>` → `NEXT <next block>`, so the two transition cases stay consistent. (Assumption — the trigger names movement changes, but leaving block transitions on the old phrasing would be inconsistent; flag at review if block transitions should be left alone.)
- Keep `AFTER SET n` for set rests and `AFTER ROUND n` for round rests between rounds of one movement unchanged. The trigger is the movement-change label only.
- Update the Delta Island and Lock Screen rest context to match, since it comes from the same shared copy function.
- Update the prototype (the source of truth for copy) first, then the shared implementation and tests.

Out of scope: completion-alert copy (`AFTER CURL · NEXT PUSHDOWN · …`) and the watch remote, which names the next movement through its own payload field.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `rest-timer`: requirement `Rest copy names what finished` — a movement switch SHALL name only the next movement, and a block transition SHALL name only the next block, instead of naming both the finished and next item.
- `live-activity`: requirement `Rest copy names the transition` (and the rest context used by `Lock Screen state row copy`) — the island and Lock Screen SHALL show the same simplified transition label.

## Impact

- Prototype: `prototype-workout-timer.html` — `restLabelFor()` movement and block branches.
- Shared copy: `Shared/Theme.swift` — `restContext(movementName:)` movement and block cases.
- Phone surface: `Restless/UI/TimerScreen.swift` — rest subtitle, through `restContext`.
- Island and Lock Screen surface: `RestlessWidget/RestlessLiveActivity.swift` — rest context.
- Tests: `RestlessTests/SessionTests.swift`, `RestlessTests/LiveActivityTests.swift` — expected movement-transition copy.
- Specs: `openspec/specs/rest-timer/spec.md`, `openspec/specs/live-activity/spec.md` (Delta specs in this change).
