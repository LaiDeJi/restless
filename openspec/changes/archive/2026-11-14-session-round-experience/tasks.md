# Tasks

## 1. Prototype first

- [x] 1.1 Change the prototype's new-session path to clone only the active
  block's schedule, clear its movements, keep the editor open, disable DONE and
  USE THIS SESSION until a movement exists, and show the save hint. Verify with a
  new `tools/prototype-driver-session.js` run through
  `python3 tools/prototype-check.py` that the draft reports 0 movements and both
  actions are disabled, then enabled after adding a movement.
- [x] 1.2 Replace the prototype's calendar `cadenceStep`, `isSessionSlot`,
  `slotNumber` and `scheduledPlanForKey` with the round arithmetic: `N + G`
  length, session days first, rest days after, session index from the position
  in the round. Change the header description, the row line and the summaries to
  BETWEEN ROUNDS. Verify with
  `python3 tools/prototype-check.py tools/prototype-driver-calendar.js` after
  updating its expected dates and marks for gap 1, gap 2, skips and closures.
- [x] 1.3 Add the done-state celebration to the prototype: a short confetti
  burst that plays once per completion, clears after about 2.5 seconds, does not
  block START AGAIN, and shows a static glow under
  `prefers-reduced-motion: reduce`. Verify with a driver that the overlay appears
  at done, survives a re-render once, and is absent after the budget.

## 2. New session default block

- [x] 2.1 Change `NewSessionDraft.make(from:)` to build one `Untitled block`
  with zero movements and the active first block's rounds, sets per round, set
  rest and round rest, or the standard defaults when there is no active session.
  Verify `NewSessionDraftTests` asserts 0 movements and the inherited schedule.
- [x] 2.2 Add a `WorkoutPreset` commit check for every block having a movement,
  make `SessionDraftCommit.save` refuse an invalid draft, and keep the editor
  from marking a refused draft committed. Verify with a test that an empty draft
  creates no record.
- [x] 2.3 Disable the editor's DONE and USE THIS SESSION while the draft cannot
  be committed and add the `ADD A MOVEMENT TO SAVE THIS SESSION.` hint. Verify
  in the iPhone 18 Pro simulator that both actions are disabled on a fresh draft
  and become enabled after adding a movement.
- [x] 2.4 Update the new-session rule in
  `.agents/skills/restless-rest-timer/SKILL.md` to say the draft copies the
  schedule but no movements and cannot be saved empty. Verify the rule no longer
  says it copies the first block.

## 3. Calendar round gap

- [x] 3.1 Replace `TrainingRotation`'s `step`, `isSessionSlot` and `slotNumber`
  with `roundIndex`/`dayInRound` arithmetic and guard an empty session list.
  Verify with tests for three sessions at gap 1, two sessions at gap 2, one
  session at gap 1, and an empty order.
- [x] 3.2 Update `TrainingRotationTests` marks, skip, next-unstarted, new-round
  and date-change cases to the round cadence, including a closed or skipped
  session day keeping its place and the round's rest days. Verify the full
  `TrainingRotationTests` suite.
- [x] 3.3 Change `CalendarCopy` and the calendar accessibility labels to
  BETWEEN ROUNDS and `N REST DAYS BETWEEN ROUNDS`, and keep `SESSIONS EVERY
  DAY` for zero. Add `CalendarCopyTests` for zero, one and several gaps, run
  `xcodegen generate`, and verify the new test passes.
- [x] 3.4 Update `AGENTS.md` rule 12 to describe one session per day through the
  SESSIONS order, then the configured rest days before the next round. Verify
  the rule no longer says one session every `restDaysBetween + 1` days.

## 4. Completion celebration

- [x] 4.1 Add the `completionEvent` counter to `SessionEngine`, incrementing it
  only when a transition enters `done` through a tap, a deadline or a store
  refresh. Verify with engine tests that a completed run increments once, a
  relaunch of a done snapshot does not, and a restart does not.
- [x] 4.2 Add the `SessionCelebration` overlay with Canvas particles, the
  2.5-second lifetime, the 48-piece cap, non-blocking hit testing and hidden
  accessibility, plus the static Reduce Motion glow. Run `xcodegen generate` and
  verify in the simulator with a recorded screen clip and with Reduce Motion on.
- [x] 4.3 Wire `TimerScreen` to the completion event, including the pending flag
  for a completion reached on another tab and the on-appear check for a rebuilt
  view. Verify on the iPhone 18 Pro: finish a session on TIMER and see one
  burst; finish on SESSIONS and see it on return; launch a done session and see
  none.
- [x] 4.4 Update the timer's done-state rule in
  `.agents/skills/restless-rest-timer/SKILL.md` with the celebration, its
  one-shot rule, the non-blocking rule and the Reduce Motion state. Verify the
  done bullet names the effect.

## 5. Integration checks

- [x] 5.1 Run `xcodebuild -project Restless.xcodeproj -scheme Restless
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
  -derivedDataPath build test` and verify all tests pass.
- [x] 5.2 Run `swiftlint lint --quiet --reporter summary` from the repo root and
  verify no new warnings.
- [x] 5.3 Run `openspec validate session-round-experience --strict` and verify
  the change is valid.
- [x] 5.4 Reinstall the app on the iPhone 18 Pro simulator, confirm a fresh
  session starts with 0 movements, a gap of 1 shows the round's rest days after
  the last session, and a completed session celebrates once. Reinstall again
  after the destructive checks.

## Workflow follow-up

- Archive the change after review with `openspec archive session-round-experience`.
- Verify the archived result and the main specs.
