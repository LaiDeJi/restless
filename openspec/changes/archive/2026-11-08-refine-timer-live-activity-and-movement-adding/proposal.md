# Proposal

## Why

The timer repeats the active block in both the chip and the strip, and offers no
way to abandon a running session without walking into SESSIONS. The Lock Screen
activity is taller than Apple's 160-point cap, so the system cuts off its
controls. Adding the usual single movement to a block costs a sheet, a queue and
two DONE taps, and the floating controls ignore the Liquid Glass that the system
tab bar already uses.

## What Changes

- **RESTART on TIMER.** A `↺` pill sits beside EDIT once at least one set is
  done. The first tap arms it (`TAP AGAIN`, amber), the second applies the
  existing restart transition: ready at block 1, set 1, zero completed sets. It
  is hidden before the first set and in done, where START AGAIN already exists,
  and stays available during a set or rest because it is a session action, not
  an edit. Arming clears when the phase changes.
- **One-line position strip.** Drop `BLOCK n OF m` and the block name when the
  block strip already names the block, and drop a block name equal to the
  movement name. The strip reads `MOVEMENT · ROUND r OF R · SET s OF S`, with
  `UP NEXT` during a rest. This removes the second line that appears during
  rests and at narrow widths.
- **Lock Screen panel fits 160 pt.** Rebuild the panel around three text rows:
  the session name and the movement name (one line each) with the countdown on
  the right; one state row (`SET REST · AFTER SET 5`, `SET REST · SET 5 OF 8`,
  `WORK · REST 1:00 AFTER`); then progress and controls. The extra position and
  rest rows are removed, not shortened. Dynamic Type is capped at `.xxLarge`,
  the largest size that still fits. The island layout and the activity's colours
  do not change.
- **One-tap movement add in the block editor.** A new `ADD FROM LIBRARY` list
  under the block's movements lists recorded movements not already in the
  block. Tapping one appends it with MANUAL and no target, in one draft edit,
  and flushes. The list is hidden while editing is locked and is absent when
  every library movement is already used. The add-movement sheet stays for
  several movements, custom ends, and typed names. The new-block flow gains the
  same path, so a single-movement block is `ADD BLOCK` → tap a movement →
  `DONE`.
- **Liquid Glass on floating controls only.** EDIT, the new restart pill and the
  SESSIONS add button adopt iOS 26 Liquid Glass behind
  `#available(iOS 26.0, *)`; iOS 18–25 keeps today's flat translucent capsule.
  Cards, the ring, the set map, primary buttons and the island stay flat, per
  Apple's "use sparingly, not in the content layer". The system tab bar and
  sheets already take glass. The deployment target stays iOS 18.
- **Prototype first.** The timer reset, the strip copy, the inline library and
  the glass pills land in `prototype-workout-timer.html` before the skill and
  the code. The Lock Screen panel is not in the prototype; it lands in the
  widget.

## Capabilities

### New Capabilities

- `app-chrome`: how the app's floating navigation and action controls are
  drawn, including the iOS 26 Liquid Glass treatment and the flat fallback.

### Modified Capabilities

- `rest-timer`: the running timer gains a two-tap restart control, and its
  position strip stops repeating the active block.
- `live-activity`: the Lock Screen panel gets a defined content hierarchy and a
  160-point height budget it must fit.
- `workout-sessions`: the block editor gains a one-tap library add, including
  for a staged new block.
- `app-typography`: the Lock Screen Dynamic Type cap changes from
  accessibility1 to xxLarge so the panel never clips.

## Impact

Touched: `prototype-workout-timer.html`,
`.agents/skills/restless-rest-timer/SKILL.md`, `Restless/UI/TimerScreen.swift`,
`Restless/UI/TimerPositionStrip.swift`, `Restless/UI/PlanChrome.swift` plus a
glass modifier, `Restless/UI/BlockEditorScreen.swift`,
`Restless/Session/SessionDraftStore.swift` for a target-aware single append, and
`RestlessWidget/RestlessLiveActivity.swift`. Tests cover the restart control, the
strip copy, the single append and the staged block, and the Live Activity copy.
No store format change, no new session transition (restart reuses `.restart`),
no new dependency. iOS 18 remains supported. Live Activity attributes and
content state are unchanged.
