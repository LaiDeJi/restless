# Proposal

## Why

Inside a block with several movements, the timer alternates them every round: Biceps, Triceps, Biceps, Triceps, and so on. A block of three rounds of Biceps followed by three rounds of Triceps does not run that way. Adding a second movement to a one-round block also silently raises ROUNDS to 2. The expected run is that each movement finishes all of its rounds before the next movement starts, and that ROUNDS stays the value the user typed.

## What Changes

- **Movement-major order inside a block.** A block with two or more movements runs its first movement through all of its rounds, then its next movement through all of its rounds. Within each round the movement runs its sets per round. A single-movement block does not change.
- **The movement switch takes the round rest.** The rest after a movement's last round is the block's round rest, shown as ROUND REST with `AFTER <finished movement> · NEXT <next movement>`. The block's set rest applies only between sets inside a round.
- **Rest between rounds of one movement is round rest,** shown as `AFTER ROUND n`, which matches today's rest after a non-final round.
- **The block map has one row per round of each movement,** in run order, with a gap between movements. A single-movement block draws exactly as it does now. The dot and bar limits apply to the rows and to the sets in a row.
- **Adding a movement never changes ROUNDS.** The two-round floor is removed from the one-tap library add, the add-movement sheet, and DONE on a new block. ROUNDS can stay at 1 for a block with several movements.
- **A running session restarts when the app updates.** A saved completed-set count means a different set under the new order, so the snapshot key moves to v5 and a v4 snapshot opens at the start gate, as the v3 to v4 change did. Stored plans are not changed.
- The prototype and `.agents/skills/restless-rest-timer/SKILL.md` change first, because they are the behaviour reference. The Swift code and tests follow.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `rest-timer`: run order inside a block, the rest at a movement switch, total rest, block position, the block map, and rest copy.
- `workout-sessions`: the block schedule runs movement by movement, and adding a movement keeps ROUNDS.
- `live-activity`: the island names a movement switch as a round rest.
- `countdown-alerts`: the completion alert for a movement switch reads ROUND REST OVER and names the next movement.

## Impact

- `prototype-workout-timer.html`: `posAt`, `restAfter`, `blockRest`, the block map markup and painter, and the rounds floor in the editor paths.
- `.agents/skills/restless-rest-timer/SKILL.md`: order, rest table, formulas, examples, map, editor rules, copy, and tests.
- `Shared/WorkoutPreset.swift` and `Shared/WorkoutBlock.swift`: position, rest, and total rest. `Shared/SessionStore.swift`: snapshot key v5.
- `Restless/Session/SessionDraftStore.swift` and `Restless/UI/BlockEditorScreen.swift`: rounds floor removed.
- `Restless/UI/SetMap.swift`: one row per round of each movement.
- `RestlessWidget/`, `Shared/CompletionAlertCopy.swift`, `Shared/SessionSnapshot.swift`, `Shared/Theme.swift`: copy and island read the shared rest, so no code change is expected beyond tests.
- `RestlessTests/`: rest plan, session, engine, completion copy, library add, draft store, map layout, store, and migration tests that encode round-major order, a set-rest switch, the old totals, or the floor.
- No store format change. Stored plans keep their JSON; only the order they run in changes.

Out of scope: per-movement rounds or sets per round, superset or circuit labels, reordering, the Live Activity transport, and App Groups.
