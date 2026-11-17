---
name: restless-rest-timer
description: Domain rules for the Restless workout rest timer — sessions made of ordered blocks of library movements, each movement running all of its rounds before the next, rounds and sets per round, per-set end conditions (time or a tap), the performing work countdown, set/round/movement/block rests, local-first editing, and the Live Activity/Dynamic Island contract. Use when writing, reviewing, or testing any code that decides which rest comes next, counts sets or rounds, starts or ends a timed set, advances a block or movement, pauses a rest, ends a session, adds, renames or deletes a movement, persists or migrates sessions, debounces an edit, or renders timer state on the Lock Screen or Dynamic Island.
---

# Restless rest timer

The prototype `prototype-workout-timer.html` is the behaviour reference; this skill is the rule set. When the two disagree, the prototype wins and this file gets fixed.

## Vocabulary

- A **session** is an ordered list of **blocks**.
- A **movement** is a reusable, name-only library entry. Its name is the whole entry: no muscle group, no profile, and no default end condition or target.
- A **block** holds a name, **rounds**, **sets per round**, a set rest, a round rest, and ordered **block movements**. A block movement references a library movement and carries its own end condition and target, so the same movement can be timed in one block and manual in another.
- The plan unit is **BLOCK**. A block has a user-chosen name, rounds, sets per round, and one or more movements. There is no arrangement mode and no straight/superset/circuit label. The block name is independent of its movements.
- A set ends on **TIME** (a phone countdown) or **MANUAL** (SET DONE).
- A timed set runs a **performing** phase before its rest. It is work, not rest.

## Model

```swift
enum EndCondition { case time, manual }

struct Movement {
    var id: UUID
    var name: String        // trimmed, 40 characters; nothing else
}

struct BlockMovement {
    var id: UUID
    var movementId: UUID
    var endCondition: EndCondition
    var target: Int?
}

struct WorkoutBlock {
    var id: UUID
    var name: String        // trimmed, 40 characters
    var rounds: Int         // 1 or more
    var setsPerRound: Int   // 1 or more
    var setRest: Int        // seconds; 0 or 15...600, step 15
    var roundRest: Int      // seconds; 15...600, step 15
    var movements: [BlockMovement]  // never empty
}

struct WorkoutPreset {
    var id: UUID
    var name: String        // trimmed, 40 characters
    var blocks: [WorkoutBlock]      // never empty
}
```

One order: **movement → round → set**. Each movement runs all of the block's rounds before the next movement starts; within a round it runs `setsPerRound` sets. A block with one movement is that movement repeated across its rounds; a block with two or more movements runs them one after another, each through every round. A sequential pair is two blocks, not one header over two movements.

Ranges: rounds and sets per round are any integer 1 or more. Time targets are seconds; the editor uses 15–600 in 15 s steps. A block's set rest may be 0; a round rest is 15–600. Only rests clamp, and a rest stepper never wraps. Every product and sum clamps at `Int.max` instead of trapping; a typed value that would overflow keeps its previous value. There is no rounds floor: adding a movement never raises rounds, and ROUNDS has a minimum of 1 for every block however many movements it holds.

Defaults:

- The app fallback is one session `Chest` with one block `Chest`, one manual movement `Chest`, **rounds 1, sets per round 9**, set rest 60, round rest 120. The active session survives.
- A new session copies the active session's first block's rounds, sets per round, set rest and round rest and **no movements**, then opens as an unsaved draft named `New session` with one `Untitled block`; it is created and opened, not activated. The draft cannot be saved empty: DONE and USE THIS SESSION stay disabled while any block has no movement, the editor shows `ADD A MOVEMENT TO SAVE THIS SESSION.`, and adding a movement enables both. DONE saves exactly one session with the edited name and blocks and leaves it inactive; USE THIS SESSION saves it and activates it; back or swipe-back discards it. The list, the active session, and the timer do not change until it is saved. The default name gets its lowest free suffix (`New session 2`, `New session 3`, …) at save time, not when the draft opens.
- `+ ADD BLOCK` opens a new block in the same editor layout used to edit a saved block: block name, summary, rounds, sets per round, set rest, round rest, movement list, order preview, and `+ ADD MOVEMENT`. The new block starts as `Untitled block` with rounds 1, sets per round 3, the previous block's set and round rests, and no movements. It is staged outside `session.blocks`: the session keeps its original blocks while it is authored. DONE appends the staged block and flushes the plan, and stays disabled until the block has at least one movement. Back or cancel discards it and adds nothing; backgrounding and a save flush never append it. `+ ADD BLOCK` creates one staged block at a time.
- The add-movement picker lists MANUAL and TIME and starts on MANUAL. ADD MOVEMENT or a library row queues a movement with the selected end condition and target; tapping the row again unqueues it; DONE creates or reuses the typed library movements, appends every queued movement to the block in the displayed order, flushes the plan, and closes; CANCEL and swipe-down discard the queue without changing the block or the library. A name is queued at most once, ignoring case. The same order applies in the block movement editor. The picker only queues movements for a saved or staged block; it has no new-block mode, and DONE with an empty queue simply closes.
- The prototype seeds three demo sessions (Chest 4 × 4, Arms 2 rounds × 1 set with two movements, Core 1 round × 3 sets) and seven movements so every flow can be walked. That demo data is not the app seed.

Derived, never stored:

```swift
blockSets(block)  = block.rounds * block.movements.count * block.setsPerRound   // overflow-clamped
sessionTotalSets  = sum over blocks of blockSets(block)
position(at: i)   = walk blocks by blockSets; 0-based i
  perMovement   = rounds * setsPerRound
  movementIndex = indexInBlock / perMovement
  within        = indexInBlock % perMovement
  round         = within / setsPerRound + 1
  set           = within % setsPerRound + 1
currentPosition = position(at: min(doneSets, totalSets - 1))
```

For each block `i` (0-based), with `hasNext = i < blocks.count - 1`:

