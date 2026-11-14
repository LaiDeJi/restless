# AGENTS.md — Restless

Restless is an iPhone rest timer, mirrored on the Dynamic Island. A session is an ordered list of blocks of movements. A set ends on MANUAL (SET DONE) or TIME (a phone countdown), and a rest follows it except after the last set. Three bottom tabs: TIMER, SESSIONS and CALENDAR. CALENDAR projects the SESSIONS order onto training days and lists the runs actually started.

## Source of truth and layout

- `.agents/skills/restless-rest-timer/SKILL.md` is the rule set for a session: timing, state machine, editing, navigation, Live Activity, alerts, persistence and copy. Read it before changing anything that decides which rest comes next. Where it and the prototype disagree, the prototype wins.
- `prototype-workout-timer.html` is the behaviour and visual reference, over 6,000 lines. `grep -n '/\* -' prototype-workout-timer.html` lists its section headings; read one range with `offset`/`limit`.
- Change order: prototype first for timing, copy, layout or colour, then skill, then code. Deadline maths, persistence, notifications and intents skip the prototype. For a UI change, draw before/after or the options as a page before asking the user to choose.
- Calendar: `Shared/CalendarSettings.swift` (document `restless.calendar.v2` in `UserDefaults`; v1 migrates on load) and `Shared/TrainingRotation.swift` (projection). History: `Restless/Data/WorkoutRecord.swift` and `WorkoutHistoryStore.swift`. Rules 12 and 13 summarise both.
- Code map: `Shared/` is the pure model, with `SessionTransitions` in `SessionSnapshot.swift`, the rest plan in `WorkoutPreset.swift`, `LiveActivityCoordinator` in `RestlessActivity.swift`, and the palette and type scale in `Theme.swift`. `Restless/` holds `App/`, `Session/` (`SessionEngine`, `SessionDraftStore`), `Data/`, `Alerts/` and `UI/` (screens; `Calendar*.swift` is the calendar surface). `RestlessWidget/` is the Live Activity and Dynamic Island, and `RestlessTests/` holds the Swift Testing suites.
- `project.yml` generates `Restless.xcodeproj`; never edit the project by hand. Swift 6 with complete strict concurrency, iOS 18.0 minimum.
- `openspec/` holds one directory per change under `openspec/changes/` and the main specs under `openspec/specs/`. Plan a change there before writing code; the `openspec-*` skills in `.agents/skills/` run the workflow.

## Commands

```bash
xcodegen generate   # after editing project.yml or adding or removing source files

xcodebuild -project Restless.xcodeproj -scheme Restless \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build build

xcodebuild -project Restless.xcodeproj -scheme Restless \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath build test
```

Use the `iPhone 18 Pro` simulator for everything, Argent included. A second booted simulator makes the test runner hang (`iPhone 18 Pro Max` did in an earlier session); if the runner hangs, follow Verification.

- Tests use Swift Testing (`import Testing`, `@Test`).
- SwiftLint runs as a script phase on the `Restless` target, configured by `.swiftlint.yml`; warnings do not fail the build. Only that target disables script sandboxing, because the phase reads the repo.
- Once per clone, run `git config core.hooksPath .githooks`. The pre-commit hook runs SwiftLint and `openspec validate --all --strict`, so both tools must be on PATH.

Device build (iPhone 15 Pro Max, team `VMZG879ZU8`):

```bash
xcodebuild -project Restless.xcodeproj -scheme Restless -configuration Debug \
  -destination "platform=iOS,id=00008130-001A05810190001C" \
  -derivedDataPath "$TMPDIR/restless-device-dd" -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008130-001A05810190001C \
  "$TMPDIR/restless-device-dd/Build/Products/Debug-iphoneos/Restless.app"
```

## Rules

