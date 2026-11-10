# Verification

## Visual review — TIMER and MOVEMENTS

The before/after pair was rendered from the prototype at `HEAD` and the updated
prototype, using the same seeded demo session in its ready state.

- **TIMER**: the before state shows the `WATCH ARMED · 0 OF 10 REPS` strip with
  its `+ REP` / `DISCONNECT` simulation buttons under the set map. The after
  state removes the strip; the primary action takes its place at the same gap
  and the countdown ring keeps its centre.
- **MOVEMENTS**: the before state shows the header `+`, `recorded on the watch`
  copy, a `PROFILE` / `NO PROFILE` line on every row, and the
  `+ RECORD MOVEMENT` row. The after state keeps the list, rename, usage line
  and delete, with no meta line and no recording control.

Review result: approved on 2026-11-10. Subtraction only; no new controls and no
replacement card.

## Implementation verification

### Install over the previous build, with a running REPS snapshot

The previous build (`HEAD`, commit `57ee591`) was built in a worktree and
installed on `iPhone 18 Pro`. Its active `Chest` session was given a stored
`"endCondition":"reps","target":10` row and a running rest snapshot
(`doneSets` 1) that carried the same row. The new build was installed over it
without clearing the data container.

Verified on the simulator with Argent:

- The timer opened inside the same rest: `1 OF 9 SETS`, `UP NEXT CHEST · SET 2 OF 9`.
- The session kept 1 block, 1 movement, 1 round, 9 sets each, 9 sets, set rest
  1:00, round rest 2:00.
- The movement row read `01, Chest, MANUAL`; its editor offered `MANUAL` and
  `TIME`, selected `MANUAL`, and showed `NO TARGET`.
- The movement name `Chest` survived.
- No watch strip appeared on the timer, and SESSIONS, the block editor and the
  movement editor carried no recording control or profile tag.
- The installed app bundle contains no `Watch/` directory.

### TIMER and SESSIONS screens

Reviewed on the simulator after the install: the timer's ready action sits
directly below the set map with no watch strip; SESSIONS says `Reusable in any
block`; MOVEMENTS says `1 MOVEMENT · ADDED FROM A BLOCK`, has no header add
control and no record row, and lists the name only.

### E2E sequences

Both saved sequences pass on `iPhone 18 Pro` with the new build, back to back:

- `.argent/e2e/session-start-and-draggable-lists.yaml` — 43 steps. Rewritten to
  the current UI: the gate, START SESSION, a new session draft, `+ ADD BLOCK`,
  the one-tap library add, the block drag, DONE, and deletion of the created
  session. It returns to the gate through `restless://restart` so it is
  repeatable, and every wait is a raw `await-ui-element` because the runner tree
  on this simulator resolves no stable text nodes for YAML selectors.
- `.argent/e2e/drag-reordering.yaml` — 98 steps. The session, block and movement
  drags and the movement-picker coordinates are unchanged and still valid after
  the third end-condition segment disappeared; the picker's default MANUAL
  selection lands on the same rows. It now returns to the start gate through
  `restless://restart` after `restart-app`, so it no longer depends on the
  preceding fixture leaving the timer unstarted.

The stale `10 REPS` selector was replaced by `MANUAL` in the session-start
fixture; it is now covered by the movement row text `01, Chest, MANUAL`.

### Gates

- `xcodegen generate` regenerated the project and `Restless/Info.plist` without
  the watch target or file-sharing keys.
- `xcodebuild ... build` succeeded with no watch target; the built bundle has no
  `Watch/` directory.
- `xcodebuild ... test` passed 205 tests.
- `swiftlint lint --quiet --reporter summary` reported 0 violations.
- `openspec validate remove-movement-recording --strict` reported the change
  valid.
