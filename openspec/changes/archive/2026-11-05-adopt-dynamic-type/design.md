# Design

## Context

See `proposal.md` for motivation. The constraints that shape this design:

- SwiftUI, iOS 18, one 430 pt-wide reference frame. `prototype-workout-timer.html` is the visual reference at 430 × 880, where 1 px = 1 pt, and is silent on Dynamic Type.
- Every size is a fixed `.font(.system(size:))`: 7–11.5 pt for labels, 13 pt for the largest metadata, 24–28 pt for titles. Several labels also shrink to fit (`minimumScaleFactor`), which defeats the text size setting.
- `Shared/Theme.swift` is the only SwiftUI file in `Shared/`. The app and the widget compile all of `Shared/`, and the watch target compiles `Theme.swift` on its own, so the type tokens must stay to `Font` and `Color` with no iOS-only API.
- The timer is pinned by a `GeometryReader`: header, part strip, position strip, spacers, a 320 pt hero circle, the set map, and a bottom action row. The hero side is `min(320, width - 44, height * 0.42)`.
- The Lock Screen panel has a fixed height; the Dynamic Island ignores Dynamic Type and has fixed regions.
- No UI test target. Verification is `xcodebuild test` plus Argent UI passes on the simulator at several text sizes.

## Goals / Non-Goals

**Goals:**

- One role-based type scale shared by every app screen and the widget, so the same kind of text gets the same style everywhere.
- Full Dynamic Type support on the app screens; bounded scaling on surfaces with fixed geometry (hero ring, Lock Screen panel, Dynamic Island).
- A visible hierarchy: titles, section headings, content and meta are distinguishable at a glance.
- Readable at the default size (nothing below 11 pt) and intact at accessibility sizes (wrap/scroll, no shrink-to-fit).
- 44 pt tap targets.

**Non-Goals:**

- Changing colours, the circle, the dot map, uppercase branding, or the tab bar.
- Changing copy, timer behaviour, persistence or the island actions.
- Custom fonts, iPad/Mac layouts, or landing-page chrome.
- Adding a UI test target or snapshot infrastructure.

## Decisions

### D1. Semantic styles behind named roles

Add `Theme.TypeScale` in `Shared/Theme.swift` with static `Font` values. Screens use a role, never a point size.

| Role | Style at default | Default pt | Used for |
| --- | --- | --- | --- |
| `screenTitle` | `.largeTitle.weight(.semibold)` | 34 | SESSIONS page title |
| `pageTitle` | `.title.weight(.semibold)` | 28 | editable session/part name |
| `section` | `.footnote.weight(.semibold)` | 13 | eyebrows, SESSION/PARTS kickers, uppercase session header |
| `rowTitle` | `.headline.weight(.semibold)` | 17 | card name, part row name, widget part name |
| `value` | `.title3.weight(.semibold)` | 20 | stepper values |
| `body` | `.subheadline` | 15 | summaries, back/Done, explanatory copy |
| `meta` | `.footnote` | 13 | card/part meta, subtitles, badges, footer copy |
| `label` | `.caption.weight(.semibold)` | 12 | timer kicker, position strip, chips |
| `micro` | `.caption2.weight(.semibold)` | 11 | set-map labels, progress counts, ACTIVE badge |
| `action` | `.headline.weight(.bold)` | 17 | primary buttons |
| `compactAction` | `.footnote.weight(.semibold)` | 13 | EDIT, back, DONE, add/delete |

Rationale: semantic styles carry Apple's metrics and scale automatically; roles keep the same style across the timer, list and editors, and give the design one place to change. Alternatives rejected: fixed sizes with `@ScaledMetric` per site (repeats the maths and drifts), `UIFont.preferredFont` (UIKit, breaks the watch compile).

`Theme` keeps importing only SwiftUI. No new files, so `xcodegen` is not required.

### D2. Hierarchy per screen

The numbers below are the default-size targets; the semantic style supplies the scaled value. "Now" is the current fixed size.

**Timer**

| Element | Now | New |
| --- | --- | --- |
| Session name | 11 semibold, tracking 1.8 | `section` 13, tracking 1.2 |
| EDIT | 9 semibold, ~25 pt tall | `compactAction` 13, 44 pt tall |
| Part chip | 8.5 bold, tracking 1 | `label` 12, tracking 0.8, 32 pt min height |
| Position strip | 9 semibold, one line | `label` 12, tracking 0.8, wraps to two lines |
| Kicker | 10 bold, tracking 2.4 | `label` 12 bold, tracking 1.6 |
| Countdown | 78 / 52 fixed | 78 → cap 96 / 52 → cap 68, scaled |
| Subtitle | 10 medium, tracking 1.3 | `meta` 13 medium, tracking 0.4, up to 2 lines |
| Set-map row label | 8 semibold | `micro` 11, tracking 0.2 |
| Set-map count | 8 semibold, tracking 1.6 | `micro` 11, tracking 1.2 |
| Primary title | 11.5 bold, tracking 1.6 | `action` 17 bold, tracking 0.6 |
| Primary subtitle | 8.5 semibold, tracking 0.9 | `meta` 13 semibold, tracking 0.2 |
| Skip icon | 15 | 17, 62 pt circle |
| SESSION COMPLETE | 10 bold, tracking 2 | `label` 12 bold, tracking 1.6 |

