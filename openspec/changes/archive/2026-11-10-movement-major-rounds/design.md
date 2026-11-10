# Design

## Context

A session is ordered blocks; a block holds rounds, sets per round, rests and ordered movements. The order and rests are defined once in `Shared/` and mirrored in the prototype:

- `Shared/WorkoutPreset.swift`: `position(in:blockIndex:indexInBlock:)` and `rest(after:)`.
- `Shared/WorkoutBlock.swift`: `perRoundSets`, `totalSets`, `totalRest(hasNextBlock:)`.
- `Restless/UI/SetMap.swift`: the block map, one row per round with dots grouped by movement.
- `prototype-workout-timer.html`: `posAt`, `restAfter`, `blockRest`, `mapMarkup`, `paintMap`, and the rounds floor in the editor.
- `Restless/Session/SessionDraftStore.swift` and `Restless/UI/BlockEditorScreen.swift`: the two-round floor for blocks with two or more movements.
- `Shared/SessionStore.swift`: the running snapshot stores `doneSets`, a count of completed sets, and is keyed `restless.session.v4`.

The round → movement → set order and the set rest at a movement switch come from `simplify-block-rounds` (archived 2026-11-06, decision 2). That change also rejected per-movement rounds and sets, and this change keeps that rejection: rounds and sets per round stay shared by a block's movements.

## Goals / Non-Goals

**Goals:**

- Each movement finishes all of its rounds before the next movement starts.
- A movement switch is a round rest; the set rest applies only between sets inside a round.
- A single-movement block runs, rests, totals, and draws exactly as today.
- Adding a movement leaves ROUNDS as the user typed it.
- The rule lives in `Shared/`, so the timer, the island, the Lock Screen panel, and the completion copy follow it without their own maths.

**Non-Goals:**

- Per-movement rounds or sets per round.
- Superset or circuit labels, or alternating movements within a round.
- Changes to the state machine, deadlines, editing lock, coalescing, or the Live Activity transport.
- Changes to stored JSON. Plans keep their shape; only the order they run in changes.

## Decisions

### 1. Movement-major order

For a block with `M` movements, `R` rounds, and `S` sets per round, the set at 0-based index `i` in the block is:

```swift
let setsPerMovement = safeProduct(rounds, setsPerRound)     // R × S, clamped
let movementIndex   = min(i / setsPerMovement, movements.count - 1)
let within          = i % setsPerMovement
let round           = within / setsPerRound + 1
let set             = within % setsPerRound + 1
```

The block total stays `R × M × S`. With one movement, `movementIndex` is always 0 and `round` and `set` are the values they are today. Blocks still run in session order, and a block is finished before the next one starts.

For `M = 2`, `R = 3`, `S = 2` (Biceps, Triceps), the set indices are:

```
Biceps   round 1: 0 1   round 2: 2 3   round 3: 4 5
Triceps  round 1: 6 7   round 2: 8 9   round 3: 10 11
```

The old order interleaves the two movements in every round, which is the behaviour this change replaces.

### 2. Rest after a set

The rest after the set at `(movementIndex, round, set)`:

```swift
if set < setsPerRound                  { return .set(setRest, transition: .set) }
if round < rounds                      { return .round(roundRest, transition: .round) }
if movementIndex < movements.count - 1 { return .round(roundRest, transition: .movement) }
if blockIndex < blocks.count - 1       { return .round(roundRest, transition: .block) }
return nil
```

| Where | Duration kind | Transition | Kicker | Accent |
| --- | --- | --- | --- | --- |
| Inside a movement's round | set | set | `SET REST` | set-rest green |
| End of a round, the movement has another round | round | round | `ROUND REST` | round-rest amber |
| End of a movement's last round, another movement follows | round | movement | `ROUND REST` | round-rest amber |
| End of the block's last movement's last round, another block follows | round | block | `ROUND REST` | round-rest amber |
| Last set of the last block | none | — | `LAST SET` / `FINISH` | green |

The movement switch changes from a set rest to a round rest. The kicker, the accent, and the copy `AFTER <finished> · NEXT <next>` follow from the duration kind and transition, so no string changes except where the switch was described as "inside a round".

The switch takes the round rest, not the set rest, as chosen during planning. The alternative, a set rest at the switch, would make the 2 × 3 × 2 block 15:00 instead of 16:00 and keep the old kicker.

### 3. Totals

```
setRests   = M × R × (S − 1) × setRest
roundRests = (M × (R − 1) + (M − 1) + hasNextBlock) × roundRest
blockRest  = setRests + roundRests
```

With `M = 1` both terms reduce to today's formula. Worked examples at the values in the proposal:

