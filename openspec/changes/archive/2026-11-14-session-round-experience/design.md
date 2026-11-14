# Design

## Context

See `proposal.md` for the motivation and the three spec deltas for the required
behaviour. The current code shapes the approach:

- `NewSessionDraft.make(from:)` copies the active session's first block,
  movements included. `WorkoutPreset.clamped()` replaces a block with no
  movements with `.fallback`, which carries a Chest movement, so saving an empty
  draft today would silently create the wrong session.
- `TrainingRotation` projects with `step = restDaysBetween + 1`: every slot is a
  session day and the rest gap sits between two sessions.
- `SessionTransitions.apply` is the only session mutation path. The engine calls
  it from a tap, a deadline, and a store refresh; nothing exposes the transition
  into `done` to the UI.
- `TimerScreen` owns the timer's view state. The widget, history and alerts read
  `SessionSnapshot`, which stays pure Foundation.
- The prototype is the visual and copy reference and changes first. Swift is
  Swift 6 with complete strict concurrency; `Shared/` stays free of SwiftUI
  except `Theme.swift`.

## Goals / Non-Goals

**Goals:**

- A new session opens with one movement-less block and cannot be committed
  until a movement is added.
- The calendar gap means rest days after a complete pass through the SESSIONS
  order, with the sessions inside the pass on consecutive days.
- A completed session plays one short, non-blocking celebration on the timer,
  including when the completion happened on another tab or in the background.

**Non-Goals:**

- No stored-document or SwiftData migration. `restDaysBetween` keeps its key,
  its 0–6 range and its value.
- No change to block rounds, set counting, rest selection, alerts, history or
  the Live Activity.
- No celebration in the Dynamic Island or Lock Screen, no audio, no extra
  haptic and no notification.
- No second session-ending path and no new library movement defaults.

## Decisions

### A new session is a valid draft only with a movement

`NewSessionDraft.make(from:)` builds one block with a fresh id, the name
`Untitled block`, zero movements, and the schedule fields copied from the
active block when one exists (otherwise `WorkoutBlock()` defaults). It does not
use `.fallback`, because the fallback exists to keep decoded plans runnable and
carries a movement.

`WorkoutPreset` gains a `canCommit` check: every block has at least one
movement. `SessionEditorScreen` disables DONE and USE THIS SESSION for a draft
that fails it and shows a short line such as `ADD A MOVEMENT TO SAVE THIS
SESSION.` when the draft has no runnable block. `SessionDraftCommit.save`
returns an optional and refuses the same invalid draft, so the guard does not
depend on one button.

`WorkoutPreset.clamped()` keeps its fallback for decoding and migration. The
difference is deliberate: a stored broken plan still opens as a usable session,
while a user-authored empty draft is refused instead of being replaced with
Chest.

Alternative considered: allow saving an empty block. Rejected because the timer
would have zero sets, `rest(after:)` would be nil, and the session would enter
`done` immediately.

### Round arithmetic replaces the fixed slot step

For `N = sessions.count` and `G = restDaysBetween`, the round length is
`N + G`. From the anchor offset:

```
roundIndex = offset / (N + G)
dayInRound = offset % (N + G)
session day when dayInRound < N
session index = dayInRound
global slot = roundIndex * N + dayInRound
```

The global slot keeps the existing "a closed or skipped session day consumes
its session" rule: the session index comes from the day's position in the
round, not from the number of open days before it. Rest days have no slot, so
they consume nothing. `scheduledPlan` takes `sessions[slot % N]`, which is
`sessions[dayInRound]`.

The rest of `TrainingRotation` keeps its current shape: `mark` still resolves
exception, skip, boundary, rest, plan in that order; `nextUnstartedDay` still
walks forward to the first open session day; `restartRotation` and
`startNewRound` still write the anchor. `CalendarSettings` is untouched.

Empty `sessions` returns no slot before any division, and `mark` returns
`.none` rather than `.rest`, matching the existing empty-order behaviour.

