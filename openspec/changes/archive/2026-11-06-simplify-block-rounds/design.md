# Design

## Context

The current block model is one `count` plus `BlockKind` (straight/circuit). `WorkoutPreset.position`, `rest(after:)`, and `totalRest` branch on the kind. `WorkoutBlock` is persisted as JSON in `PresetRecord.blocksData`; `PresetRecord` also keeps the legacy part columns and `partsData`. The Live Activity attributes and the v3 session snapshot encode the preset, so the block shape reaches the widget and the watch. The prototype and `.agents/skills/restless-rest-timer/SKILL.md` are the behaviour reference, and the watch target compiles `WorkoutBlock.swift`, `WorkoutPreset.swift`, `SessionSnapshot.swift`, and `Theme.swift` from `Shared/`.

Constraints: `Shared/` stays free of SwiftUI except `Theme.swift`; the timer is deadline-based; edits are local-first and coalesced; the watch counts only the watch arm; no App Groups are configured.

## Goals / Non-Goals

**Goals:**

- Make a block two explicit numbers: rounds and sets per round. Remove the arrangement mode and every STRAIGHT/SUPERSET/CIRCUIT label.
- Make the order and rest one rule that reproduces today's straight and circuit schedules after migration.
- Migrate stored blocks, legacy parts, the session snapshot, and the Live Activity payload without losing sets or rest.
- Keep the watch target building and the timer's deadlines, state machine, editing lock, and coalescing unchanged.

**Non-Goals:**

- Per-movement set counts or per-movement rounds. A block shares rounds and sets per round across its movements.
- Changing the timer state machine, rest snapping, start gate, watch counting, audio, App Groups, or the Live Activity transport.
- New session or plan features beyond the block shape and numeric copy.

## Decisions

### 1. Two numbers on the block, no kind

`WorkoutBlock` becomes `rounds` (1 or more) and `setsPerRound` (1 or more). `kind` and `count` are removed. `totalSets = rounds × movements.count × setsPerRound`, using the existing safe arithmetic. The editor shows ROUNDS and SETS PER ROUND; both are unbounded integers with a minimum of 1.

Why: the switch only told the app whether `count` meant sets or rounds. With both numbers present, there is nothing left for the switch to decide. Alternatives: keep `kind` and add `setsPerRound` (still two count meanings and a mode); put rounds and sets on each movement (allows uneven sets but makes a shared superset round ambiguous). Rejected.

### 2. One traversal, one rest rule

For every round 1...R, for every movement in order, run its S sets. After every set except the last of the round, start the block's set rest. After the last set of a round, start the block's round rest. After the last round of a block, the round rest is the block transition when another block follows; the final set of the final block has no rest.

A movement switch is always inside a round, so it uses the set rest and the `.movement` transition (amber accent). The old straight block's long movement transition is preserved by migration: a straight block with several movements splits into one block per movement, so the boundary becomes a block transition with the round rest.

Examples:

- 4 rounds × 4 sets, one movement, 60/120: 16 sets; set rest after sets 1–3, round rest after set 4; total rest 1080 s.
- 2 rounds × 1 set, Biceps + Triceps, 30/120: B → T set rest, T → next round round rest; 4 sets, 180 s total.
- 3 sets, one round: set rest between sets, no round rest.

The editor keeps multi-movement blocks at rounds ≥ 2: adding a second movement to a one-round block raises rounds to 2, and the rounds stepper will not go below 2 while two or more movements are present. The model still reads a one-round multi-movement block as a single pass with set rests, so old or hand-written data remains readable. Migration never creates one: a straight multi-movement block splits.

### 3. Numeric copy

No STRAIGHT, SUPERSET, or CIRCUIT string is stored or computed. Block rows and summaries use the numbers: movements, rounds, sets per round, total sets, set rest, round rest. The block name remains user text; "Superset" can be typed as a name, but the app never assigns it.

Timer position:

- R > 1, S > 1: `ROUND r OF R · SET s OF S`
- R > 1, S = 1: `ROUND r OF R`
- R = 1, S > 1: `SET s OF S`
- R = 1, S = 1: no round or set segment.

Use one shared helper for this copy so the timer and the widget cannot drift.

### 4. Position, rest, totals

`WorkoutPosition` keeps `blockIndex`, `blockName`, `round`, `set`, `movementIndex`, and `movementId`; `blockKind` and `isCircuit` are removed. `set` is the one-based set within the movement's round.

```swift
let perRound = max(block.movements.count, 1) * max(block.setsPerRound, 1)
round = indexInBlock / perRound + 1
movementIndex = (indexInBlock % perRound) / setsPerRound
set = (indexInBlock % perRound) % setsPerRound + 1
```

`rest(after:)`:

```swift
if p.set < block.setsPerRound {
    .set(block.setRest, transition: .set)
} else if p.movementIndex < block.movements.count - 1 {
    .set(block.setRest, transition: .movement)
} else if p.round < block.rounds {
    .round(block.roundRest, transition: .round)
} else if p.blockIndex < blocks.count - 1 {
    .round(block.roundRest, transition: .block)
} else {
    nil
}
```

`totalRest`:

```swift
let perRound = safeProduct(movements.count, setsPerRound)
let setRests = safeProduct(safeProduct(rounds, max(perRound - 1, 0)), setRest)
let roundRests = safeProduct(safeSum(max(rounds - 1, 0), hasNextBlock ? 1 : 0), roundRest)
return safeSum(setRests, roundRests)
```

