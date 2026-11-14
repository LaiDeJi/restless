# Tasks

## 1. Prove the platform before any UI

- [x] 1.1 Add an empty watchOS app target to `project.yml` with the same team and bundle prefix, run `xcodegen generate`, and build for the physical watch. Verified when the app installs and launches on the wrist under the team id; if provisioning refuses a second identifier, stop here.
- [x] 1.2 Prove the background wake: send a throwaway `sendMessage` from the watch and log it on the phone while Restless is suspended and the phone locked. Verified when the phone's log shows the delivery while suspended, and shows a clean failure instead of a hang after the phone app is force-quit.
- [x] 1.3 Record the result in `AGENTS.md`: the watch target in the code map, and one sentence in rule 10 that the wrist never alerts. Verified by reading the edited sections back.

## 2. Payload and the time-carrying transition

- [x] 2.1 Add the Codable message types to `Shared/`: an action carrying its tap instant and an id, and a published session carrying the snapshot, the active preset and the movement names. Test round-trip encoding and that an unknown action decodes as ignored. Verified by Swift Testing coverage in `RestlessTests`, and `SharedPurityTests` still passing.
- [x] 2.2 Give `SessionEngine` an apply-at-instant entry point and route `perform` through it with `.now`. Test that SET DONE applied four seconds late still puts the rest deadline at the tap instant, and that a late skip reconciles into the ready phase. Verified by those two tests.
- [x] 2.3 Clamp a tap time more than a few seconds in the future to the arrival time, and drop an action id that was already applied. Test both. Verified by two tests.

## 3. Phone transport

- [x] 3.1 Activate a `WCSession` at launch, convert a received message into a `SessionAction`, apply it at its tap time, and publish the resulting session. Verified when the existing URL-handler and island-link tests still pass, and a unit test of message-to-action mapping covers every action the watch can send.
- [x] 3.2 Publish the application context on launch, on every session change, and when the watch becomes reachable, reusing the snapshot the engine already persists. Verified by a manual check that a second session change replaces the first rather than queueing, and by a log line on failure instead of a thrown error.
- [x] 3.3 Publish nothing when the phone has no active plan or no session to control, so the wrist falls back to asking for the phone. Verified by clearing the session and reading the published context.

## 4. Watch screen

- [x] 4.1 Add the wrist screens to `prototype-workout-timer.html` — READY, WORK, SET REST, ROUND REST, PAUSED, DONE, and the notification — with the exact copy and colours. Verified with `python3 tools/prototype-check.py` showing the new section's DOM.
- [x] 4.2 Build the watch target's shared subset: `WorkoutPreset`, `WorkoutBlock`, `SessionSnapshot`, `Theme` and the message types, excluding `RestlessActivity` because ActivityKit is unavailable on watchOS. Verified by the watch target compiling against `Shared/` without duplicating any file.
- [x] 4.3 Build the single screen: phase label, movement name, round and set position, segmented set bar, and the phase's button pair taken from `primaryTitle` and `primaryAction`. Verified in the watch simulator with seeded contexts for all six phases.
- [x] 4.4 Send a tap as one message and show a not-sent state when the send fails, leaving the screen unchanged. Verified by terminating the phone app and tapping: the wrist reports it and nothing advances.
- [x] 4.5 Render the phase implied by a published deadline when the app resumes after the wrist was down, without changing anything. Verified by a unit test over the shared reconciliation and a manual wrist-drop check with a rest running.
- [x] 4.6 Add a "Watch remote" section to `.agents/skills/restless-rest-timer/SKILL.md`: no clock, same actions, no alerts, no runtime session, no HealthKit. Verified by reading the section against the implemented screen.

## 5. Notification and integration

- [x] 5.1 Confirm the completion notification still carries no actions and that tapping it on the watch opens the watch app. Verified on the physical pair with the phone locked: the wrist app opens on the current phase and nothing advances.
- [x] 5.2 Run the full session on the pair: start from the wrist, complete a set on the wrist, skip a rest on the wrist, pause and resume on the wrist, and finish. Verified when both devices agree at every step and the phone's history record matches a phone-only run of the same plan.
- [x] 5.3 Run both gates: `swiftlint lint --quiet --reporter summary` and `openspec validate watch-remote --strict`. Verified by 0 failures and 0 warnings on the touched files.

## Workflow follow-up

- Archive this change with `openspec-archive-change` once the physical-watch checks in 5.1 and 5.2 pass; a simulator-only pass does not cover the background wake.
