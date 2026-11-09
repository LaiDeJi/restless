# Design

## Context

- The name limit is centralized: `WorkoutPreset.bounds.nameLimit` (18), `WorkoutPreset.clampedName`, and `NameRules` in `Restless/UI/NameRules.swift`. `NameRules.live` caps while typing; `normalize` caps at save.
- `PresetRecord` is the SwiftData session row. `SessionsScreen` uses `@Query(sort: \PresetRecord.createdAt)` and opens a record by appending to `AppRouter.sessionsPath`. Blocks and movements already use `PlanListRow`, whose `PlanDragHandle` and `PlanDropDelegate` implement the 44 × 44 grip, floating preview, and drop reorder.
- `TimerScreen` implements restart as a two-tap arm (`restartArmed`, `TAP AGAIN`). `SessionEditorScreen` has a separate `RESTART SESSION` button with no confirmation.
- `SessionEngine` owns the `SessionSnapshot`; a 200 ms ticker reaches `finishRest` or `setDone` at the deadline. `SessionTransitions.apply` is the single mutation entry point. `LiveActivityCoordinator` updates the one `RestlessActivityAttributes` activity on transitions; the widget reuses the shared position and rest maths.
- The watch side has `WatchMessage`, `WatchLink`, and `WatchSessionModel`. It counts reps and plays `WatchHaptics.success()` at a target; it has no rest countdown.
- Deployment target is iOS 18. App Groups are not configured. Background alerts use one UserNotifications request; the app never relies on background execution for an alert.
- The prototype is the behaviour reference and the rest-timer skill owns the timing rules. Both still describe the 18-character cap, the two-tap restart, and a silent completion.

## Goals / Non-Goals

**Goals:**

- A 40-character name is accepted everywhere a plan name is entered, saved unchanged, and readable in the editor and list rows.
- The SESSIONS list order is user-controlled, persisted, survives relaunch, and never changes the active session or the running timer.
- Both restart entry points explain the lost progress and require confirmation; confirming returns to the start gate and ends the session Live Activity.
- Every rest or timed work countdown that expires raises one alert. The phone haptic is immediate in-app; in the background the one pre-scheduled local notification is the alert, delivered by the system and mirrored to the paired watch without relying on background execution.
- A pending alert is cancelled as soon as its countdown is paused, skipped, restarted, replaced, completed early, or found stale at launch.

**Non-Goals:**

- Alphabetical or recently-used session sorting.
- Multiline stored names, rich text, or per-surface short names.
- A push server, APNs Live Activity updates, or App Groups.
- Alerting Live Activity updates, or any system alarm presentation, or watch-side pause/skip/restart controls.
- Custom audio, sound settings, or an alert history.
- Changing the 160-point Lock Screen panel or the Dynamic Island layout beyond fitting 40-character names.

## Decisions

### 1. Raise the shared name limit to 40 and keep one-line data

Change `WorkoutPreset.Bounds.nameLimit` to 40. `NameRules.limit`, `NameRules.live`, `WorkoutPreset.clampedName`, and every `maxlength` in the prototype read from that one value. Existing stored names are not rewritten; no SwiftData migration is needed.

Add one normalisation rule so the model really is single-line: `NameRules.live` and `WorkoutPreset.clampedName` replace newline and tab characters with a space before trimming and capping. This handles pasted text without changing the visible text of a normal name.

Editors keep the existing single-line `TextField`; a 40-character name scrolls horizontally while focused. The list surfaces get the extra room:

- A session card shows the name with `lineLimit(2)` and a fixed vertical size. Its summary keeps its current two-line clamp.
- The session editor's block rows already wrap; the block editor's movement rows and the library/pending rows change from one line to two.
- The timer header and block strip stay one line with the existing `minimumScaleFactor`; the position strip gets a one-line truncation path before its accessibility-size stacked fallback.
- The Lock Screen panel keeps one line and lowers its movement-name `minimumScaleFactor` from 0.7 to 0.55. The 160-point height comes from the row count, padding, and cap, not the name length.
- The expanded island movement label stays one line; the compact label remains three characters.

Alternative considered: a separate 18-character short name for compact surfaces. Rejected: two names per movement doubles editing and lets the timer and session disagree.

### 2. Persist session order as an optional sort index, normalised at launch

