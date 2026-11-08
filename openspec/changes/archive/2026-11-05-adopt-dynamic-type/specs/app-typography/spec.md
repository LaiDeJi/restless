# Spec Delta

## Purpose

Ranks every piece of text in Restless into one type hierarchy and makes it follow the system text size across the timer, sessions list, editors and Lock Screen.

## ADDED Requirements

### Requirement: Text follows the system text size

All user-facing text on the timer, sessions list, session editor, part editor and Lock Screen SHALL grow and shrink with the system text size. At the default text size no text SHALL render below 11 pt. The Dynamic Island SHALL keep fixed sizes because it does not follow the system text size.

#### Scenario: Larger Text reaches every screen

- **GIVEN** the system text size is set to XXL
- **WHEN** the timer, sessions list and both editors are shown
- **THEN** labels, values and body copy are larger than at the default text size on each screen

#### Scenario: Default size has a readable floor

- **GIVEN** the default system text size
- **WHEN** any app screen is shown
- **THEN** no text renders below 11 pt

### Requirement: Four-tier type hierarchy

Each screen SHALL rank its text in four tiers: title, section, content and meta. A role SHALL use the same relative size on every screen: screen and page titles are largest, section headings sit below them, content covers row titles, names, values, body copy and actions, and meta is smallest. Outside the timer countdown, content SHALL be at least subheadline size, meta at least caption2, and uppercase tracking SHALL not exceed 1.6 pt.

#### Scenario: Sessions list ranks its text

- **GIVEN** the SESSIONS tab is open
- **WHEN** the header and a session card are shown
- **THEN** SESSIONS is larger than the WORKOUTS eyebrow, and the session name is larger than its parts/sets/rest summary

#### Scenario: Editor ranks its text

- **GIVEN** a session editor is open
- **WHEN** a part row is shown
- **THEN** the part name is larger than its rounds/sets/rest line, and the editable session name is larger than the section headings

#### Scenario: Timer ranks its text

- **GIVEN** a session is resting
- **WHEN** the timer is shown
- **THEN** the countdown is the largest text, the session name and kicker are smaller, and the progress count is the smallest

### Requirement: Controls grow with their text

Buttons, stepper rows and list rows SHALL take their height from their content and padding rather than a fixed height, and every interactive control SHALL provide at least a 44 × 44 pt tap target.

#### Scenario: Buttons grow at the largest text size

- **GIVEN** the largest accessibility text size
- **WHEN** the timer and both editors are shown
- **THEN** primary buttons, footer buttons and stepper rows grow with their labels and no label is clipped

#### Scenario: Small actions keep a full tap target

- **GIVEN** any text size
- **WHEN** the timer EDIT action, a part move chevron or a rest stepper is shown
- **THEN** its tappable area is at least 44 × 44 pt

### Requirement: Timer reflows at accessibility sizes

At accessibility text sizes the timer SHALL keep all text readable without truncation or shrink-to-fit: the position strip SHALL wrap to a second line, the content SHALL scroll when the screen is too short, and the session name and EDIT action SHALL share the header without either being clipped.

#### Scenario: Position strip wraps

- **GIVEN** an accessibility text size
- **WHEN** a session is resting
- **THEN** the part, round and set text is fully visible, wrapping as needed, and the actions are reachable by scrolling

#### Scenario: Header keeps name and action

- **GIVEN** an 18-character session name and an accessibility text size
- **WHEN** the timer is shown
- **THEN** the full session name and the EDIT action are both visible

### Requirement: Countdown scales inside the ring

The countdown SHALL scale with the system text size up to a cap, remain monospaced, and stay inside the progress ring, which SHALL grow with it up to the available width.

#### Scenario: Countdown grows with text size

- **GIVEN** an accessibility text size
- **WHEN** a rest countdown is shown
- **THEN** the digits are larger than at the default size and the ring around them is not clipped

#### Scenario: Short hero text fits

- **GIVEN** the largest accessibility text size
- **WHEN** the session reaches the done state
- **THEN** DONE fits inside the ring

### Requirement: Lock Screen scales, island stays fixed

The Lock Screen panel SHALL use the same hierarchy and scale with the system text size, capped so the panel's fixed height is never clipped. The Dynamic Island SHALL keep fixed type sizes and SHALL keep its compact part label and countdown visible.

#### Scenario: Lock Screen at the largest text size

- **GIVEN** the largest accessibility text size
- **WHEN** the Lock Screen panel is shown during a rest
- **THEN** the part name, rest label and remaining time are fully visible

#### Scenario: Compact island keeps both sides

- **GIVEN** a Triceps session on the Dynamic Island
- **WHEN** the compact presentation is shown
- **THEN** TRI and the countdown are both visible
