# Design

## Context

One `ModelContainer` holds all three `@Model` types — sessions, the movement library and history — in `Application Support/default.store`, with `SessionStore`'s running snapshot in `UserDefaults` beside it. A session's blocks live as JSON in `PresetRecord.blocksData`; the movement library is the only place a movement's *name* is stored, since a block movement carries `movementId` alone. `UserDefaults` and the SwiftData file have different lifetimes: clearing the store does not touch the calendar settings.

## Goals / Non-Goals

**Goals:**

- One readable storage shape: the one the current build writes.
- A neutral first-run fixture with no trace of the demo "Chest" plan.
- No migration code, no compatibility columns, no legacy tests.

**Non-Goals:**

- Preserving any of the old store's contents.
- Changing the prototype's demo data, which is a design reference and already carries muscle groups the app dropped.
- Changing history behaviour beyond starting empty.

## Decisions

**A new store file, not a migration.** The container is created with a `ModelConfiguration` pointing at `restless-v2.store`, and the old `default.store` with its `-wal` and `-shm` is removed before the container opens. Deleting a `@Model` property needs a store that never had it; a new file gives that for free.

Alternatives considered: a `SchemaMigrationPlan` with a custom stage (keeps the old model types alive, which is exactly what we are deleting), and a probe of SwiftData's lightweight migration (may work, but leaves `PresetRecord`'s legacy shape unaddressed and leaves the columns in the file).

**No carry-over.** The four sessions and thirteen movements are retyped from the project note. A one-shot reader that copies rows into the new shape would be more code than the data it preserves, and would reintroduce a decoder for a shape the change deletes.

**A neutral seed constant.** `WorkoutPreset.seeded` is "Session 1" holding "Block 1" with one "Movement 1", all with fixed ids so previews and tests stay stable. It replaces `WorkoutPreset.chest`, `Movement.chest` and `Movement.chestID`. Most of the test diff is the mechanical `.chest` → `.seeded` rename; the assertions that depend on the demo plan's totals move to a locally built fixture in the test that needs them.

**One decode shape.** `PresetRecord.blocks`, `WorkoutRecord.blocks` and `WorkoutPreset.init(from:)` decode `[WorkoutBlock]` directly. `StoredBlock`, its `Kind`, `migratedBlocks()`, `adjacentRuns`, `WorkoutPart`, `WorkoutBlock(legacyPart:)` and `MovementRepository.ensureLibrary` are deleted. `WorkoutBlock` keeps tolerating missing scalar keys with defaults; that is ordinary resilience, not a legacy shape.

**`EndCondition` keeps its total decode.** An unknown stored string still lands on `.manual`, because a throwing decoder would drop a plan. Only the comment that names the removed `reps` condition and the tests that pin it change.

**The calendar migration stays.** `restless.calendar.v1` lives in `UserDefaults`, which the reset does not reach. Deleting that decoder would silently wipe rest days and exceptions. The `SessionStore` key sweep collapses to one key, since the running snapshot is versioned by the reset itself.

**History needs no code.** A fresh store has no `WorkoutRecord` rows, so nothing is deleted; only its block decode changes type.

## Risks / Trade-offs

- **Deleting the old store is irreversible** → the phone's store is copied first, and the project note holds the plan, so the data survives outside the app.
- **The calendar anchor moves.** Recreating sessions gives new ids and a new order, and the projection anchors to the round in progress → planned dates after the retype differ from today's; accept the new anchor or start a new round afterwards.
- **Deletion order matters.** The old files must be removed before `ModelContainer` is constructed, or the container may create a `-wal` for the old file again. Removal is best effort: a failure leaves an orphan file, which is harmless.
- **e2e fixtures assume the Chest seed.** Five step lists reference it; they are updated to the neutral seed, and any that rely on the demo plan's nine sets build their own session first.

## Migration Plan

1. Copy the phone's store to a reference folder and keep the inventory note.
2. Build and run on `iPhone 18 Pro`: old store removed, one seeded session, empty history.
3. Retype the four sessions and thirteen movements on the phone.
4. Check the timer, calendar projection, Live Activity and watch remote against the new plan, then confirm no new `Restless-*.ips` reports.
5. No rollback beyond the copied file, which is read-only reference material.