All products and sums use the existing overflow helpers. Zero set rest still produces a rest value with duration 0 that is never entered.

### 5. Block map

Rows are rounds; columns are the `movements × setsPerRound` sets in a round, with a small gap between each movement's block of sets. The active dot keeps the ring and accent. Row labels are no longer movement names; the position line names the active movement. Use dots when `rounds ≤ 12`, `movements × setsPerRound ≤ 12`, and `rounds × movements × setsPerRound ≤ 72`; otherwise draw the existing bar. A one-round block is one row; a one-movement block is one group.

### 6. Persistence and migration

- `WorkoutBlock` JSON writes `rounds` and `setsPerRound`; `kind` and `count` disappear. Reading accepts the new keys first, then the legacy `kind`/`count`.
- The straight-multi-movement split needs the whole block list, so migration runs at the plan boundary (`WorkoutPreset` decoding and `PresetRecord.blocks`), not inside a single block. A shared helper decodes a `StoredBlock` that accepts both shapes, then emits one or more `WorkoutBlock`s.
- Mapping:
  - straight, one movement, count C → rounds 1, sets per round C.
  - straight, several movements, count C → one block per movement, in order, each rounds 1, sets per round C, same rests; keep the old block name on each.
  - circuit, count C → rounds C, sets per round 1.
  - adjacent duplicate movements in a circuit with the same movement id, end condition, and target → one movement, sets per round = duplicate count.
  - legacy part R × S → one block with rounds R, sets per round S, one manual movement, same name and rests. This preserves the old part's round rests; the previous flattening to one straight count is removed.
  - legacy columns (no `blocksData`, no `partsData`) → one block from the columns.
- `PresetRecord.legacyShape(of:)` mirrors the first block as `(rounds, setsPerRound × movements.count)` so an older build still sees the same total sets in its single part. `partsData` stays nil after a write.
- The session snapshot key moves to v4 and v3 is discarded, because the stored `WorkoutPreset` shape changed and a half-migrated running rest is not worth carrying. The timer opens in the not-started gate at the active session.
- Live Activity attributes carry the new preset; on launch the coordinator ends any stale activity and requests a new one only when the session is running. Activities from the old shape are not decodable and are ended.

### 7. UI

- `BlockEditorScreen`: remove the arrangement section and `BlockKindPicker`; add ROUNDS and SETS PER ROUND steppers. Keep the two rest steppers and the movement list.
- `SessionEditorScreen`: block rows use numeric meta; adding a block inherits rests, copies no movements, and opens the picker for the first movement. Adding a movement to a one-round block bumps rounds to 2.
- `BlockMovementEditorScreen`: subtitle uses rounds and sets per round, no arrangement.
- `TimerScreen`: position line uses the shared round/set copy; no arrangement segment. `SetMap` as above.
- `MovementComponents`: remove `BlockKindPicker`; reuse `PlanCountRow` and `PlanStepperRow`.
- `SessionSnapshot`: remove `currentPart`; `restContext` keeps the shared fallback; the timer and widget resolve movement names for `.movement` copy.
- `RestlessWidget`: `positionLabel` uses the shared copy; `restCopy` already resolves movement names and needs no change beyond `block.rounds` and `block.setsPerRound`.
- `RestlessWatch`: no UI change; it compiles the shared model. Verify the watch scheme build.

### 8. Prototype and skill first

Update `prototype-workout-timer.html` before the Swift: the block shape, arrangement control removal, block summary and meta, position copy, map layout, and demo data. Then update `.agents/skills/restless-rest-timer/SKILL.md`: model, order and rest rules, formulas, examples, copy, and tests.

## Risks / Trade-offs

- [A straight block with several movements becomes several blocks] → The block strip shows more entries and names may repeat. Mitigation: deterministic order, same rests, split only on read; names stay user-editable.
- [A one-round multi-movement block is a new one-pass shape] → Its movement switch uses set rest, unlike the old straight block. Mitigation: the editor raises rounds to 2 on the second movement; migration splits old straight blocks; the model still reads the shape.
- [The snapshot and activity payload shape changes] → Old running state may not decode. Mitigation: v4 snapshot key, v3 discarded, gate; end stale activities on launch.
- [The map layout changes] → Progress for multi-movement blocks may be less obvious. Mitigation: movement gaps, active ring, caption; bar fallback.
- [The total-rest formula assumes the uniform rest rule] → A misread legacy block could produce a different total. Mitigation: decode tests for straight, circuit, multi-movement straight, parts, and duplicate collapse; safe arithmetic.
- [Rollback] → An older build cannot read the new block JSON. Mitigation: legacy columns mirror the first block's total sets; `partsData` is nil; do not roll back with a running session.

## Migration Plan

1. Update the prototype and skill.
2. Add `rounds` and `setsPerRound`, remove `kind` and `count`, and add the shared decoder with legacy fixtures; update the model tests.
3. Update `PresetRecord`, the v4 snapshot, and the Live Activity attributes; update migration tests.
4. Update the editors, timer, map, and widget copy.
5. Run SwiftLint, `xcodebuild test`, and the watch build.
6. Roll back only with a stopped session; reinstall the previous build, which reads the first block from the legacy columns.

## Open Questions

None. The split keeps the old block name on each resulting block; the user can rename. The rounds floor of 2 for multi-movement blocks is an editor rule, not a stored constraint.
