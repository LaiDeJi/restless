# Design

## Context

Restless currently runs a deadline-based rest timer over parts made of rounds × sets. Every set ends on a manual tap, the watch lab counts dumbbell curls only, and its link to the phone is one-way file transfer. HealthKit is available on the free team, so the watch can run an `HKWorkoutSession` and keep motion while the wrist is down. See `proposal.md` for motivation.

The change replaces parts with blocks of movements, adds a recorded movement library, and gives every set one of three end conditions: reps, time, or a tap.

## Goals / Non-Goals

**Goals:**

- A movement recorded once on the watch is reusable in any session and counted by the watch.
- A session can mix straight blocks and circuits; a two-movement circuit reads as a superset.
- Timed sets run a work countdown and then the same rest as any other set.
- The phone stays the source of truth; the watch is a sensor with a manual fallback.
- The prototype and the timing skill are updated before any Swift.

**Non-Goals:**

- Exercise recognition. The user names the movement; the app never guesses it.
- A trained model. The profile is a threshold calibration, not Core ML.
- App Groups, heart-rate sampling, workout history, or HealthKit data beyond keeping the session alive.
- Automatic session arrangement, exercise order, or rest prescription.
- Workout history, load tracking, or per-set logging.
- Rep progress in the island. The island updates on transitions only.
- "Reps or time, whichever first" as a fourth end condition.

## Decisions

### A block is the session unit; a movement is a library entry

A session is an ordered list of blocks. A block holds a name, a kind, a set rest, a round rest, and ordered movements. A movement in a block references a library entry and carries its own end condition and target. A block may hold any recorded movements; the block name is chosen independently.

### Two block kinds, one traversal swap

A block is `straight` or `circuit`. Straight runs movement-major: all sets of one movement, then the next. Circuit runs round-major: one set of each movement, then the next round. `sets` means sets per movement in a straight block and rounds in a circuit. A two-movement circuit is labelled `SUPERSET`; three or more is `CIRCUIT`.

The timing engine needs one inner/outer swap, not three engines. The inner loop is the movement's sets in a straight block and the movements in a round in a circuit. The rest rule is the same sentence in both: set rest while the inner loop continues, round rest when it ends.

Alternative considered: three kinds with separate behaviour. Superset and circuit differ only in movement count, rest defaults, and the label, so a third kind would duplicate the engine.

### A set ends on reps, time, or a tap

The end condition belongs to the block movement. Reps uses the watch count; time uses a phone countdown; manual waits for SET DONE. The library has no default, so the same movement can be counted in one session and timed in another.

Alternative considered: an exercise-level type. Bench press is a rep exercise in one session and a 60-second set in another; the type belongs to the use, not the exercise.

### The phone owns the plan, profile, and rest; the watch is a sensor

The phone derives the profile, stores the library, runs the session, and starts the rest. It arms the watch with a token, the profile, and the target. The watch counts, reports progress, and reports completion. The phone applies the same `setDone` transition as the button and the island link.

Alternative considered: the watch runs the session. It loses the rest timer and the island, and the watch still needs a workout session to keep motion running with the wrist down, so the phone would still have to run the rest.

### The profile is four numbers, not a model

The phone derives the forearm elevation rise and fall (degrees) and the minimum period from the recorded trace, then validates that at least three complete cycles exist, the amplitude clears a floor, and the period variance stays under a cap. The signal is the angle between gravity and the watch's +Y axis, so the watch face orientation around the forearm does not matter. The watch applies those numbers; it does not learn during a set.

This is the part that can invalidate the feature. The task order puts a replay spike first: take three reps from a recorded set, derive the profile, run it over the rest of the set, and compare with the known count. If the profile does not hold across curls, lateral raises, and rear flies, the library still ships for names and targets, but counting falls back to the manual path.

Alternative considered: a Core ML model trained on public data. It needs subject-grouped training, adds model size and a training loop, and does not remove the need for a workout session to keep motion running.

### Timed sets add a `performing` phase

`ready` gains a sibling: `performing`, with its own `setDuration` and `setDeadline`. A timed set starts on a tap, runs its work countdown, and then applies the same `setDone` transition as a manual set. SET DONE during a timed set ends it early. The rest is unchanged.

Alternative considered: reuse `resting` for the work countdown. It would make work and rest indistinguishable in the timer, the island copy, and the accent, and every rest guard would need a special case.

### Two-way, tokenized watch link

The arm message carries a unique token. Progress and completion echo it. The phone ignores a token that no longer matches the armed set, so a late message cannot consume the next set. The arm uses `updateApplicationContext` so it survives a suspended watch app; progress uses `sendMessage`; completion uses `sendMessage` with a queued fallback.

Alternative considered: rep-by-rep queued messages. They are reliable but slow and noisy; progress is best-effort, completion must arrive.

### Persistence keeps the legacy path readable

Movements persist as their own records. The session record gains an optional `blocksData`; when it is nil, the old `partsData` is decoded as one straight block with one manual movement. The legacy single-part columns mirror the first block's first movement, so an older build still opens the first block. The Live Activity attributes change shape; launch ends stale activities before requesting a new one.

Alternative considered: migrate the old JSON in place. Keeping the old key readable is simpler and gives a rollback path.

### Copy and prototype first

`prototype-workout-timer.html` gets the new timer, block editor, movement library, recording status, and timed-set screens before any Swift. The skill then records the block model, the end conditions, the `performing` phase, the island contract, and the new copy. Code follows the prototype and the skill, not the other way round.

### The movement library lives inside SESSIONS

The library is a MOVEMENTS section reachable from SESSIONS, not a third bottom tab. The two-tab shell and its "switching tabs never changes the rest" contract stay intact. The library opens as a screen from the sessions page and returns to it.

Alternative considered: a third tab. It separates the library clearly but changes the tab bar, the navigation spec, and the tests for no functional gain.

## Risks / Trade-offs

- **A profile from one short recording is unreliable** → validate hard, reject bad recordings, keep the manual fallback, and run the replay spike before building the library UI.
- **Workout authorization can be denied** → keep the foreground fallback, show armed/unavailable on the timer, and keep SET DONE on every set.
- **Only the watch arm is counted** → document it; alternating work is correct when the watch arm finishes the set, one-arm-at-a-time only when the watch arm goes last.
- **Two-way link latency or reachability** → tokens make late messages harmless; completion is queued; the manual path always works.
- **The model rewrite touches every screen and the island** → stage the tasks: prototype, model and migration, library, block editor, timed sets, watch link, island, tests.
- **A timed set can be confused with a rest** → distinct phase, distinct copy, and the set-rest accent for work.
- **Scope is large for a personal project** → ship in stages; the library and the block model are useful even if watch counting is disabled.

## Migration Plan

1. Add the block and movement model with defaults; decode old `partsData` as one straight block with one manual movement.
2. Add the movement library and profile records; existing sessions keep working with manual movements.
3. Add the block editor and the end conditions; the prototype and skill land first.
4. Add the timed-set phase and the island content.
5. Add the watch recording, arm, progress, and completion path behind the manual fallback.
6. Keep the legacy columns mirrored so an older build opens the first block.

Rollback: the old build reads the legacy columns and opens the first block; the library and profiles are ignored.

## Open Questions

- What are the exact profile floors and caps? They are empirical and belong to the replay spike, not to this design.