| Block | Today | Proposed |
| --- | --- | --- |
| 2 movements, 3 rounds, 2 sets, 60 s set rest, 120 s round rest | 13:00 (9 set rests, 2 round rests) | 16:00 (6 set rests, 5 round rests) |
| 2 movements, 2 rounds, 1 set, 30 s set rest, 120 s round rest | 3:00 | 6:00 (0 set rests, 3 round rests) |
| 1 movement, 4 rounds, 4 sets, 60 s set rest, 120 s round rest | 18:00 | 18:00 |

The two-movement, one-round, several-sets block is a single set-rest run per movement with one round rest at the switch. Two separate blocks give the same totals, because the block transition is also a round rest.

### 4. Block map

The map draws one row per (movement, round), in run order. Each row has `S` dots. Dot `k` of row `(m, r)` is set index `(m × R + r − 1) × S + k − 1`, so the done and current dots use the same index as the timer. A gap separates movements. The active row is the row of the current `(movementIndex, round)`.

Caps keep today's numbers, applied to the new shape: dots when rows (`M × R`) ≤ 12, sets per row (`S`) ≤ 12, and total sets ≤ 72. Otherwise the bar is drawn with `n OF m SETS IN THIS BLOCK`. A single-movement block has `R` rows and is unchanged.

Before and after, three of twelve sets done (● done, ◉ current, ○ next):

```
Today: rows are rounds          Proposed: one row per movement round
R1  ● ●  ·  ● ◉                 R1  ● ●
R2  ○ ○  ·  ○ ○                 R2  ● ◉
R3  ○ ○  ·  ○ ○                 R3  ○ ○
                                (gap)
                                R1  ○ ○
                                R2  ○ ○
                                R3  ○ ○
```

The movement names are not drawn on the map, as today; the position line names the active movement.

### 5. ROUNDS keeps its value

Adding a movement never changes `rounds`. The floor is removed from:

- `SessionDraftStore.appendMovements(toBlock:)`, the staged-block `appendMovements`, and `appendBlock`.
- `BlockEditorScreen.minimumRounds`, which becomes a minimum of 1 for every block.
- The prototype's `blockMin` and the three prototype append paths.

The steppers keep their other rules: a minimum of 1 and no upper cap.

### 6. Running sessions restart on update

`doneSets` is a count of completed sets, so under the new order the same count points at a different set. A v4 snapshot cannot be reinterpreted. The key moves to `restless.session.v5`, and `restless.session.v4` joins the legacy keys that `load()` clears. The result is the start gate, as the v3 to v4 change produced. Stored plans and `ActivePresetStore` are not touched. A running Live Activity is ended on launch, as it is today when no session runs.

### 7. Copy

- Movement switch: `ROUND REST` with `AFTER <finished movement> · NEXT <next movement>`. The completion alert title is `ROUND REST OVER`, which follows from the rest kind.
- Between rounds of one movement: `AFTER ROUND n`, where `n` counts that movement's rounds.
- The block editor's order preview keeps its text, `ORDER · n ROUNDS · NAME × S → NAME × S`. Each movement runs for the block's rounds in turn, so the preview remains accurate.
- Prototype demo data keeps its three sessions. Its comment that calls Arms a superset is dropped.

### 8. Prototype and skill first

The repo's rule is that the prototype and the skill change before the Swift. The prototype changes first, is checked in headless Chrome with `tools/prototype-check.py`, and then the skill is updated. Only then do `Shared/` and `Restless/` change, followed by the tests.

## Risks / Trade-offs

- [A movement switch always costs the block's round rest] → Set rest now separates only sets inside a round. A user who wants a shorter switch lowers that block's round rest. The totals table shows the cost.
- [Multi-movement blocks run longer] → The 2 × 3 × 2 example grows from 13:00 to 16:00 of rest. This is the intended order, and the total is visible on the block editor and the session card.
- [More multi-movement blocks fall back to the bar] → A block with three movements and five rounds has 15 rows, over the 12-row cap, where it used to draw dots. The bar keeps the map height bounded under the countdown ring.
- [A running session is reset on update] → The v5 key discards a v4 run. Update between sessions; the start gate is the safe state.
- [The block editor's order preview may read as round-major] → Its text is unchanged. If it misleads in use, change it in a follow-up with its own before and after mockup.

## Migration Plan

- No data migration. Stored blocks read with the same `rounds`, `setsPerRound`, rests, and movements; only the run order and the rest at a switch change.
- Snapshot: bump to v5 and clear v4 on load, so an in-flight v4 run opens at the start gate.
- Rollback: reinstall the previous build with a stopped session. The v4 key is cleared by v5, so a rollback also opens at the gate.
