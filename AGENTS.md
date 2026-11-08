# AGENTS.md — Restless

Rest timer for iPhone: untimed sets, a set rest, a longer round rest, and the
same state mirrored on the Dynamic Island. A session is an ordered list of
blocks of movements; after a block's last set its round rest leads into the next
block. Two bottom tabs — TIMER and SESSIONS — replace the old setup sheet. The
watch app in `RestlessWatch/` counts recorded movements for an armed set, records
new movement profiles, and keeps the curl lab behind its LAB button.

## Source of truth

- `prototype-workout-timer.html` is the behaviour and visual reference. It is
  about 5,500 lines, so `grep -n '/\* -' prototype-workout-timer.html` prints its
  40 section headings (CSS and JS); read the matched range with `offset`/`limit`
  instead of paging the whole file.
- Change timing, copy, layout or colour in `prototype-workout-timer.html`
  first, then the skill and code. Deadline maths, persistence, notifications
  and intents do not touch the prototype.
- `.agents/skills/restless-rest-timer/SKILL.md` owns the timing rules, the state
  machine, the island contract, the platform limits and how to verify a Lock
  Screen or Dynamic Island change. Read it before changing anything that decides
  which rest comes next.
- `RestlessWatch/README.md` owns the watch app: movement recording, set counting,
  the curl lab, install steps and its limits.
- `project.yml` generates the Xcode project. Never edit `Restless.xcodeproj` by hand.
- `openspec/` is the planning home: one directory per change under
  `openspec/changes/`, plus the specs they derive from. Plan a change there
  before writing code; the `openspec-*` skills under `.agents/skills/` run the
  workflow.

## Commands

```bash
xcodegen generate

xcodebuild -project Restless.xcodeproj -scheme Restless \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build build

xcodebuild -project Restless.xcodeproj -scheme Restless \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build test
```

Use that one simulator for everything, including Argent. A second booted
simulator is what makes the test runner hang, and `iPhone 18 Pro Max` hung twice
in the last session where `iPhone 18 Pro` ran 189 tests in two seconds. If the
runner does hang, follow the remedy under Verification rather than switching
device.

SwiftLint runs as a script phase on the `Restless` target; run it on demand with
`swiftlint`. Rules live in `.swiftlint.yml`, and warnings do not fail the build.
That target sets `ENABLE_USER_SCRIPT_SANDBOXING: NO` because the phase reads the
repository; the other targets keep the sandbox on.

The repository is under git. `git config core.hooksPath .githooks` installs the
pre-commit gate: SwiftLint plus `openspec validate --all --strict`.

Watch app (`RestlessWatch` is embedded in the iPhone app; no watch simulator is
installed on this Mac):

```bash
xcodebuild -project Restless.xcodeproj -scheme RestlessWatch \
  -destination 'generic/platform=watchOS' \
  -derivedDataPath "$TMPDIR/restless-watch-dd" build
```

Device build (iPhone 15 Pro Max, team `VMZG879ZU8`):

```bash
xcodebuild -project Restless.xcodeproj -scheme Restless -configuration Debug \
  -destination "platform=iOS,id=00008130-001A05810190001C" \
  -derivedDataPath "$TMPDIR/restless-device-dd" -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008130-001A05810190001C \
  "$TMPDIR/restless-device-dd/Build/Products/Debug-iphoneos/Restless.app"
```

## Verification

- The simulator keeps state between runs. Do destructive checks (delete,
  reorder, big plan edits) on a throwaway simulator, or restore the fixture
  afterwards; do not burn the only session you still need.
- A flow longer than a couple of taps belongs in one Argent e2e sequence. Read
  the accessibility tree at checkpoints, not after every tap.
  `.argent/e2e/session-start-and-draggable-lists.yaml` already waits on
  `await-ui-element` text selectors and taps by label; extend it (or copy its
  shape) before writing raw coordinates, and never repeat a tap you already made.
- Prototype changes get checked in headless Chrome: `python3
  tools/prototype-check.py [driver.js]` serves the prototype on an ephemeral
  localhost port and prints the DOM after 6 s of virtual time. A driver runs
  before the dump, so it can seed `localStorage`, click, and write the strings it
  asserts into the page. Pass `--budget N` to change the wait.
