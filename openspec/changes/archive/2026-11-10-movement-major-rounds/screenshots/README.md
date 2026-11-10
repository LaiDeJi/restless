# Implementation notes: movement-major rounds

Screenshots taken on the `iPhone 18 Pro` simulator (iOS 27) while verifying
tasks 5.2, 6.2, and 6.3.

## `map-4x4-before.png`, `map-4x4-after.png`

A single-movement Chest block at 4 rounds × 4 sets, captured from the HEAD build
and from the change's build. The two crops from just under the status bar to the
action button are pixel-identical (ffmpeg `psnr` reports `inf`), so a
single-movement block keeps its four rows, dot spacing, and active dot.

## `timer-2x2x2-switch-rest.png`

The timer at the switch rest of a Biceps and Triceps block, 2 rounds × 2 sets,
60/120: `ROUND REST`, `AFTER BICEPS · NEXT TRICEPS`, and the map's two groups of
two rows with a gap between them.

## `island-switch-before.png`, `island-switch-after.png`

The expanded Dynamic Island during the same switch rest. Before the change the
expanded view carried only the block, movement, and round-and-set segments.
After it, one full-width line above the progress bar names the transition
(`AFTER BICEPS · NEXT TRICEPS`); the round and set segments move out of the way
while the timer and both controls stay fully visible.

Reinstalling the app restores the seeded Chest session after these captures.
