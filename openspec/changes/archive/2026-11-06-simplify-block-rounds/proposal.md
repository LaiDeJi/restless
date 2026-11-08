# Proposal

## Why

A block stores one `count` plus a STRAIGHT/CIRCUIT switch. The switch only disambiguates the count — sets per movement or rounds — and chooses the rest at a movement boundary. As a result a movement cannot be 4 rounds of 4 sets: the user must add the same movement four times to a circuit and set four rounds, or accept sixteen straight sets without a round rest. That duplication is the main authoring cost, and the switch is a mode users must understand before they can express a normal plan.

The fix is to stop overloading one number. A block gets `rounds` and `setsPerRound`; the arrangement is derived from them. The 4 × 4 case becomes `rounds = 4`, `setsPerRound = 4`; a superset becomes `rounds = 2`, `setsPerRound = 1` with two movements. No switch, no duplicate movement rows.

## What Changes

- Replace `WorkoutBlock.kind` and `WorkoutBlock.count` with `rounds` and `setsPerRound`. **BREAKING** for the persisted block JSON shape.
- Remove the arrangement picker and every stored or computed label `STRAIGHT`, `SUPERSET`, `CIRCUIT`. Block copy is numeric: movements, rounds, sets per round, total sets.
- One order: round → movement → set. One rest rule: set rest between sets inside a round; round rest after each round and after a block when another block follows.
- A block with one movement is that movement repeated `rounds` times. A block with two or more movements is a repeated group where each movement does `setsPerRound` sets per round. A sequential pair is two blocks.
- `totalSets = rounds × movements × setsPerRound`; `totalRest = rounds × (movements × setsPerRound − 1) × setRest + (rounds − 1 + hasNextBlock) × roundRest`.
- The timer position shows `ROUND n OF R` and `SET n OF S`, hiding a segment when its count is one. The block map uses `rounds` rows × `movements × setsPerRound` dots, or the existing 72-dot bar fallback; the straight/circuit layout switch is removed.
- Migration: `straight, count C` becomes `rounds = 1, setsPerRound = C`; a straight block with several movements splits into one block per movement; `circuit, count C` becomes `rounds = C, setsPerRound = 1`; a circuit with adjacent duplicate movements collapses the duplicates into `setsPerRound > 1`. Legacy `partsData` keeps its existing path and then applies the same mapping.
- Live Activity attributes carry rounds and sets per round instead of kind and count; the content state shape is unchanged.
- The prototype and `.agents/skills/restless-rest-timer/SKILL.md` are updated first, because they are the behaviour reference.
- Existing rest values and snapping, the 350 ms coalescing, the editing lock, and the session start gate do not change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: block structure becomes rounds plus sets per round; the arrangement switch and labels are removed; the block editor, summaries, movement list, and migration rules change.
- `rest-timer`: order, rest selection, total rest, position, timer copy, and the block map no longer branch on straight/circuit; multi-set rounds and the 4 × 4 case are added.
- `live-activity`: attributes and island or expanded content carry rounds and sets per round without an arrangement; position copy shows round and set.

## Impact

- `Shared/WorkoutBlock.swift`: remove `BlockKind`, add `rounds` and `setsPerRound`, update decode, clamp, and rest math; `Shared/WorkoutPreset.swift`: position, rest, totals, and the legacy part bridge; `Shared/SessionSnapshot.swift`: rest context and position copy.
- `Restless/UI/`: `SessionEditorScreen`, `BlockEditorScreen`, `BlockMovementEditorScreen`, `MovementComponents` (remove `BlockKindPicker`), `TimerScreen`, and `SetMap`.
- `Restless/Data/PresetRecord.swift`: mirror migration and JSON round-trip.
- `Shared/RestlessActivity.swift` and `RestlessWidget/`: attributes, state, and island copy.
- `RestlessWatch/`: compiles from `Shared`; no watch UI change, but the shared model and snapshot change.
- `RestlessTests/`: rest plan, session, record migration, and watch link tests.
- `prototype-workout-timer.html` and `.agents/skills/restless-rest-timer/SKILL.md`: remove the switch, labels, and old formulas; add rounds × sets per round.