**Sessions list**

| Element | Now | New |
| --- | --- | --- |
| WORKOUTS eyebrow | 9 semibold, tracking 2 | `section` 13, tracking 1.2 |
| SESSIONS title | 28 semibold, tracking −0.4 | `screenTitle` 34, tracking 0 |
| Add button | 14, 40 pt circle | 20, 44 pt circle |
| Card name | 13 semibold, tracking 0.6 | `rowTitle` 17, tracking 0.2 |
| Card summary | 9 semibold, tracking 1.1 | `meta` 13 medium, tracking 0.2, 2 lines |
| ACTIVE badge | 8 bold, tracking 0.9 | `micro` 11 bold, tracking 0.6 |
| Chevron | 11 | 15 |
| Footer copy | 10 medium | `meta` 13, line spacing 3 |
| Lock banner | 8.5 semibold, tracking 1.1 | `meta` 13 semibold, tracking 0.6 |

**Session editor**

| Element | Now | New |
| --- | --- | --- |
| Back / DONE | 10 | `compactAction` 13, 44 pt tall |
| Section kicker | 9 bold, tracking 2 | `section` 13, tracking 1.2 |
| Name field | 24 semibold | `pageTitle` 28 |
| Summary | 10 semibold, tracking 1.2 | `body` 15, tracking 0.2 |
| Restart warning | 9 semibold, tracking 1.2 | `meta` 13 semibold, tracking 0.6 |
| Part index | 10 semibold | `meta` 13 semibold |
| Part name | 13 semibold | `rowTitle` 17 |
| Part meta | 8.5 semibold, tracking 0.9 | `meta` 13, tracking 0.2, 2 lines |
| Move chevrons | 10, 34 × 24 | 17, 44 × 44 |
| Add part | 9.5 bold, 42 pt tall | `compactAction` 13 bold, 48 pt min height |
| Footer buttons | 10 bold, 46 pt tall | `action` 17, 52 pt min height |
| Delete | 9.5 semibold, tracking 1.4 | `meta` 13 semibold |
| Keyboard Done | 14 | `body` 17 |

**Part editor**

| Element | Now | New |
| --- | --- | --- |
| Back / DONE | 10 | `compactAction` 13, 44 pt tall |
| Kicker / name / summary | 9 / 24 / 10 | `section` 13 / `pageTitle` 28 / `body` 15 |
| Row label | 9.5 semibold, tracking 1.4 | `body` 15 medium, tracking 0.2 |
| Row value | 15 semibold | `value` 20 semibold |
| Stepper icon | 12 | 17, 44 × 44 |
| Row height | 52 fixed | 56 min, grows with the row |
| Footer copy / delete | 10 / 9.5 | `meta` 13 / `meta` 13 semibold |

**Widget**

| Element | Now | New |
| --- | --- | --- |
| Lock screen session name | 9 | `micro` 11, opacity 0.5 |
| Lock screen part name | 16 | `rowTitle` 17 |
| Lock screen kicker | 10 | `label` 12 |
| Lock screen subtitle | 9 | `meta` 13, 2 lines |
| Lock screen timer | 42 | scaled 42 → cap 54 |
| Island leading (kicker / part / position) | 10 / 10 / 9 | 12 / 12 / 11 fixed |
| Island timer | 28 | 30 fixed |
| Compact label / timer | 10 / 13 | 12 / 14 fixed |
| Island buttons | 11 | 13 fixed |

### D3. Timer reflow

The timer keeps one layout at every size; it does not switch to a second hand-built screen.

- Wrap the timer's `VStack` in `ScrollView` with `.scrollBounceBehavior(.basedOnSize)` and `.frame(minHeight: proxy.size.height)`. When content fits, behaviour is unchanged; when it does not, the actions are still reachable. The `GeometryReader` stays outside so the hero side and the backdrop gradient keep their current sizing.
- Position strip: `ViewThatFits(in: .horizontal)`; first the existing one-line composition, then a two-line form (`PART 2 OF 3` / `ROUND 1 OF 3 · SET 2 OF 4`). Remove `lineLimit(1)` and `minimumScaleFactor(0.7)` from this strip.
- Header: `ViewThatFits`; horizontal name + EDIT, else name on one line and EDIT below it aligned trailing. Session names are capped at 18 characters, so the horizontal form holds at ordinary sizes.
- Part strip already scrolls horizontally; chips grow in height and their labels no longer scale down.
- Primary action row: label and subtitle may each take two lines; the row uses `minHeight: 62` and grows. The skip button keeps its 62 pt circle and remains square.
- Hero: at accessibility sizes the side may grow to `min(340, width - 44)`; otherwise it stays `min(320, width - 44, height * 0.42)`. The countdown uses `@ScaledMetric(relativeTo: .largeTitle)` capped at 96 (large) and 68 (small); kerning stays proportional (`-size * 0.05` large, `0.5` small).
- The set map stays a dot grid; only its labels scale. Dots are progress marks, not text.