Copy changes in `CalendarCopy`: the row line becomes `BETWEEN ROUNDS`, the gap
summary becomes `N REST DAYS BETWEEN ROUNDS`, and the zero case stays `SESSIONS
EVERY DAY`, which remains true. The stepper's accessibility labels name rounds.
The prototype's `cadenceStep`, `isSessionSlot`, `slotNumber` and
`scheduledPlanForKey` mirror the same arithmetic; its calendar driver is
updated to assert the new dates.

Alternative considered: keep one session every `G + 1` days but label the gap
"between rounds" when it really means between sessions. Rejected because the
user-facing meaning would still be wrong.

### Completion is an engine event, not persisted state

`SessionEngine` gains a `completionEvent` counter. `perform`,
`performDeadline` and `refreshFromStore` record whether the phase was `done`
before the transition and increment the counter only when it becomes `done`.
Initialisation, `use` and `restart` never increment it, so a done snapshot
restored at launch does not replay the effect.

`TimerScreen` watches the counter. If TIMER is visible it starts the
celebration; otherwise it stores a pending flag and starts it when the tab
becomes visible. On appear it treats a counter newer than the one it last saw as
pending, so a view rebuilt while the user was on another tab still celebrates
once. The flag is view state, not persisted session data.

Alternative considered: derive the trigger from `snapshot.phase` in the view.
Rejected because SwiftUI can recreate the view, `onChange` does not fire for a
state already present, and a restored done session would replay the effect.

### The celebration is an overlay drawn by Canvas

A new `SessionCelebration` view in `Restless/UI/` draws the effect in a
`TimelineView(.animation)` + `Canvas` above the timer content. It does not enter
`Shared` and does not change layout. About 48 small rotated rectangles start
near the done hero, receive a radial initial velocity, fall under gravity, spin,
and fade over the last part of a 2.5-second run. Colours come from
`Theme.setAccent`, `Theme.roundAccent` and white; no red.

The overlay is `allowsHitTesting(false)` and `accessibilityHidden(true)`. The
done screen already says `SESSION COMPLETE`; the effect must not move focus or
add a VoiceOver announcement. It adds no haptic, sound or notification, and the
Live Activity is untouched. `TimerScreen` removes the overlay after 2.5 seconds
or when the phase leaves `done`; a task cancellation handles a restart during
the effect.

With Reduce Motion, the same component draws a static radial accent glow behind
the hero and fades its opacity once, with no particle movement. The prototype
uses CSS particles and a `prefers-reduced-motion` static state, with a
per-completion flag so its frequent renders do not restart the burst.

Alternative considered: a full-screen modal or a separate completion screen.
Rejected because it would interrupt START AGAIN and change the established done
layout.

## Risks / Trade-offs

- **An empty draft could reach the store through another path.** → Guard in both
  the editor actions and `SessionDraftCommit.save`; add a commit test with an
  empty draft.
- **The gap change alters existing users' schedules.** A stored gap of 1 now
  compresses the round and removes the between-session rest days. → No data
  migration is possible or needed because the value is still valid; call it out
  in the change and verify the projected dates in tests.
- **`N + G` division by zero when the order is empty.** → Return no slot when
  `sessions` is empty before computing the round length; keep the existing
  empty-order test.
- **The word "round" also means rounds inside a block.** → In CALENDAR the word
  has one meaning, matching the existing NEW ROUND action and day-sheet copy;
  the timer's block rounds are untouched.
- **A 60 fps Canvas could cost CPU during the effect.** → Draw only for 2.5 s,
  keep the particle count around 48, and let `TimelineView` stop when the
  overlay is removed.
- **A completion on another tab or in the background could be missed.** → The
  counter plus pending flag and the on-appear comparison cover tab switches,
  view recreation and foreground reconciliation.
- **Canvas particles at accessibility text sizes.** → The overlay is
  non-textual and absolute; it must not affect layout at any Dynamic Type size.

## Migration Plan

No stored data changes. The calendar document keeps `restDaysBetween` and its
0–6 clamp; SwiftData and the session snapshot are untouched. Deploy by updating
the prototype, the skill and `AGENTS.md` rule 12, then the Swift and tests.
Rollback is a code revert; stored documents remain readable by both versions.

## Open Questions

None.