Add `sortIndex: Int?` to `PresetRecord`. An optional attribute is additive for SwiftData's lightweight migration; existing rows read nil and keep creation order. A non-optional attribute would require a store migration that the project does not otherwise use.

`PresetRepository` gets `ordered(_ records:)`, sorting by `(sortIndex ?? Int.max, createdAt)`, and `normalizeOrder(in:)`, which rewrites the ordered records to `0..<n` when any index is nil or not contiguous. Call `normalizeOrder` from `seedIfNeeded` after the store opens, so the first launch after the update turns legacy creation order into indexes 0, 1, 2. `SessionDraftCommit.save` calls it before assigning the new record `sortIndex = ordered.count`. This appends new sessions without moving legacy rows.

`SessionsScreen` stops relying on the `@Query` order and sorts the fetched records with `PresetRepository.ordered`. The active badge stays on its record; there is no active pin. `PresetRepository.fetchAll` uses the same order so the editor, delete fallback, and used-name checks see the list order.

Reordering reuses the existing drag machinery:

- Expose `PlanDragHandle` and `PlanDropDelegate` to the app target (they become internal) or add a small `SessionDragRow` that wraps the same components. The session card's button remains the tap target; the 44 × 44 grip is a sibling.
- On `dropEntered`, move the record in the in-memory ordered array and assign contiguous indexes. On drop end, save once. The source row dims and the target row outlines, matching blocks and movements.
- The grip and accessibility Move up/down are disabled while `engine.snapshot.isLocked`, preserving the existing read-only SESSIONS contract. Reordering never calls `engine.use`; it only writes `sortIndex`.
- Deleting a session leaves gaps; the next launch or reorder normalises them. The last-session guard is unchanged.

Alternative considered: a header sort menu with A–Z and newest. Rejected for this change: the user asked for sorting, the existing drag pattern is already in the app, and a manual order is the only option that lets a favourite session stay first.

### 3. Replace both restart arms with one confirmation dialog

`TimerScreen` loses `restartArmed`, the `TAP AGAIN` label, and the amber arm styling. The button becomes a plain restart icon with the same visibility conditions (`canRestart`). Its action sets `showingRestartConfirmation = true`. The root view owns one `.alert`:

- Title: `Restart this session?`
- Message: `This clears all completed sets, cancels the current rest, and returns to block 1, set 1.`
- Destructive action: `Restart Session`
- Cancel: `Cancel`

Confirming calls `engine.perform(.restart)`, which resets the snapshot to `notStarted`: the timer shows START SESSION and the Live Activity coordinator ends the activity. Cancelling does nothing. The dialog dismisses on phase change, tab change, and when `canRestart` becomes false. `SessionEditorScreen` gets the same state and `.alert` around its existing `RESTART SESSION` button; confirming runs the existing `restart(draft)` path, which flushes, calls `engine.use`, and returns to the timer at the gate. A restart with progress lands in the gate; START AGAIN from done still starts directly because there is nothing to lose. `SessionTransitions` stays the only entry point and the restart tests assert both branches.

Alternative considered: keep the two-tap arm and add a dialog on the second tap. Rejected: it is three interactions for one decision and keeps the amber armed state the user asked to replace.

Alternative considered: restart directly into `ready` at set 1. Rejected: it leaves a Live Activity for a session the user just cleared, and the gate is the one place where START SESSION owns the start.

### 4. One alert state machine, with a notification scheduler

Add a `CompletionAlertCenter` in the app target, owned by `SessionEngine`. It is the only place that decides whether a countdown should alert. It takes a scheduler protocol so tests can use a fake; the production scheduler wraps UserNotifications.

The centre observes three things:

- `SessionEngine` transition: after `SessionTransitions.apply`, it passes the new snapshot and the scene state.
- Scene changes from `RootView`: active, inactive, background.
- Deadline completion from the ticker: the phase that finished and its deadline.

It keeps one pending countdown record: deadline, phase (rest or work), and whether a notification is scheduled. The rules are:

