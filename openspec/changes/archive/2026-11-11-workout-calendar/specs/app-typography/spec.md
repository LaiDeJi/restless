# Spec Delta

## MODIFIED Requirements

### Requirement: Text follows the system text size

All user-facing text on the timer, sessions list, session editor, part editor, CALENDAR grid and settings, day sheet, and Lock Screen SHALL grow and shrink with the system text size. At the default text size no text SHALL render below 11 pt. A grid session code SHALL truncate rather than shrink below that floor, and the day sheet SHALL show the full session name. The Dynamic Island SHALL keep fixed sizes because it does not follow the system text size.

#### Scenario: Larger Text reaches every screen

- **GIVEN** the system text size is set to XXL
- **WHEN** the timer, sessions list, calendar and both editors are shown
- **THEN** labels, values and body copy are larger than at the default text size on each screen

#### Scenario: Default size has a readable floor

- **GIVEN** the default system text size
- **WHEN** any app screen is shown
- **THEN** no text renders below 11 pt

#### Scenario: A long session code truncates

- **GIVEN** a session named Shoulders and a day cell at the default text size
- **WHEN** the month grid is shown
- **THEN** the code renders at 11 pt or larger, truncates to fit, and its day sheet shows Shoulders in full

#### Scenario: The day sheet scales

- **GIVEN** an accessibility text size
- **WHEN** a recorded day's sheet is shown
- **THEN** the session name, set count and block rows are larger than at the default size and none is clipped
