# Proposal

## Why

Plan names are capped at 18 characters, so real movement names such as "Single-arm cable lateral raise" cannot be typed. Sessions are stuck in creation order, restart throws away completed sets on a single tap, and a countdown that reaches zero is silent unless the user is looking at the timer. When the user is in another app, the Live Activity stays compact instead of announcing that the rest is over.

## What Changes

- Raise the session, block, and movement name limit from 18 to 40 characters. Names stay single-line data; editors accept the longer text and list rows may show two lines while the timer, island, and Lock Panel truncate or scale.
- Add manual sorting to SESSIONS. Each session card gets the existing grip/drop treatment, the order persists, new sessions append at the end, and the active badge follows its card rather than being pinned to the top.
- Replace the timer's two-tap RESTART arm with a confirmation dialog that names the consequence: completed sets are cleared, the rest is cancelled, and the session returns to block 1 set 1. The session editor's RESTART SESSION button uses the same confirmation.
- Add a completion alert when a rest or timed work countdown reaches zero:
  - one phone haptic when Restless is in the foreground, plus one watch haptic when the watch app is reachable;
  - one local notification scheduled when Restless moves to the background and left pending at the deadline, including while the app is still executing, so the system delivers it and mirrors it to the paired watch.
- Cancel and reschedule the alert when the rest is paused, resumed, skipped, restarted, completed, or replaced by a plan change, so an old countdown cannot fire later. A notification whose deadline is reached in the background is not cancelled.
- Update the prototype, the rest-timer skill, and the existing Live Activity panel rules to match the new name limit, restart dialog, session order, and alert behavior.

## Capabilities

### New Capabilities
- `countdown-alerts`: cross-device behavior when a rest or timed work countdown ends, including phone haptics, watch alerts, the one background local notification, authorization, and stale-alert cancellation.

### Modified Capabilities
- `workout-sessions`: name rules move from 18 to 40 characters; manual session ordering is added to the SESSIONS page.
- `rest-timer`: restart becomes a confirmation dialog instead of a two-tap arm; a rest or timed set reaching zero raises one completion alert.
- `live-activity`: an alerting update presents the expanded Dynamic Island when the app is executing at the deadline; the panel must hold up with 40-character movement names.
- `app-chrome`: the armed `TAP AGAIN` restart requirement is removed; restart is a dialog action and glass must not imply otherwise.

## Impact

- Models and validation: `Shared/WorkoutPreset.swift`, `Restless/UI/NameRules.swift`, `Shared/WorkoutBlock.swift` comments and tests.
- Sessions: `Restless/Data/PresetRecord.swift` gains persisted order; `Restless/UI/SessionsScreen.swift`, `Restless/UI/PlanListRow.swift`, and the session editor change.
- Timer and restart: `Restless/UI/TimerScreen.swift`, `Restless/UI/SessionEditorScreen.swift`, `RestlessTests/TimerRestartTests.swift`.
- Alerts: a new app-target alert center, `Shared/SessionSnapshot.swift` or `SessionEngine` completion hook, `Shared/RestlessActivity.swift`, `Shared/WatchMessage.swift`, `Restless/Watch/WatchLink.swift`, `RestlessWatch/Session/WatchSessionModel.swift`, and `RestlessWatch/UI/WatchRootView.swift`.
- Reference and rules: `prototype-workout-timer.html`, `.agents/skills/restless-rest-timer/SKILL.md`.
- No server, App Group, push entitlement, or system alarm is introduced. The watch keeps using WatchConnectivity; UserNotifications supplies the alert when the app is suspended.

## Assumptions

- The 40-character limit applies to session, block, and library movement names. Display surfaces may truncate or scale; editors and list rows are the places that show the whole name.
- Session sorting is manual, not alphabetical, and does not depend on the active session. The session list stays read-only while a set, rest, or pause is locked, so its grip and drop actions are disabled like the other plan controls.
- "Countdown" means a rest or a timed work set. Zero-duration rests have no countdown and raise no alert.
- The confirmation applies to both the timer's restart control and the editor's RESTART SESSION. START AGAIN from done has no progress to lose and stays immediate.
- A background completion uses one local notification with the system sound; in-app completion is haptic only. The system mirrors the notification to the paired watch. No custom audio asset is added in this change.

## Out of Scope

- Alphabetical or recently-used session sorting.
- Multiline names stored in the model. The 40-character name stays one string without embedded newlines.
- A push server or APNs Live Activity updates.
- Alerting Live Activity updates that expand the island in the background.
- Any system alarm presentation, including AlarmKit, or alarm authorization.
- Watch-side rest countdown UI or watch controls for pause, skip, or restart.
- Editing plans while a set, rest, or pause is active.