| Situation | Action |
| --- | --- |
| Enter a rest or timed work while active | cancel any previous alert; keep no notification |
| Move to inactive/background during a countdown | schedule one notification for the deadline |
| Return active before the deadline | cancel the pending alert |
| Pause, skip, restart, plan change, done, or zero rest | cancel the pending alert |
| Resume | no schedule while active; schedule on the next background |
| Deadline reached while the app is executing | foreground: cancel the pending notification and play the haptic; background: leave the notification pending and raise no in-app alert |
| Deadline reached while suspended | the notification is the only alert |
| App becomes active after the deadline | reconcile once; do not play a late haptic |

The background deadline branch is the simplification: the already-scheduled notification is the one background alert, so the centre never cancels it at the deadline and never sends an alerting Live Activity update. The system delivers it and mirrors it to the paired watch; no background execution is required. A notification belonging to a countdown that was paused, skipped, restarted, replaced, or never started is still cancelled before its deadline.

`SessionEngine` integration:

- `perform(_:)` applies the transition, calls `alertCenter.sessionChanged(snapshot, isActive:)`, persists, and restarts the ticker. The order matters: a skip or pause cancels before the next frame.
- The ticker applies a deadline transition through a private `performDeadline` that does not call `sessionChanged`; it persists, updates the Live Activity state while the app is executing, and then calls `alertCenter.countdownReached(snapshot, alert:isActive:)`. This keeps the pending notification alive until the system delivers it.
- `countdownReached` in the foreground cancels the pending notification and plays the haptic; in the background it leaves the notification alone and reconciles only to arm a following countdown.
- `use(...)`, `refreshFromStore`, and init call `alertCenter.cancelAll()` before the new snapshot takes over; init also cancels stale alerts left by an earlier launch.
- `scenePhase` is stored in the engine as `isActive` (set by `RootView`).

### 5. Scheduler: one local notification per deadline

`SystemCountdownAlertScheduler` requests authorization lazily when the first countdown is armed with `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound])`.

Scheduling:

- One `UNNotificationRequest` per deadline with a stable prefix identifier, a `UNTimeIntervalNotificationTrigger` at `max(1, deadline - now)`, the completion title and body, and `.default` sound.
- The per-deadline identifier lets the app keep the notification that is already due while it arms a following countdown; adding a later deadline does not replace the earlier request.
- `cancel()` removes every pending request with the prefix, plus the legacy fixed identifier. The centre calls it on pause, skip, restart, plan change, foreground return, and launch. It is not called at a background deadline.
- `stopAlerting()` removes delivered notifications with the prefix when the app becomes active.
- A notification tap routes to TIMER through a `UNUserNotificationCenterDelegate`; `willPresent` suppresses the banner when the app is foreground because the haptic already fired.
- If permission is denied, no notification is scheduled; the session still runs and the timer still advances.

Why not schedule an alerting Live Activity update for the deadline? ActivityKit has no delayed-update API, an update can only be sent while the app is executing, and it would duplicate the local notification. The local notification is the one background alert.

### 6. Completion copy is built once

Add a pure `CompletionAlertCopy` helper (app/Shared, no SwiftUI) that takes the post-transition `SessionSnapshot` and movement-name lookup and returns `(title, body)`:

- Rest: `SET REST OVER`, `ROUND REST OVER`, or `WORK SET OVER` as the title. The body names the finished context (`AFTER SET 2`, `AFTER ROUND 2`, `AFTER CURL · NEXT PUSHDOWN`, `AFTER CHEST · NEXT ARMS`) and the next set, round, and movement.
- Final set: `SESSION COMPLETE` and `17 OF 17 SETS · 2 BLOCKS · 18:00 TOTAL REST`.
- Timed work: `WORK SET OVER`; the body says `REST 1:00 AFTER`, `NEXT SET IMMEDIATELY`, or `NO REST AFTER`.

Reuse `SessionSnapshot.restContext(movementName:)`, `roundSetCopy`, and `plural` so the notification, island, and timer cannot drift. The notification and the alerting update use the same title and body.

### 7. Haptics and watch delivery

- Foreground phone: `UINotificationFeedbackGenerator().notificationOccurred(.success)`. One call per completed countdown. The generator is prepared when the timer enters a rest or work countdown.
- Foreground watch: `WatchLink` gets `alertIfReachable()`, which sends a new `WatchMessage.alert` only when `isReachable`. `WatchSessionModel` handles it by playing `WatchHaptics.alert()` (`.notification`) and leaving the armed set and reps untouched. This is a best-effort extra; the phone haptic always fires.
- Background phone: no separate app haptic. The one local notification, with its `.default` sound, is the notice.
- Background watch: iOS mirrors the local notification to the paired watch, which plays its notification haptic. The app does not schedule a second watch notification, so a watch cannot be double-buzzed. The mirrored notification still arrives when the watch app is not running.