### D4. Sizing rules for controls

- Replace fixed `frame(height:)` on buttons and rows with `minHeight` plus vertical padding; replace fixed text heights with intrinsic height.
- Every control gets at least 44 × 44 pt: timer EDIT, sessions add, back/DONE, move chevrons, delete actions, skip, add part. Steppers are already 44 × 44; the visible chip inside stays 34 × 30.
- Cards and rows keep 14–16 pt corner radii and 22 pt horizontal page padding.
- Multi-line text uses `.fixedSize(horizontal: false, vertical: true)` where a parent row could compress it; `lineLimit` is only used for names that must stay one line, and those wrap once at accessibility sizes.

### D5. Scaling limits for fixed geometry

- App screens: no cap; every text style scales to the largest accessibility size.
- Hero digits: capped as in D3 because the ring has a width. The cap only binds above AX1.
- Lock Screen panel: `.dynamicTypeSize(...(.accessibility1))` so the fixed-height panel never clips; the timer uses a capped `@ScaledMetric`.
- Dynamic Island: fixed point sizes, because the island does not follow Dynamic Type. Its regions have hard widths; the compact label remains a 3-letter prefix.
- `minimumScaleFactor` is retained only for the session-name header (single line), the island compact label, and the hero digits; everywhere else text wraps instead of shrinking.

### D6. Prototype first

`prototype-workout-timer.html` is the visual reference and its px sizes equal points at 430 pt. Update it before the SwiftUI work: apply the default-size targets from D2 to the matching selectors, adjust line heights and paddings so nothing overlaps at 430 × 880, and keep the existing palette and composition. The prototype remains a static default-size reference; the app is the Dynamic Type surface.

### D7. Verification

- Build and unit-test with `xcodebuild` on iPhone 18 Pro Max; run the watch build to prove `Theme` still compiles for watchOS.
- Inspect the four text sizes on the simulator: default, XXL, AX3, AX5. Capture the timer in ready, resting, paused and done; the sessions list; both editors; the Lock Screen panel; the island expanded and compact.
- Use the longest copy as the stress case: 18-character session and part names, `SETS PER ROUND`, `TAP AGAIN TO DELETE`, `EDITING LOCKED DURING REST · SWITCH TO TIMER TO PAUSE OR SKIP`.
- Read the accessibility tree at checkpoints to confirm no text is clipped and labels are unchanged for VoiceOver.

## Risks / trade-offs

- **Larger type costs density.** The timer stops being a single glance at accessibility sizes. Mitigation: the countdown, part and primary action keep their order; scrolling only engages when content does not fit (`basedOnSize`).
- **The 44 pt floor grows the editors.** Rows go from 52 to 56+ and move buttons become 44 wide, so fewer parts fit per screen. Mitigation: the editors already scroll; the top of the screen still shows the name and first parts.
- **Hero and Lock Screen caps mean the largest settings do not scale fully there.** Accepted: both have fixed geometry. The cap is documented and only binds above the ordinary range.
- **The Lock Screen panel has ~160 pt of height.** `accessibility1` cap plus a two-line subtitle risks clipping. Mitigation: test at AX5; drop the subtitle to one line before shrinking the part name.
- **Uppercase tracking overflows chips at large sizes.** Mitigation: tracking drops to 0.8 pt for chips and 1.2 for section labels; the part strip scrolls; no chip has a fixed width.
- **`Theme` is compiled into the watch target.** Mitigation: type roles use only `Font`; no UIKit, no iOS-only modifiers; verify the watch build.
- **Semantic metrics shift with OS versions.** Desired, but screenshots must be re-reviewed after OS updates rather than pixel-compared across versions.

## Migration Plan

1. Update the prototype type scale and confirm the 430 × 880 frame.
2. Add `Theme.TypeScale` and migrate the sessions list and both editors.
3. Migrate the timer and its reflow behaviour.
4. Migrate the Lock Screen panel and raise the island's fixed sizes.
5. Verify default, XXL, AX3 and AX5; run unit tests and the watch build.

No stored data, API or URL scheme changes, so rollback is a code revert. No app migration is needed.

## Open Questions

None.
