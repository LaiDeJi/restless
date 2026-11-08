# Spec Delta

## MODIFIED Requirements

### Requirement: Lock Screen scales, island stays fixed

The Lock Screen panel SHALL use the same hierarchy and scale with the system text size up to xxLarge, the largest size at which the panel fits its 160-point budget. It MUST NOT grow past that cap, so no text or control is clipped. The Dynamic Island SHALL keep fixed type sizes and SHALL keep its compact movement label and countdown visible.

#### Scenario: Lock Screen at the largest text size

- **GIVEN** the largest accessibility text size
- **WHEN** the Lock Screen panel is shown during a rest
- **THEN** the movement name, state row, remaining time, and both controls are fully visible at the xxLarge cap

#### Scenario: Above the cap

- **GIVEN** an accessibility text size larger than xxLarge
- **WHEN** the Lock Screen panel is shown
- **THEN** it renders at the xxLarge cap and no text or control is clipped

#### Scenario: Compact island keeps both sides

- **GIVEN** a Triceps session on the Dynamic Island
- **WHEN** the compact presentation is shown
- **THEN** TRI and the countdown are both visible
