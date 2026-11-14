# Proposal

## Why

The wrist draws all sets in the session as up to 24 thin segments, so a normal 16-set block reads as one dashed line and loses the round and set structure the phone already shows. Separately, the timer keeps whichever session was last activated even when the calendar day advances, so a planned rotation never reaches the timer without a manual pick.

## What Changes

- Replace the watch's session-wide segmented bar with one continuous progress bar for the current block. Show the block's own count above the bar (`5 / 16 · SETS IN THIS BLOCK`) and the session-wide count below it.
- Use the same bar for every block size. There is no dot map, no dot cap, and no dots-to-bar fallback on the wrist; the watch has one progress form.
- Keep the phone's existing current-block dot map unchanged. The single-form rule applies to the watch surface chosen here.
- Share only the done-in-block arithmetic between the phone and the watch, so both agree on how many of the current block's sets are complete without moving the phone's map.
- Make the timer's active session follow today's planned session on launch, on return to the foreground, and at a local day change.
- Switch only when the current session has not started, or is already done. A performing, resting, or paused session is never replaced.
- Hold a manual pick for the rest of that day: `USE THIS SESSION`, a calendar day's `START`, and the fallback after deleting the active session all count as manual. The next day follows the plan again.
- Keep the current session on a rest, closed, skipped, or unplanned day; on such a day there is nothing to follow.
- Honour a per-date exercise change when resolving that day's plan.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch-remote`: the progress requirement changes from a session-wide segmented bar to one continuous current-block bar with a block count and the session count.
- `workout-sessions`: the active session becomes date-following, with a manual choice held for the day and running progress protected.

## Impact

- Watch UI: `RestlessWatch/WatchRemoteView.swift` (a `WatchBlockBar` view), with `project.yml` and `xcodegen generate` if the view gets its own file.
- Shared progress maths: `Shared/SessionSnapshot.swift` (a done-in-block helper); `Restless/UI/SetMap.swift` may adopt the same helper without changing its dots or limits.
- Active-session flow: `Shared/SessionStore.swift` (`ActivePresetStore` day marker), `Restless/App/RootView.swift`, `Restless/App/CalendarSettingsModel.swift` or a small follower, and the manual activation sites in `Restless/UI/SessionEditorScreen.swift` and `Restless/UI/CalendarDaySheet.swift`.
- Tests: block progress maths and active-session decisions, including a session with progress, a done session, a manual pick, and a rest day.
- No change to the watch payload shape, the session JSON, the database schema, or the Live Activity. No App Group is needed; the watch keeps receiving the phone's published snapshot.
