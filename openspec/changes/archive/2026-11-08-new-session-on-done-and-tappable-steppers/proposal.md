# Proposal

## Why

Two controls in the session editor do not do what the user asks. Tapping `+` on
SESSIONS inserts a new session immediately, so backing out of the editor leaves
a `New session` card the user did not commit; a session should exist only after
DONE. On the BLOCK page, the minus works but the plus does nothing when its
visible center is tapped: only a narrow strip at the leading edge of each chip
responds. The same hit-area fault affects the top-right DONE action (only its
left edge fires) and the end-condition segments. The value cannot be raised
reliably, and even a correctly built draft cannot be committed with DONE.

## What Changes

- **A new session is a draft until DONE.** Tapping `+` opens the session editor
  on an unsaved draft. SESSIONS keeps showing the old list, and the active
  session and timer are untouched. DONE at the top-right creates the session
  with the edited name, blocks, and values, saves it once, and returns to the
  list. The back action and a swipe back discard the draft without creating a
  record. USE THIS SESSION is the explicit commit-and-activate path. The default
  name gets its unique suffix at creation time, not when `+` is tapped.
- **Steppers change on a center tap and repeat on hold.** The minus and plus
  become full-size controls: the whole visible chip is the tap target, not an
  inner image or a strip at its edge. A tap changes the value once; holding for
  about half a second repeats the change about ten times a second until release,
  so 1 to 40 rounds or 60 to 600 seconds no longer needs dozens of separate
  taps. Each repeat still updates the in-memory draft only; the debounced save
  runs once after the hold ends.
- **DONE and the end-condition control take a center tap.** The header actions
  and the MANUAL/TIME/REPS segments use the same full-surface treatment. A tap
  on the visible pill or segment selects it, not only a tap on its leading
  padding or text.
- **Prototype first.** The draft-until-DONE flow and the press-and-hold
  steppers land in `prototype-workout-timer.html` before the skill and the app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: creating a session becomes a draft committed by DONE or
  USE THIS SESSION and discarded by back; steppers respond across their whole
  visible control and repeat while held; DONE commits the draft.
- `app-typography`: the 44 × 44 pt minimum becomes a real, continuous tap target
  for steppers, header actions, and the end-condition segments, not a narrow
  leading strip.

## Impact

Touched: `prototype-workout-timer.html`,
`.agents/skills/restless-rest-timer/SKILL.md`,
`Restless/UI/SessionsScreen.swift`, `Restless/UI/SessionEditorScreen.swift`,
`Restless/App/AppRouter.swift`, `Restless/UI/MovementComponents.swift`, and
`Restless/UI/BlockMovementEditorScreen.swift`. `SessionDraftStore` gains a
no-persist draft mode or reuses its optional commit. Tests cover draft
creation/discard/commit, unique naming at commit, and the repeat behaviour; an
Argent e2e taps the visual center of every stepper, DONE, and a segment. No
store format change; existing sessions stay readable and the active session is
never reset by opening or discarding a draft.
