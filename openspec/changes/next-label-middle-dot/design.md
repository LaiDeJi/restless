# Design

## Context

The transition rest label comes from one shared copy function, `restContext(movementName:)` in `Shared/Theme.swift`, consumed by the phone timer (`TimerScreen.subtitle`), the Dynamic Island and Lock Screen (`RestlessLiveActivity` rest context and state row). The prototype's `restLabelFor()` is the project's source of truth for copy, so per `AGENTS.md` it changes first, then the skill, then the Swift code. `simplify-movement-rest-label` (implemented, not archived) landed the undotted `NEXT <name>`; the skill file and one e2e checkpoint still carry the older pre-simplification phrasing, so their update is folded into this change. See proposal.md — Why.

## Goals / Non-Goals

**Goals:**

- Make the transition rest label read `NEXT · <name>` on the phone, island and Lock Screen by editing the single shared copy source.
- Bring `.agents/skills/restless-rest-timer/SKILL.md` and the `movement-major-timer-walk` e2e checkpoint in line with the shipped copy.
- Keep the prototype, skill, Swift copy, tests and specs consistent.

**Non-Goals:**

- Changing completion-alert copy (`AFTER CURL · NEXT PUSHDOWN · …`), which is a separate decided surface that already dots its segments.
- Changing the watch remote (names the next movement through its own payload), the position strip's `UP NEXT` segment, the ready screen's `NEXT` hero text, or the set and round labels.
- Changing rest timing, state transitions, persistence or Live Activity refresh behaviour.

## Decisions

**Edit the shared `restContext(movementName:)` once, not each surface.** All three surfaces call it, so a single edit updates the phone and both widget panels. The prototype's `restLabelFor()` is edited first as the copy source of truth. Alternative — per-surface literals — would drift and there are none to edit: the surfaces hold no separate copy for this label.

**Separate `NEXT` from the name with ` · `.** The label becomes `NEXT · TRICEPS`. The middle dot is the separator the app's copy already uses (`2 BLOCKS · 12 SETS · …`, `UP NEXT · <movement> · ROUND 2 OF 4`, alert segments). Alternatives considered: a colon (`NEXT: TRICEPS`, not used anywhere in the app's vocabulary) and no separator (the current state this change replaces).

**Dot the block transition the same way.** A block transition becomes `NEXT · <block>`. Leaving it undotted would give the same kind of rest two different copy styles, the same consistency argument `simplify-movement-rest-label` used for simplifying it. This is an assumption recorded in the proposal — confirm at review.

**Keep the nil-name fallback coherent.** Without a `movementName` closure the movement case returns `NEXT · MOVEMENT`. No current consumer shows this during a rest, but the fallback should follow the same rule.

**Update the skill and e2e straight to the final copy.** `SKILL.md`'s rest-label, island rest-context, state-row and worked-example lines still read `AFTER <x> · NEXT <y>` because the simplification change updated prototype and code but not the skill. This change rewrites those lines to `NEXT · <name>` directly — the intermediate undotted phrasing never needs documenting. Its completion-alert lines (`AFTER CURL · NEXT PUSHDOWN`, `SET REST OVER`) are alert copy and stay as they are. The `movement-major-timer-walk.yaml` checkpoint gets the same one-step fix, `AFTER BICEPS · NEXT TRICEPS` → `NEXT · TRICEPS`.

**Leave set and round labels untouched.** `AFTER SET n` and `AFTER ROUND n` still state what finished; the dot belongs to the `NEXT` label only.

## Risks / Trade-offs

- **Blind find/replace of `NEXT ` would corrupt unrelated copy.** `AFTER … NEXT …` appears in completion-alert strings and their tests, `UP NEXT` in the position strip, and `NEXT` as the ready hero text; the prototype's debug strip also renders ` · NEXT <movement>` next to the rest label, mirroring the position strip. → Limit edits to `restLabelFor()` and `restContext(movementName:)`, their direct test expectations, the skill's rest-label lines and the one e2e checkpoint; do not touch `CompletionAlertCopy`, its tests, or the debug strip's trailing position readout.
- **Prototype and Swift copies can drift.** → Change the prototype first, then the shared Swift function, and run the prototype check before the build.
- **The dot adds two characters to the island's rest line.** → Accepted: the expanded island line is full width and previously carried the longer `AFTER <name> · NEXT <name>` phrasing; `NEXT · <name>` is shorter than that by the whole finished-name segment.

## Migration Plan

None — user-visible copy only, no stored data or schema changes. Rollback is reverting the prototype, skill, Swift and test edits.

## Verification

- `python3 tools/prototype-check.py` (with a driver that reaches a movement-switch rest) to confirm the label renders `NEXT · TRICEPS`.
- `xcodebuild ... test` for the `Restless` scheme; update `SessionTests`, `LiveActivityTests` and the e2e checkpoint expectations first.
- `swiftlint lint --quiet --reporter summary` and `openspec validate next-label-middle-dot --strict` before finishing.