- If `xcodebuild test` says "The test runner hung before establishing
  connection", do not retry it unchanged. Terminate the app, shut down extra
  booted simulators, then rerun; after a second hang, reboot the destination or
  use another simulator.
- Before debugging widget content, check which bundle owns the screen with
  `xcrun simctl listapps <udid>`. An older `Rounds` (`com.whc.rounds`) install
  can own the Dynamic Island.
- End a task with `swiftlint lint --quiet --reporter summary` from the repo root
  and `openspec validate <change> --strict` when the work ran through an OpenSpec
  change. Warnings do not fail the build, so neither gate is automatic. For a
  spec-shape housekeeping edit, `openspec validate --all --strict` must report
  5 passed, 0 failed.

## Rules

1. `Shared/` is pure model plus ActivityKit; no SwiftUI except `Shared/Theme.swift`.
   The watch target compiles `WorkoutPreset.swift`, `WorkoutBlock.swift`,
   `MovementProfileDerivation.swift`, `ProfileRepCounter.swift`,
   `WatchMessage.swift`, `SessionSnapshot.swift` and `Theme.swift` from it, so
   keep those free of iOS-only frameworks.
2. Time is a deadline, never a decrementing counter. A ticker only triggers
   redraws and deadline reconciliation.
3. Every mutation goes through `SessionTransitions.apply` — the app button, the
   island link and the URL handler must not have separate logic.
4. `setDone` is valid only in `ready`; a double tap must not consume two sets,
   including at a block boundary.
5. The team is a free Apple Developer account. **HealthKit is available**: a
   clean build with `com.apple.developer.healthkit` in
   `RestlessWatch.entitlements` produced a profile and a signed app carrying the
   entitlement, so an `HKWorkoutSession` is possible and counting keeps running
   with the wrist down. App Groups are not configured; `SessionStore` falls back
   to `.standard`, so the widget extension cannot read the session. Apple lists
   App Groups as available to free accounts, but this project has not tested
   provisioning one; do not repeat the old "free team cannot use App Groups"
   claim without a clean build. Island controls are `Link`s to
   `restless://<action>` and the app applies them in `onOpenURL`.
6. A session is an ordered list of blocks and always keeps at least one block.
   The last saved session cannot be deleted, and a session's last block has no
   delete action. Blocks persist as JSON on the SwiftData record, with the
   legacy single-part columns kept readable for migration and rollback.
7. Rounds and sets per round are unbounded (minimum 1); rests stay 15–600
   seconds in steps of 15. Only rests clamp.
8. Editing is local-first: a stepper tap or keystroke updates the draft, and
   persistence, the session reset and the Live Activity refresh are coalesced
   after 350 ms of idle, then flushed on dismissal, Done and background. Never
   put a synchronous save or `engine.use` inside the tap handler.
9. Editing is locked while the session is performing, resting, or paused; the
   timer hides EDIT and SESSIONS is read-only with its lock banner. Switching
   tabs must not change or pause the set or rest.
10. The prototype is silent. Sound and rest-end notifications are undecided, not
    an omission to fix silently. The watch plays one haptic when a set target is
    reached and when a recording stops.
11. The watch counts the watch arm only. Counting runs in an `HKWorkoutSession`,
    so motion continues with the wrist down and the screen off; if workout
    authorization is denied it falls back to the foreground. Recording a
    movement uses `CMSensorRecorder` for the same reason. The curl lab is still a
    measuring tool, not the timer: it needs the screen on and its CSV/logs travel
    one way over WatchConnectivity. Do not add a second counting path.

## Layout

- `Shared/` — session and block maths, rest plan, session snapshot and
  transitions, store, activity attributes, coordinator, palette.
- `Restless/` — app entry, router and root tab shell, engine, draft store,
  SwiftData session record, timer and sessions screens, watch link, recording and
  trace receiver.
- `RestlessWidget/` — Live Activity and Dynamic Island, built from the shared
  session snapshot.
- `RestlessWatch/` — watch app: set counting, movement recording, curl lab,
  WatchConnectivity.
- `RestlessTests/` — rest plan across blocks, session transitions, draft
  debouncing, and record migration.