Why not send a WatchConnectivity alert on every background completion? The watch may be suspended and `transferUserInfo` would deliver late, not at the deadline. The local notification is the only reliable path once the phone app is suspended, and the system mirror is the watch delivery.

### 8. The Live Activity stays a state display

`LiveActivityCoordinator` keeps its normal `start`, `restart`, `update`, and `end` calls and has no alerting method. A deadline transition updates the activity with the post-completion state while the app is executing, so a background run that is still alive can show the next set. The notification is the alert; the activity never carries `AlertConfiguration`.

The expanded movement label keeps `lineLimit(1).minimumScaleFactor(0.75)` so a 40-character name does not push the timer. The Lock Screen panel's existing one-line rows and 0.55 scale keep the 160-point budget.

### 9. Prototype and skill updates

The prototype changes first:

- `trimName`, `liveName`, every `maxlength`, and the unique-name suffix move from 18 to 40.
- The SESSIONS cards get a grip and drag reorder, persisted in the demo state, with the active badge following the card.
- The two-tap restart becomes a modal confirmation with the same copy as the app.
- The island gets a simulated alerting state at rest end: the expanded presentation plus a notification/alert card, so the "big island" behaviour is visible without a device. The prototype stays silent; the simulation is visual.

The `restless-rest-timer` skill then updates: 40-character names and the two-line display rule, manual session order, the restart dialog (and removal of `TAP AGAIN`), the completion alert rules, the notification fallback, the watch haptic limit, and the new copy. The skill's "prototype is silent" paragraph changes to "foreground is silent; a suspended background completion uses the notification sound".

## Risks / Trade-offs

- **A suspended app cannot update the Live Activity.** ActivityKit cannot update a Live Activity without the app running. Mitigation: the local notification is scheduled before the deadline and the system mirrors it to the watch; the app does not need background execution for the alert.
- **The suspended Live Activity freezes at 0:00.** The activity keeps its last resting state until the app opens and reconciles. Mitigation: the notification is the notice; opening it or the app updates the activity to READY or DONE. Do not try to update it from the notification.
- **A local notification can look like a second alert when the app is alive.** Mitigation: the notification is the only background alert; the foreground branch cancels it before the haptic, and the notification delegate suppresses a foreground banner.
- **The session list drag can steal the card tap.** Mitigation: the grip is a sibling 44 × 44 surface, exactly like `PlanListRow`, and the card keeps its own button shape.
- **Long names can break compact layouts.** Mitigation: two lines in lists, one line plus scale/truncate on the timer and island, 0.55 scale in the Lock Panel, and tests at 40 characters and xxLarge.
- **Optional `sortIndex` can leave gaps.** Mitigation: normalise at launch, after insert, and after a reorder; ordering is always `(sortIndex ?? max, createdAt)`.
- **WatchConnectivity is not a background timer.** Mitigation: the watch haptic is only a foreground extra; the mirrored local notification is the background guarantee.
- **Notification permission denial makes the suspended background case silent.** Mitigation: request once at the first countdown, never block the session, and keep the timer's visual state authoritative.

## Migration Plan

1. Add `PresetRecord.sortIndex: Int?`; no explicit schema migration. `PresetRepository.normalizeOrder` assigns 0..<n to legacy rows in creation order at the next launch.
2. Raise the name limit. Existing names are unchanged; no store rewrite. A name longer than 18 remains until edited.
3. Remove `NSAlarmKitUsageDescription` and the silent alarm asset; run `xcodegen generate`. No entitlement or App Group change.
4. Add the alert scheduler and centre; on first launch, cancel any pending countdown notification, including the legacy fixed identifier, so an alert from an older build cannot survive.
5. Rollback: remove the alert scheduling and the dialog; `sortIndex` is additive and ignored by older builds. Names over 18 remain readable but new edits cap at 18 again if the limit is reverted.

## Open Questions

None that change the specs or the task breakdown. The suspended-case notification is a platform limit, not an open design choice.
