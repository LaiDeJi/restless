# Proposal

## Why

A saved preset is currently one fixed block: a name, rounds, sets, and two rest values. Real sessions mix body parts — biceps 3 × 3, triceps 4 × 2 — and each part needs its own shape and rests. The setup sheet also stops at 6 rounds and 6 sets, and every stepper tap saves to SwiftData, resets the live session, and restarts the Live Activity, so quick taps make the numbers lag. The app needs a session plan made of parts, a full editing surface, and local-first stepper input.

## What Changes

- A saved **session** becomes an ordered list of **parts**. A part has a name, rounds, sets per round, set rest, and round rest. Example: `Biceps 3 × 3 · 60 / 120`, then `Triceps 4 × 2 · 45 / 90`.
- Parts run sequentially. After the last set of a part, its round rest applies before the next part. The final set of the final part has no rest.
- Existing presets migrate to a one-part session; the default `Chest` 3 × 3 / 60 / 120 is unchanged.
- Rounds and sets per round lose the 6 cap. Values can be stepped or typed; rests stay 15–600 seconds in 15-second steps.
- **BREAKING (internal):** persisted session plans and Live Activity attributes gain parts. Old session snapshots are discarded and rebuilt from the active session.
- The app gets an Apple Health-style bottom tab bar: `TIMER` and `SESSIONS`. The setup sheet is replaced by a sessions list, a session editor, and a part editor.
- Editing is local-first: the displayed value updates on the same tap; SwiftData saves, session resets, and Live Activity refreshes are debounced and happen once per burst, not once per tap.
- The timer and Live Activity show the current part and its progress. The set map falls back to a compact progress bar when a part is too large to draw as dots.
- Editing remains blocked while a rest is running; the `SESSIONS` tab shows the plan read-only in that state.
- The prototype and the `restless-rest-timer` skill are updated before Swift code, as the source of truth and the domain rule set.

## Capabilities

### New Capabilities

- `workout-sessions`: session plans made of ordered parts, per-part limits and rests, persistence and migration, the `TIMER` / `SESSIONS` navigation, and responsive editing.
- `rest-timer`: how a session advances through parts and sets, which rest follows which set, the timer screen's part presentation, and the editing lock during rest.
- `live-activity`: the Lock Screen and Dynamic Island contract when a session has multiple parts.

### Modified Capabilities

None — this is the first OpenSpec change in the project; there are no existing specs.

## Impact

- `Shared/WorkoutPreset.swift`: part model, session plan, rest and position maths (also compiled by the watch target).
- `Shared/SessionSnapshot.swift`, `Shared/Theme.swift`: part-aware positions, copy, and accents.
- `Shared/RestlessActivity.swift`, `RestlessWidget/RestlessLiveActivity.swift`: part-carrying attributes and island copy.
- `Restless/Data/PresetRecord.swift`: SwiftData lightweight migration to parts; legacy columns retained for reading.
- `Restless/Session/SessionEngine.swift`, `Restless/UI/*`, `Restless/App/RestlessApp.swift`: tab shell, edit debouncing, session and part editors, adaptive map.
- `RestlessTests/*`, `prototype-workout-timer.html`, `.agents/skills/restless-rest-timer/SKILL.md`, `AGENTS.md`, and `project.yml` only if a new shared file is introduced.
- No new dependencies, permissions, App Groups, HealthKit, or notification work. The watch target still compiles only the shared model files.