```swift
setRests   = movements.count * rounds * (setsPerRound - 1) * setRest
roundRests = (movements.count * (rounds - 1) + (movements.count - 1) + (hasNext ? 1 : 0)) * roundRest
blockRest  = setRests + roundRests
totalRest  = sum over blocks of blockRest
```

Examples:

- 4 rounds × 4 sets, one movement, 60/120 → 16 sets; set rest after sets 1–3 of each round, round rest after set 4; total rest 1080 s (12 set rests + 3 round rests).
- 2 movements (Biceps, Triceps) × 3 rounds × 2 sets, 60/120 → 12 sets; Biceps runs rounds 1–3, then Triceps runs rounds 1–3; total rest 960 s (6 set rests + 5 round rests: two inside each movement's rounds, one at the switch).
- 2 movements × 2 rounds × 1 set, 30/120 → 4 sets; every rest is a round rest — between Biceps' rounds, at the switch, and between Triceps' rounds; total rest 360 s.
- 1 round × 3 sets, one movement, 60/0 → 3 sets; 120 s of set rest and no round rest.
- A 40-round block at 25 sets per round, one movement → 1000 sets, no overflow. The block map falls back to a bar.
- A zero set rest adds no set rest and no countdown; round boundaries still rest.

## Which rest follows which set

The rest is chosen from the position of the set just completed, not from a counter of rests:

```swift
func rest(after doneSets: Int) -> Rest? {
    guard doneSets < totalSets else { return nil }
    let p = position(at: doneSets)
    let block = blocks[p.blockIndex]

    if p.set < block.setsPerRound {
        return .set(block.setRest)                          // inside the movement's round
    }
    if p.round < block.rounds {
        return .round(block.roundRest)                      // end of a round, another round follows
    }
    if p.movementIndex < block.movements.count - 1 {
        return .round(block.roundRest)                      // movement switch
    }
    guard p.blockIndex < blocks.count - 1 else { return nil }
    return .round(block.roundRest)                          // block transition
}
```

The rest has a **duration kind** and a **transition kind**. The kicker and accent follow different things:

| Where | Duration kind | Transition | Kicker | Accent |
| --- | --- | --- | --- | --- |
| Inside a movement's round | set rest | set | `SET REST` | set-rest green |
| End of a round, the movement has another round | round rest | round | `ROUND REST` | round-rest amber |
| End of a movement's last round, another movement follows | round rest | movement | `ROUND REST` | round-rest amber |
| End of the block's last round, another block follows | round rest | block | `ROUND REST` | round-rest amber |
| Last set of the last block | none | — | `LAST SET` / `FINISH` | green |

Rest copy states what finished:

- A set rest: `AFTER SET n`.
- A round rest between rounds of one movement: `AFTER ROUND n`, counting that movement's rounds.
- A movement switch: `NEXT · INCLINE PRESS` (the block's round rest).
- A block transition: `NEXT · ARMS` (the block's round rest).
- A zero set rest starts no rest at all; the next set is ready immediately. The ready screen shows `NO REST` / `NEXT`, not a `0:00` countdown.
- The final set of the final block has no rest, straight to done.

Rest is nil only on the very last set; a zero-duration set rest is a rest value with duration 0 that is never entered, so it also leaves the next set ready immediately. A movement switch and a block transition are still `.round` when the duration is the round rest; there is no third rest kind.

## State machine

`notStarted → ready → performing → resting → ready` per timed set, `ready → resting → ready` per other set, plus `paused` and a terminal `done`.

| State | Meaning | Entry effect |
| --- | --- | --- |
| `notStarted` | a session is selected but the session has not begun | `doneSets` stays zero, no rest, no set, nothing armed |
| `ready` | a set is next | `doneSets` unchanged, no countdown |
| `performing` | a timed set is running | `setDuration = target`, `setDeadline = now + duration` |
| `resting` | rest counting down | `duration`, `deadline = now + duration` |
| `paused` | rest frozen | `remaining = remainingNow()` before clearing the deadline |
| `done` | last set of the last block completed | `doneSets = totalSets`, no rest |

Transitions and the guards that matter:

- **Start session** is valid only in `notStarted`. It enters `ready` at block 1, set 1 with `doneSets = 0`; it never completes a set. Applying it again in `ready` is ignored.
- **Set done** is valid in `ready` and `performing`. Ignore it in every other state, including `notStarted` — the island button is easy to double-tap, and a second call must not consume a second set, including at a block boundary.
- **Start set** is valid only in `ready` and only when the current block movement's end condition is `time`. It enters `performing`; it never starts a manual set.
- **Set done during performing** ends the timed set early and starts the same rest as any other set. **Expiry** at `setDeadline` applies the same transition. Clear `setDuration` and `setDeadline` on every exit from `performing`.
- **Set done with no rest** ends the session: `doneSets = totalSets`, state `done`, clear rest fields. A zero set rest does the same except it lands in `ready` at the next set.
- **Rest end**, **Skip rest**, and **Finish rest** land in `ready` at the next set — block 2, round 1, set 1 when the rest was a block transition — and clear `restKind`, `duration`, `remaining`, `deadline`.
- **Pause** is valid only in `resting`; **resume** only in `paused`. A timed set is never paused. Resume recomputes the deadline from the frozen remaining, so paused time never eats the rest.
- **Start again** resets to `ready`, `doneSets = 0`, empty rest and set fields, block 1. It is a direct start, not the gate.
- **Use this session** activates it and resets to `notStarted` with zero completed sets.
- **The active session follows the day.** On launch, foreground and a local day change the app activates today's planned session when the current one has no completed sets or is done. A performing, resting or paused session is never replaced, and a rest, closed, skipped or unplanned day leaves the active session alone. A manual activation (`USE THIS SESSION`, a calendar day's `START`, the fallback after deleting the active session) holds for the rest of that day; the next day follows the plan again.
- **Restart session** in the editor returns to the start gate at block 1 with zero completed sets.
- A committed edit to the **active** session's plan resets the session to `notStarted` with zero completed sets, no rest, and no running set. Editing another session never touches the running one.
- Launch, and an install with no saved run, opens in `notStarted`. A restored snapshot keeps the phase it stored, so an in-flight `ready`/`resting` session from before a start gate continues rather than being interrupted.
- Every mutation goes through one entry point (`SessionTransitions.apply`) so the button, the island link and the URL handler cannot drift.
- Only SET DONE starts a rest. Progress or elapsed time alone never does.

## Time

Store a deadline, never a decrementing number:

```swift
remaining = max(0, deadline.timeIntervalSince(.now))
```

A ticker exists only to trigger redraws; it must not be the source of truth. This is what makes backgrounding, lock/unlock, and a suspended app resume correctly. On `scenePhase == .active`, reconcile the rest deadline and the set deadline in the same frame, before drawing.

Use `Text(timerInterval:pauses:countsDown:)` for the rest and work countdowns on screen and in the island. It renders at the right cadence without per-second view updates or per-second Live Activity pushes.

`SessionStore` uses the v5 snapshot key. A v4 snapshot is discarded and the timer starts in the not-started gate at the active session: `doneSets` is a count of completed sets, and the movement-major order points the same count at a different set, so a v4 run cannot be reinterpreted. `ActivePresetStore` keeps the selected session across the change. A timed set that expires while the app is inactive lands in its rest on the next reconcile. A saved v5 snapshot keeps its stored phase; only a missing snapshot opens the gate.

## Editing

- **Locked while performing, resting, or paused.** The timer hides `EDIT`; SESSIONS and every editor are read-only with an amber `EDITING LOCKED DURING A SET OR REST · SWITCH TO TIMER TO SET DONE OR PAUSE` banner. Add, delete, reorder, activate, and every field are disabled. Lock returns to available when the session is ready or done, without leaving the tab. Switching tabs never changes the running set or rest.
- **Local-first.** A stepper tap or keystroke mutates the in-memory draft only, so the number leads the finger. Persistence, session reset and Live Activity refresh are coalesced after 350 ms of idle and applied once per burst. Live Activity is never requested per tap.
- **One-tap library add.** A block editor lists `ADD FROM LIBRARY` under its movements: every library movement not already in the block, one 44 pt row each with a `MANUAL` label and a `+`. A tap appends that movement with `MANUAL` and no target in one draft edit and flushes once; no sheet opens and the row appears in the same frame. The same list appears for a staged block, so `ADD BLOCK` → tap a movement → `DONE` creates a one-movement block and nothing reaches `session.blocks` before DONE. The list is hidden while editing is locked and absent when every library movement is already in the block. The add-movement sheet remains for several movements, custom ends or targets, and typed names, and adding a movement leaves ROUNDS unchanged.
- **A staged block is not a session block.** A new block's name, rounds, sets, rests, movements, and order edits live in the draft store outside `session.blocks`. They do not mark the draft dirty or schedule a save; only DONE commits the block, and back or cancel drops it. The block editor hides DELETE BLOCK for a staged block because leaving is the delete action.
- **Flush on exit.** Dismissal, `Done`, and `scenePhase != .active` commit a pending edit. A synchronous SwiftData save or `engine.use` inside the tap handler is the bug this exists to prevent.
- **A page tap dismisses the keyboard.** On the session, block, movement, and add-movement pages, a tap outside the focused text field ends editing and hides the keyboard; a tap inside the field keeps it, and the typed text stays. One shared modifier owns the field-frame guard.
- Discrete actions (activate, create, delete, move) apply immediately; they are one intentional action, not a burst.
- Counts have no upper bound: ROUNDS and SETS PER ROUND step by 1 and a tapped value becomes a number field. ROUNDS has a minimum of 1 for every block, whatever its movements. Rests are stepper-only in 15 s steps; a round rest stops at 15 and 600, and a set rest may be 0 and stops at 600 (never wrapping).
- **A stepper's whole chip is the target.** The visible 48 × 44 body is the control, not only its symbol or leading edge. A tap steps once; holding for 500 ms repeats every 100 ms until release, disable, lock, or the range bound. Every repeat updates the draft in memory, and the same 350 ms debounce collapses the whole hold into one save and one refresh. DONE is the commit for a draft.
- **The drag grip owns only its own row.** The grip's drag surface is 44 × 44 and hit-tests only that height; it must never claim a vertical strip above or below its row, or it steals taps from steppers and header actions in the same trailing x range.
- **Draggable plan rows.** The session editor's block list and a block editor's movement list use one row: number, name and meta, a trailing grip, and a trailing trash. The grip is the drag source and every row in the same list is a drop target, so the list reorders as the row is moved. The card still opens its editor. The last block and the last movement keep no trash. Drag and delete disappear while editing is locked.
- **Red delete.** DELETE SESSION, DELETE BLOCK, REMOVE FROM BLOCK and the row trash use one destructive red: the red at reduced opacity at rest, the full red with a red-tinted capsule when armed, and the row's secondary line changes to `TAP AGAIN TO DELETE`. Arm one row at a time; any other delete tap moves the arm.
- A session never has zero blocks, a block never has zero movements, and the app never has zero sessions; the last delete action is not offered. Deletes are two-step: `DELETE` → `TAP AGAIN TO DELETE`.
- A block movement carries its own end condition and target; the library has no default to copy. SET DONE ends every set. TIME labels its target.
- The library lives **inside SESSIONS** as a `MOVEMENTS` entry, not as a third tab. The two-tab shell and its "switching tabs never changes the rest" contract stay intact.
- Library edits (name) do not reset the running session; they are not a plan change.
- Names trim and cap at 40 characters, and a pasted newline, carriage return, or tab becomes a space before the trim: empty session → `Untitled`, empty block → `Untitled block`, empty movement → `Untitled movement`. Names are single-line data.
- Long names: a SESSIONS card and a movement or pending row wrap to two lines; the timer header, block strip, position strip, expanded island, and Lock Screen rows stay on one line by scaling or truncating. A 40-character name must not move the ring or grow the 160-point panel.

## Navigation

Two persistent bottom tabs, `TIMER` and `SESSIONS`; TIMER is the default.

- `TIMER` shows the live session. `EDIT` opens the active session in SESSIONS and is hidden during a set or rest. A `↺` restart pill sits beside EDIT once at least one set is done, stays available while EDIT is hidden, and is absent in `done`, where START AGAIN is the primary action. Tapping it opens one confirmation dialog: `Restart this session?`, `This clears all completed sets, cancels the current rest, and returns to block 1, set 1.`, a destructive `Restart Session`, and `Cancel`. Cancelling changes nothing. Confirming applies the restart transition — the start gate at block 1, round 1, set 1, zero completed sets and no Live Activity. The dialog closes when the phase it was opened in changes, on leaving the timer, and when the restart control disappears. The session editor's `RESTART SESSION` opens the same dialog and keeps its flush and return-to-timer path.
- `SESSIONS` lists every session card (`name`, `n BLOCKS · n SETS · rest REST`, `ACTIVE` badge), then a `MOVEMENTS` card with the name-only library. The order is manual and persisted: each card has the same 44 × 44 grip as a plan row, drag and drop reorders the list, a new session appends at the end, and the order survives relaunch. The `ACTIVE` badge stays on its own card and is never pinned to the top. Reordering writes the order only: it never activates, edits, or resets a session, and the grip is disabled while editing is locked. VoiceOver offers `Move up` and `Move down` on the card. The add control opens the new-session editor on an unsaved draft; the card appears only after DONE or USE THIS SESSION. A session opens its ordered blocks; a block edits its rounds, sets per round, rests, and movements; a block movement opens its end condition and target. Blocks and movements reorder by their grip and delete from their row. The library opens the flat movement list and a movement detail for rename, usage, and delete; both return to SESSIONS.
- An island link opens the app on the TIMER tab and then applies its action. Launch and `onOpenURL` handling live at the root so they work from either tab.

## Chrome

On iOS 26 the timer's `EDIT` and restart pills and the SESSIONS add control render with Liquid Glass. On iOS 18 through 25 they keep the flat translucent capsule or circle. The material must not change an action, label, accessibility label, size, or hit area, and the restart keeps the same icon, accessibility label, and confirmation dialog with and without glass. Content stays flat: session cards, the countdown ring, the set map, primary buttons, editor fields, and the Live Activity do not use glass. The system tab bar, sheets, and menus keep the glass the system applies to them.

## Timer presentation

- **The ring does not move.** The countdown ring's centre is pinned to the timer viewport's vertical middle on every block, round, and phase. The block strip and position strip sit above it; the set map and actions sit below it at a fixed gap. A wrapping position strip or a taller map never moves the ring. The actions follow the set map directly. Content that does not fit makes the timer page scroll. If the top chrome and the ring cannot both fit, the ring is clamped below the chrome and the page scrolls.
- Multi-block sessions show a horizontally scrolling **block strip** under the header, auto-scrolled to the active block: completed blocks dim with a check, the active block is filled, future blocks are outlined. Hidden for one block.
- Not started: kicker `READY`, hero `START`, subtitle `n BLOCKS · n SETS · total rest TOTAL REST`, primary action `START SESSION` with `BLOCK 1 · first block name`. The block strip, position strip and block map preview block 1 set 1 with nothing completed. `SKIP REST` is hidden, and no Live Activity exists. `EDIT` stays available; the gate is not locked.
- The position strip reads `UP NEXT · movement · ROUND r OF R · SET s OF S` during a rest, and `block name · movement · ROUND r OF R · SET s OF S` when the plan has one block whose name adds something the movement name does not. With several blocks the block strip already names the active block, so the position strip carries only the movement and the round/set segments; the block name is never repeated in both. The block name is dropped when it equals the movement name, ignoring case and surrounding spaces. There is no `BLOCK n OF m` segment and no arrangement word. Hide the round segment when rounds is 1 and the set segment when sets per round is 1; a 1 × 1 block shows only the movement. The strip stays on one line at default sizes; at accessibility sizes it may wrap above the ring.
- The **block map** draws the active block only: one row per round of each movement in run order, one dot per set in that round, and a small gap between movements. It uses dots when `movements × rounds` ≤ 12, `setsPerRound` ≤ 12, and total dots ≤ 72; anything larger becomes a progress bar with `n OF m SETS IN THIS BLOCK`. Row labels are `R1`, `R2`, … restarted for each movement; the position line names the active movement. The caption above it stays `n OF m SETS` for the whole session.
- Ready: kicker is the upcoming rest kind, hero time is its duration, subtitle `AFTER THIS SET`; on the final set `LAST SET` / `FINISH` / `NO REST AFTER`; on a zero set rest `NO REST` / `NEXT` / `AFTER THIS SET`. The action is `START` with the hold for a timed set, otherwise `SET DONE` with the rest length.
- Performing: kicker `WORK`, the work countdown, and the rest that follows (`REST 1:00 AFTER`, or `NEXT SET IMMEDIATELY` for a zero set rest). The action is `SET DONE`; ending early starts the rest.
- Resting: kicker `SET REST` or `ROUND REST`, the countdown, and the context subtitle from the transition table; the action is `PAUSE` plus `SKIP REST`.
- Paused: kicker `PAUSED`, frozen countdown, action `RESUME` plus `SKIP REST`.
- Done: `DONE` with completed sets, `n BLOCKS · n MOVEMENTS · total rest TOTAL REST`, and `START AGAIN`. Entering done plays one celebration over the done screen: about 48 accent confetti pieces in the Restless green, amber and white, falling for 2.5 seconds. It is an overlay: it never blocks `START AGAIN`, changes no timing, and adds no sound, haptic, notification or Live Activity update. It plays once per completion, including one reached on another tab (on return) or through a store refresh, and never when a saved done session is restored at launch or revisited. With Reduce Motion it is a brief static accent glow with no moving pieces.
- Totals of an hour or more show hours: `18:00` below one hour, `1:02:00` above. Use a plural helper so one block never reads `1 BLOCKS`.

## Live Activity and Dynamic Island

Immutable attributes carry the plan itself: the session name and its ordered blocks, each with name, rounds, sets per round, set rest, round rest, and movements with end condition and target. Everything that moves is `ContentState`: `phase`, `doneSets`, `restKind`, `duration`, `deadline`, `pausedRemaining`, and `setDeadline` for a timed set. The timed set's duration comes from the plan's target. Compare the whole plan to decide whether to end and re-request the activity; compare content to decide whether to update it. Launch ends any stale activity and requests a new one only when the session is running.

No activity exists while the session is not started. Entering the gate ends any existing activity and requests none; `START SESSION` requests exactly one. A restart lands in the gate and ends the activity, so the next START SESSION requests a new one. At most one activity exists.

The widget builds a display-only snapshot from attributes + state and reuses the app's `kicker`, `subtitle`, `accentColor`, `currentPosition`, and `upcomingRest`. It must not carry its own position or rest maths.

Update the activity only on transitions — set done, start set, pause, resume, skip, rest finish, timed set finish, restart, completion — plus one update when the plan changes. Never push once per second. Countdowns render from their deadlines.

Island content by state:

| State | Leading | Trailing / centre | Bottom |
| --- | --- | --- | --- |
| not started | no activity | no activity | no activity |
| ready | active movement short label | next rest kind and duration, or `READY` | `BENCH PRESS · ROUND 2 OF 4 · SET 3 OF 4`; `NO REST AFTER` on the final set |
| performing | active movement short label | work countdown | `REST 1:00 AFTER` / `NEXT SET IMMEDIATELY` / `NO REST AFTER` |
| resting / paused | next movement short label | remaining time, progress bar | `AFTER SET 2` / `AFTER ROUND 3` / `NEXT · PUSHDOWN` / `NEXT · ARMS`, plus pause/resume and skip |
| done | `DONE` | total sets completed | total rest, blocks, movements |

A movement switch is a round rest: the kicker reads `ROUND REST`, the copy names the finished movement and the next, and the accent is the round-rest amber. `SET REST` never appears at a switch.

- Expanded: session name small, active block, active movement prominent, `ROUND r OF R` and `SET s OF S` (each hidden at a count of 1), timer trailing, controls at the bottom. During a rest one full-width line above the progress bar carries the rest context (`AFTER SET 2`, `AFTER ROUND 3`, `NEXT · TRICEPS`). The compact leading region gets a 3-character movement label (`BEN`), or `DONE`; compact trailing is the countdown, `READY`, or `DONE`. The full block and movement names live in the expanded and Lock Screen views.
- Controls are `Link`s to `restless://set-done`, `restless://start-set`, `restless://pause`, `restless://resume`, `restless://skip`, and `restless://restart`. The app applies the matching action in `onOpenURL` through `SessionTransitions.apply`. Set done during a rest is ignored; start set applies only to a ready timed set.
- Accent follows the rest or work kind, not the screen: set rest `#C8FF4D`, round rest and movement or block transition `#FFB84D`, work countdown `#C8FF4D` (it is not a rest), done `#C8FF4D`.

### Lock Screen panel

The Lock Screen and Notification Center panel fits 160 points, padding included, at every supported text size. It is built from three rows:

1. Header: the session name in `micro` above the movement name in `rowTitle` (one line), with the countdown trailing at 26 pt, scaled and capped at 32 pt.
2. State: one row pairing the phase kicker in its accent with one context string. Ready uses the upcoming rest kicker plus `SET s OF S`, or `ROUND r OF R` when sets per round is 1, or `AFTER THIS SET` when neither applies. Resting and paused use the kicker plus the rest context (`AFTER SET 5`, `AFTER ROUND 3`, `NEXT · PUSHDOWN`, `NEXT · ARMS`). Performing uses `WORK` plus the following rest (`REST 1:00 AFTER`). Done uses the completed-set kicker plus the session totals.
3. The progress bar during a rest or a timed set, then the same action links the island offers for that state.

There is no separate block-position row and no separate rest-context row. Every row is `lineLimit(1)` with a small `minimumScaleFactor`; padding is 14 pt and vertical spacing 8 pt. Dynamic Type is capped at `.xxLarge`, the largest size at which the whole panel fits; larger system sizes render at the cap. The panel must fit by layout, never by relying on the system's 160-point truncation. It shows `SESSION COMPLETE` with the completed-set total in done. The expanded and compact islands keep their fixed sizes and four-part leading region.

### Verifying a panel change

The panel only exists on the Lock Screen or in Notification Center, never in the
app, so every change to it needs the screen locked with a rest or set running.

- Lock the simulator with `l` in the Simulator menu:
  `osascript -e 'tell application "Simulator" to activate' -e 'delay 0.5' -e 'tell application "System Events" to keystroke "l" using command down'`.
  The Argent power button does not lock it.
- To expand the Dynamic Island, background the app first (Argent `button`
  `home`); a long press while the app is foreground does nothing. Then
  `gesture-custom` with Down on the pill centre, Up after ~900 ms. Tapping the
  expanded island opens the app.
- Change text size with `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`
  and reset with `content_size large`. Check both, because the cap has to hold
  at the largest system size.
- Screenshot with `xcrun simctl io <udid> screenshot /tmp/lock.png`; crop a
  region with `ffmpeg -i /tmp/lock.png -vf crop=w:h:x:y /tmp/crop.png`. There is
  no PIL, no numpy and no ImageMagick on this Mac; ffmpeg and ffprobe are the way
  to measure pixels.
- When the panel's height is in question, the system's own frame request is in
  the chrono activity archive name under
  `.../com.apple.chrono/activities/...-w:fix-374.00-h:dyn-64.00-160.00-...`;
  `xcrun simctl spawn <udid> log show --last 3m --predicate 'eventMessage CONTAINS "chrono/activities"'`
  surfaces it. It confirms the 160-point budget, not the rendered rows.
- `xcrun simctl launch --console-pty` waits for the app to exit and trips the
  30 s command timeout. Use `simctl launch`, then
  `simctl spawn <udid> log show --last 3m --predicate 'process == "Restless"'`.
- A stale activity can survive an install. Reboot the simulator
  (`simctl shutdown` then `boot`) before concluding the panel is wrong.

### Platform limits that decide the design

- A personal (free) Apple ID gets 7-day profiles. **App Groups are not configured**: `SessionStore` falls back to `.standard`, so the widget extension cannot read the app's session and an App Intent button in the island would only repaint the island while the app kept the old state. Apple lists App Groups as available to free accounts, but this project has not tested provisioning one; do not repeat the old "free team cannot use App Groups" claim without a clean build.
- Tapping the compact island opens the app. It cannot run an action, and compact/minimal regions cannot hold buttons.
- Current approach: island controls are `Link`s. If an App Group is provisioned for both targets, switch the links to `LiveActivityIntent` buttons so the action no longer opens the app.
- Completion alerts use one local notification with the system sound when the app is in the background. In-app completion is haptic only; Restless adds no custom audio asset and schedules no system alarm.
- The local notification is the one background alert. The app does not depend on background execution: the system delivers the notification whether the app is still executing or suspended, and mirrors it to the paired watch.

## Watch remote

The watch is a control surface for the running session, never a second copy of it.

- **No clock.** The wrist shows the phase, the movement, the round and set position, and one continuous progress bar for the current block filled to that block's completed sets. The block's own count sits large above the bar (`5 / 16 · SETS IN THIS BLOCK`) and the session count below it (`5 OF 24 SETS`). Every block size uses the same bar; there is no dot map, no dot cap and no alternate form. It shows no countdown, no remaining time, no progress ring and no value that changes as time passes. The paused screen does not tick either. One display-only wake at the published deadline may flip the phase (a finished rest becomes ready) while the phone is suspended; it shows no time and sends nothing.
- **Same actions, same words.** The labelled button is the snapshot's `primaryTitle` with `primaryAction`: `START SESSION`, `START`, `SET DONE`, `PAUSE`, `RESUME`, `START AGAIN`. A running rest adds one skip glyph; a paused rest does not. The watch invents no copy and no order.
- **One message per tap.** A tap sends `WatchActionMessage` (id, action, tap time). The phone applies it through `SessionTransitions.apply` at the tap instant, then reconciles to the present, so delivery delay does not move a deadline. A tap more than five seconds in the future is clamped to arrival; an id already applied is dropped.
- **Fed, not synced.** The phone publishes the snapshot, the active preset and the movement names as the WatchConnectivity application context on launch, on every session change and when the wrist becomes reachable. It also returns the post-transition session in the reply to every tap, and falls back to a direct message when the system refuses the context update (a stale `isWatchAppInstalled` state does this even while taps arrive). The newest value replaces the previous one. An unstartable plan publishes nothing, and the wrist reads `NO SESSION` / `OPEN RESTLESS ON YOUR PHONE` with no control.
- **Display-only reconciliation.** A published rest or work deadline that passed while the wrist was down selects the phase to show; the result is never sent back and never counts as a completed set.
- **A tap that cannot be delivered is lost.** There is no queue: the wrist shows `NOT SENT · TRY AGAIN` and leaves its screen unchanged. A force-quit phone cannot be woken.
- **No alert of its own.** The wrist plays no haptic, sound or notification for a deadline and requests no notification permission. It is the phone's one haptic or one mirrored local notification. Tapping that notification opens the watch app on the current phase and performs no action.
- **No runtime session.** No `HKWorkoutSession`, no extended runtime session, no standalone watch session, no complication or Smart Stack widget, no countdown notifications, no HealthKit. The target compiles only `WorkoutPreset`, `WorkoutBlock`, `SessionSnapshot`, `Theme` and `WatchRemote` from `Shared/`; `RestlessActivity` is excluded because ActivityKit is unavailable on watchOS.
- **Verification.** Build `RestlessWatch` and launch a fixture on the 42 mm and 46 mm watch simulators. A 5 / 16 block reads `5 / 16 · SETS IN THIS BLOCK` above the bar and `5 OF 24 SETS` below it; a block of a thousand sets uses the same bar with no dots; a done session shows a full bar. The action row stays visible.

## Completion alerts

A rest or timed work countdown that reaches zero raises exactly one alert. It
never completes a set, skips a rest, or creates a second transition; the
deadline reconciliation is the only state change.

- **Foreground:** one phone haptic (`UINotificationFeedbackGenerator` success). No banner, no sound, no island expansion, and no app-level watch message. The haptic must not change the phase or the completed sets.
- **Background:** one local notification scheduled when the app moves to the
  background. It is left pending at the deadline, even if the app is still
  executing, so the system delivers exactly one notification. iOS mirrors it to
  a paired watch, which plays the notification haptic; the app sends no second
  alert. The app does not depend on background execution and sends no alerting
  Live Activity update. No system alarm is scheduled.
- **Island:** the Live Activity stays a state display. The app updates it on
  transitions while it is executing, but it never carries an alert
  configuration and does not expand as part of the alert.
- **Suspended stale activity:** a suspended app cannot rewrite the activity, so
  the minimal island can sit at `0:00` after the deadline until the app opens.
  The notification is the notice; opening it reconciles the activity to `READY`
  or `DONE`. Do not treat the `0:00` as a new session state.
- **Copy:** one pure `CompletionAlertCopy` builds the title and body from the
  post-transition snapshot: `SET REST OVER`, `ROUND REST OVER`, or
  `WORK SET OVER`, then what finished (`AFTER SET 2`, `AFTER ROUND 2`,
  `AFTER CURL · NEXT PUSHDOWN`, `AFTER CHEST · NEXT ARMS`) and what follows
  (`NEXT ROUND 2 OF 4 · NEXT SET 1 OF 4`). A final set reads `SESSION COMPLETE`
  with the set, block, and total-rest totals. The notification and the timer
  use the same strings.
- **Cancellation:** pause, resume (arm again for the resumed deadline), skip,
  restart, plan change, a zero set rest, an early SET DONE, and a launch after an
  expired deadline all cancel pending alerts. A notification whose deadline is
  reached in the background is not cancelled. Per-deadline identifiers let a
  following countdown be armed without removing the request that is due now.
- **Permission:** notification permission is requested when the first countdown
  is armed. Denial is survivable: no background alert, and the session and timer
  keep working. The prompt is not repeated.
- The pending notification is cancelled before the foreground haptic, so a
  deadline never alerts twice.

## Persistence

Sessions persist locally in SwiftData. The record keeps the legacy single-part columns and stores the ordered blocks as JSON in an optional `blocksData`; a nil `blocksData` reads `partsData` as one block per part (`rounds`, `setsPerRound`, one manual movement), or the legacy columns as one block. Writing encodes `rounds` and `setsPerRound` and mirrors the first block as `(rounds, movements × setsPerRound)` into the legacy columns so an older build still sees the same total sets in its single part. `partsData` stays nil after a write. No explicit migration plan and no entity rename.

Movements persist as their own `MovementRecord` rows: an id and a name. The legacy muscle-group, default-condition, and profile columns remain for store compatibility but are never read or written. A block movement stores only the library id, end condition, and target. A used movement cannot be deleted.

Migration rule: each stored part `R rounds × S sets`, set rest `a`, round rest `b` becomes **one block with rounds R, sets per round S, one manual movement**, name preserved, set rest `a`, round rest `b`. This preserves the old part's total sets and round-rest rhythm. A legacy straight block with count `C` becomes rounds 1, sets per round `C`; if it has several movements it splits into one block per movement, in order, each keeping the old name and rests. A legacy circuit with count `C` becomes rounds `C`, sets per round 1. Adjacent duplicate circuit movements with the same library movement, end condition, and target collapse into one movement with sets per round equal to the duplicate count when every run is the same length; otherwise the duplicates stay separate. New `rounds`/`setsPerRound` keys win on read; `kind`/`count` are read only for migration. The prototype demonstrates the block model with richer demo data; the app fallback above is the seed.

A stored end condition of `reps`, or any other value the app no longer offers, decodes as `manual` with no target. Decoding never throws on an unknown condition: a throw would drop a saved block and could return the whole plan to the seed. The bridge covers `PresetRecord.blocksData`, the legacy part columns, and a saved `SessionSnapshot`.

A missing or unreadable stored plan falls back to the seeded `Chest` block. A block movement whose library entry is missing is dropped on read; a block left with no movements is dropped; a session left with no blocks falls back to the seed.

## Copy

Keep the prototype's words. Timer and island: `START SESSION`, `SET DONE`, `START`, `WORK`, `PAUSE`, `RESUME`, `SKIP REST`, `START AGAIN`, `READY`, `DONE`, `SESSION COMPLETE`, `SET REST`, `ROUND REST`, `PAUSED`, `NO REST`, `NEXT`, `NEXT SET IMMEDIATELY`, `AFTER THIS SET`, `AFTER SET n`, `AFTER ROUND n`, `NEXT · INCLINE PRESS`, `NEXT · ARMS`, `LAST SET`, `FINISH`, `NO REST AFTER`, `Finish session`, `Restart this session?`, `Restart Session`, `Cancel`, `SET REST OVER`, `ROUND REST OVER`, `WORK SET OVER`, `SESSION COMPLETE`, `UP NEXT`, `SETS IN THIS BLOCK`, `SETS`, `HOLD`.

Blocks and movements: `BLOCKS`, `ROUNDS`, `SETS PER ROUND`, `SETS EACH`, `MOVEMENTS`, `END CONDITION`, `TARGET`, `TIME`, `MANUAL`, `DELETE MOVEMENT`, `USED BY CHEST · REMOVE IT FROM THE PLAN FIRST`. Block rows and summaries are numeric: `2 MOVEMENTS · 2 ROUNDS · 1 SET EACH · 4 SETS`, `1 MOVEMENT · 4 ROUNDS · 4 SETS EACH · 16 SETS`. The app never assigns a straight, superset, or circuit label; a user may still type one as a block name.

Navigation and editing: `TIMER`, `SESSIONS`, `WORKOUTS`, `ACTIVE`, `ACTIVE SESSION`, `USE THIS SESSION`, `RESTART SESSION`, `EDITING THIS SESSION RESTARTS IT.`, `ADD A MOVEMENT TO SAVE THIS SESSION.`, `EDIT`, `ADD BLOCK`, `ADD FROM LIBRARY`, `DELETE BLOCK`, `ADD MOVEMENT`, `TO ADD`, `REMOVE FROM BLOCK`, `TAP AGAIN TO DELETE`, `DELETE SESSION`, `EDITING LOCKED DURING A SET OR REST · SWITCH TO TIMER TO SET DONE OR PAUSE`, `Untitled`, `Untitled block`, `Untitled movement`, `New session`.

The grip is an icon, not copy. VoiceOver reads the row actions as `Move up`, `Move down`, and `Delete`; those labels never appear on screen. The row delete, DELETE SESSION, DELETE BLOCK, and REMOVE FROM BLOCK use the destructive red; `TAP AGAIN TO DELETE` is the armed state.

Watch remote: `NO SESSION`, `OPEN RESTLESS ON YOUR PHONE`, `NOT SENT · TRY AGAIN`.

Retired words: `PART`, `PARTS`, `PART n OF m`, `SETS PER MOVEMENT`, `SETS IN THIS PART`, `ADD PART`, `DELETE PART`, `Untitled part`, `New part`, `NEW BLOCK`, `EDITING LOCKED DURING REST · SWITCH TO TIMER TO PAUSE OR SKIP`, the old arrangement labels, and the recording vocabulary: `REPS`, `WATCH ARMED`, `WATCH UNAVAILABLE`, `PROFILE`, `NO PROFILE`, `RECORD MOVEMENT`, `RE-RECORD ON WATCH`, `START RECORDING`, `TRACE RECEIVED`.

The timer's last-set primary action is `SET DONE`, not `FINISH SESSION`; the island uses `Finish session` only as its action label.

## Tests worth writing

- `rest(after:)` for every position in 4 × 4 (one movement), 2 movements × 3 rounds × 2 sets, 2 movements × 2 rounds × 1 set, a one-round block with N sets, and N rounds × 1 set — the degenerate shapes are where the round-rest branch usually breaks.
- A 4 × 4 block: 16 sets and 1080 s at 60/120 (12 set rests + 3 round rests); set rest after sets 1–3, round rest after set 4.
- A 2 × 3 × 2 block (two movements, three rounds, two sets each, 60/120): 12 sets and 960 s (6 set rests + 5 round rests); sets 1–6 all belong to the first movement and set 6 is a round rest named `NEXT · TRICEPS`; set 7 is the second movement's round 1 set 1.
- A 2 × 2 × 1 block at 30/120: 4 sets and 360 s (0 set rests, 3 round rests); every rest is a round rest.
- A 1 × 3 block at 60/0: 3 sets and 120 s of set rest, no round rest.
- A movement switch is a round rest over the block's round rest and names both movements; a round rest between rounds of one movement is `AFTER ROUND n`; a block transition names both blocks and gets the block's round rest; the final set has no rest.
- A zero set rest starts no rest state and lands ready at the next set of the same movement; the total rest excludes it.
- `totalRest` across the parts example: Biceps 3 × 3 (60/120) then Triceps 2 × 4 (45/90) = 17 sets and 1080 s; a 40 × 25 block totals 1000 sets without overflow.
- Position at every block, movement, round, and set boundary, including the last-set clamp; the map draws one row per round of each movement with a gap between movements and falls back to the bar above 12 rows, 12 sets per row, or 72 dots.
- Watch progress: the current block's done-in-block count is 5 for 5 of 16, 0 at the gate, the block total at done, and clamped at both ends; a 1000-set block uses the same bar with no dots; a movement switch keeps the block count.
- Copy: `ROUND r OF R · SET s OF S`, `ROUND r OF R` alone, `SET s OF S` alone, and no segment at 1 × 1.
- Start set only for a timed set; the work countdown expires into the same rest; SET DONE early starts the rest; a timed set is never paused; pause/resume are rest-only.
- The gate: a fresh snapshot is not started; START SESSION reaches block 1 set 1 without counting; set done and a second START SESSION in the gate or ready state are ignored; activating a session or committing an active-plan edit returns to the gate; RESTART SESSION and the timer's restart also land at the gate with zero sets and no activity.
- Draggable lists: move a block and a movement up and down, delete one from the row, refuse to delete the last block or movement, and disable both while editing is locked.
- Staged blocks: a new block starts as `Untitled block` with rounds 1, sets per round 3, the previous block's rests, and no movements; editing it, adding movements, and reordering them leave `session.blocks` unchanged and do not dirty the draft; DONE rejects zero movements; DONE appends the block and flushes once; back or cancel discards it; a two-movement staged block keeps its one round.
- Timer hero: the ring centre is the same y for a one-row and a three-row map, for a one-line and a two-line position strip, and when a rest starts and ends; a map taller than the viewport keeps the ring centred on first display and scrolls; a short viewport clamps the ring below the chrome.
- Set done twice in a row consumes one set, not two — including across a movement or block boundary; set done during a rest is ignored; start set twice does not restart the countdown.
- Pause for longer than the remaining time, then resume: remaining is unchanged and the deadline moves. A rest that expires while the app is inactive reconciles to ready; a timed set that expires while inactive reconciles to its rest.
- Editing locks during performing, resting, and paused; SESSIONS is read-only with the banner; switching tabs does not change the set or rest; editing the active plan resets, editing another session does not.
- End conditions: only MANUAL and TIME are offered; a stored `reps` row decodes as MANUAL with no target; any unknown condition decodes as MANUAL; a saved plan and a saved snapshot keep every block, movement, round, set, rest, and order.
- Restart: `canRestart` is true in ready, performing, resting and paused once a set is done, and false in notStarted and done; tapping opens the dialog without changing the snapshot; cancelling leaves the phase and completed sets untouched; confirming lands in the start gate at block 1 set 1 with zero sets and no activity; a phase change and leaving the timer close the dialog; restart during a rest clears the rest. The editor's RESTART SESSION shows the same dialog and returns to the gate.
- Position strip: multi-block ready and resting carry no block name; a single block names itself only when its name differs from the movement; a block and movement with the same name produce one segment; resting prefixes `UP NEXT`; rounds > 1 gives the round segment, sets per round > 1 the set segment, and 1 × 1 gives neither. No `BLOCK n OF m` anywhere.
- Library add: one tap appends a MANUAL movement with no target to a saved block and to a staged block, flushes once, and leaves ROUNDS unchanged on the second movement; the rows exclude used movements, disappear while locked, and a staged append leaves `session.blocks` unchanged until DONE.
- Lock Screen panel: the state row reads `SET REST · AFTER SET 5`, `ROUND REST · AFTER ROUND 3`, `WORK · REST 1:00 AFTER`, `PAUSED · AFTER SET 5`, and ready's `SET REST · SET 5 OF 8`; the panel has no separate position or rest row; it fits 160 points with a 40-character movement at default, XXL and xxLarge text sizes and caps there for accessibility sizes.
- Migration: a legacy `partsData` record with `R × S` reads as one block with rounds R and sets per round S, one manual movement, and the old rests; a legacy straight count C reads as rounds 1 and sets per round C, and a straight block with several movements splits into one block per movement; a legacy circuit count C reads as rounds C and sets per round 1; four adjacent duplicate circuit rows collapse to one movement with sets per round 4; a `blocksData` JSON round-trip preserves block and movement ids; the active session id survives.
- Store: a v4 snapshot is discarded and the gate opens; a v5 snapshot keeps its phase.
- Live Activity: attributes carry every block and movement; a plan change ends the old activity and requests a new one; no activity exists before the start and entering the gate ends a stale one; content updates only on transitions; the start-set link starts a ready timed set; set done during rest is ignored.