1. `Shared/` stays pure: Foundation, ActivityKit and OSLog only, and SwiftUI only in `Shared/Theme.swift`. `SharedPurityTests` checks SwiftUI and SwiftData imports.
2. Time is a deadline, never a decrementing counter. A ticker only triggers redraws and deadline reconciliation.
3. Every mutation goes through `SessionTransitions.apply`. The app button, the island link and the URL handler have no separate logic.
4. `setDone` is valid only in `ready` and `performing`, where it ends a timed set early; ignore it elsewhere. A double tap must not consume two sets, including at a block boundary.
5. The team is a free Apple Developer account, and **App Groups are not configured**: `SessionStore` falls back to `.standard`, so the widget cannot read the session. Island controls are `Link`s to `restless://<action>`, applied in `onOpenURL`. Apple lists App Groups as available to free accounts, but this project has not tested provisioning one. Do not assert either way; verify with a clean build first.
6. A session is an ordered list of blocks and always keeps at least one block. The last saved session cannot be deleted, and a session's last block has no delete action. Blocks persist as JSON on the SwiftData record; the legacy single-part columns stay readable for migration and rollback.
7. Rounds and sets per round are unbounded integers, minimum 1. Round rest is 15–600 s; set rest is 0 or 15–600 s. Rests step by 15 s, and only rests clamp.
8. Editing is local-first. A stepper tap or keystroke changes the draft only. Persistence, the session reset and the Live Activity refresh coalesce after 350 ms of idle, then flush on dismissal, Done and background. Never save synchronously or call `engine.use` inside a tap handler.
9. Editing is locked while the session is performing, resting or paused: the timer hides EDIT, and SESSIONS and the editors are read-only behind their lock banner. Switching tabs must not change or pause the set or rest.
10. Completion alerts are decided. Foreground: one phone haptic. Background: one local notification, scheduled when the app backgrounds and left for the system to deliver at the deadline. iOS mirrors it to a paired watch, so the app sends no watch alert. No alerting Live Activity update, system alarm or custom audio. Keep `CountdownNotificationDelegate` on the completion-handler `UNUserNotificationCenterDelegate` methods; the async variants crashed a physical iPhone.
11. The movement library is a name list. A movement is created by typing its name in a block's add-movement picker and managed from MOVEMENTS (rename, delete). It has no profile, recording action or watch count. A used movement cannot be deleted. Do not add a second set-ending path.
12. The persisted SESSIONS order is the program. CALENDAR projects it onto a fixed cadence: one session per day through the order, then the configured `restDaysBetween` rest days before the next round. Exceptions are a dated range or one repeating weekday. A closed or skipped session day keeps its place in the round and takes no session, so that session is dropped for the round; the round's rest days stay. A reorder or a new round moves the anchor. A record and a running session never move; adding, renaming, deleting or a settings edit keeps the anchor. A planned date can show another exercise without moving the schedule. A new round is offered only today or later.
13. A history record starts with the first completed set and keeps its own plan snapshot. It is read-only apart from a two-tap delete; editing or deleting the session never changes it. START exists only in a planned day's sheet.

## Verification

- Simulator state persists between runs. Do destructive checks (delete, reorder, big plan edits) on a throwaway simulator, or restore the fixture afterwards. Reinstalling the app reseeds the demo sessions; some e2e files leave a session or library movement behind (`movement-major-timer-walk.yaml` does), so reinstall before running them again.
- Return to the start gate with `open-url restless://restart`.
- `.argent/e2e/` holds Argent step lists. Read a file's header first: it states any fixture, week start or SESSIONS order it assumes, and whether it is a fragment. Waits use `await-ui-element` on visible text; taps use coordinates unless the file uses an accessibility id. Put a flow longer than a couple of taps in one sequence, read the accessibility tree at checkpoints rather than after every tap, add `wait: 800` after each transition, and never repeat a tap you already made.
- Prototype changes: `python3 tools/prototype-check.py [driver.js]` serves the prototype on an ephemeral localhost port and prints the DOM after 6 s of virtual time; `--budget N` (ms) changes the wait. A driver can seed `localStorage` and click before the dump. `tools/prototype-driver-calendar.js` asserts the calendar grid, day sheets, settings and the reorder boundary.
- Completion alert on a physical iPhone: complete a set, press Home while the rest runs, wait out the rest, then pull Notification Center from the top edge and tap the RESTLESS cell. Then check for new `Restless-*.ips` crash reports.
- If `xcodebuild test` says the test runner hung before establishing connection, do not retry unchanged. Terminate the app, shut down extra booted simulators and rerun. After a second hang, reboot the destination or use another simulator.
- Before debugging widget content, check which bundle owns the screen with `xcrun simctl listapps <udid>`. An older `Rounds` (`com.whc.rounds`) install can own the Dynamic Island.
- For a Lock Screen or Dynamic Island change, follow the skill's "Verifying a panel change" section.

## Before finishing

Run both gates at the end of every task; the pre-commit hook only covers commits.

- `swiftlint lint --quiet --reporter summary` from the repo root, even when no Swift file changed.
- `openspec validate <change> --strict` when the work went through an OpenSpec change, or `openspec validate --all --strict` when it edited main specs. A bare `openspec validate --strict` validates nothing. `--all --strict` must report 0 failed, and any failure is real.
