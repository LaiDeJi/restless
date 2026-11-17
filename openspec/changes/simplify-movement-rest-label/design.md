# Design

## Context

The rest label comes from one shared copy function, `restContext(movementName:)` in `Shared/Theme.swift`. It is consumed by the phone timer (`TimerScreen.subtitle`), the Dynamic Island and Lock Screen (`RestlessLiveActivity` rest context). The prototype's `restLabelFor()` is the project's source of truth for copy, so per `AGENTS.md` it is changed first. The watch does not use this copy during a rest: it names the next movement from its own published payload and uses `subtitle` only in the done state.

## Goals / Non-Goals

**Goals:**

- Make a movement-switch rest label name only the next movement: `NEXT <movement>`.
- Keep the phone, island and Lock Screen labels in sync by editing the single shared source.
- Keep the prototype, Swift copy, tests and specs consistent.

**Non-Goals:**

- Changing completion-alert copy (`AFTER CURL · NEXT PUSHDOWN · …`), which is a separate decided surface.
- Changing the watch remote, set-rest copy (`AFTER SET n`), or round-rest copy (`AFTER ROUND n`).
- Changing rest timing, state transitions, persistence or Live Activity refresh behaviour.

## Decisions

**Edit the shared `restContext(movementName:)` once, not each surface.** All three surfaces call it, so a single edit updates the phone and both widget panels. The prototype's `restLabelFor()` is edited first as the copy source of truth, then the Swift function.

**Keep the `NEXT` prefix.** The label becomes `NEXT TRICEPS`, not a bare `TRICEPS`. Alternatives considered: bare movement name (ambiguous beside round/set info) and `UPCOMING` (longer than the island's space and not in the app's copy vocabulary). `NEXT` matches `NEXT SET`, `NEXT ROUND` and the strip's `UP NEXT`.

**Simplify the block transition the same way.** A block transition becomes `NEXT <block>`. This keeps the two transition cases consistent; leaving only movement switches simplified would produce two different copy styles for the same kind of rest. This is an assumption recorded in the proposal — confirm at review.

**Keep the nil-name fallback coherent.** With no `movementName` closure, the movement case returns `NEXT MOVEMENT` instead of `AFTER <block> · NEXT MOVEMENT`. No current consumer shows this during a rest, but the fallback should follow the same rule.

**Leave set and round cases untouched.** `AFTER SET n` and `AFTER ROUND n` still state what finished; the user's complaint is about the movement-change label only.

## Risks / Trade-offs

- **The position strip already shows `UP NEXT <movement>` during a rest**, so `NEXT <movement>` in the subtitle is partly repetitive. → Accepted: the strip is the position row and the subtitle is the rest context; the user explicitly asked for the next movement to be named.
- **Prototype and Swift copies can drift.** → Change the prototype first, then the shared Swift function, and run the prototype check before the build.
- **Blind find/replace would corrupt unrelated copy.** `AFTER … NEXT …` also appears in completion-alert strings and tests. → Limit edits to `restLabelFor()` and `restContext(movementName:)` and their direct tests; do not touch `CompletionAlertCopy` or its tests.

## Migration Plan

None — user-visible copy only, no stored data or schema changes. Rollback is reverting the prototype and Swift edits plus their tests.

## Verification

- `python3 tools/prototype-check.py` to confirm the rest label renders `NEXT <movement>` after 6 s of virtual time.
- `xcodebuild ... test` for the `Restless` scheme; update `SessionTests` and `LiveActivityTests` expectations first.
- Before finishing, run `swiftlint lint --quiet --reporter summary` and `openspec validate simplify-movement-rest-label --strict`.
