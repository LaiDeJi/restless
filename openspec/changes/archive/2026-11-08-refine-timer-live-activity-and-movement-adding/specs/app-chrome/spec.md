# Spec Delta

## Purpose

Defines how Restless draws its floating navigation and action controls, including when those controls adopt Liquid Glass and which surfaces stay flat.

## ADDED Requirements

### Requirement: Floating controls adopt Liquid Glass on iOS 26

On iOS 26 and later, the timer's EDIT and restart controls and the SESSIONS add control SHALL render with the system Liquid Glass material. On iOS 18 through iOS 25 they SHALL keep the flat translucent capsule or circle. Adopting the material MUST NOT raise the deployment target or change a control's action, label, accessibility label, size, or position.

#### Scenario: Glass on iOS 26

- **GIVEN** an iPhone running iOS 26 or later
- **WHEN** the timer header and the SESSIONS header are shown
- **THEN** EDIT, restart, and add render with Liquid Glass and each keeps a 44 × 44 pt or larger hit area

#### Scenario: Flat on iOS 18 through 25

- **GIVEN** an iPhone running iOS 18 through iOS 25
- **WHEN** the same controls are shown
- **THEN** they render with the flat translucent fill and no glass effect

#### Scenario: The action does not change with the material

- **GIVEN** any supported iOS version
- **WHEN** the user taps EDIT, restart, or add
- **THEN** the control performs the same action and announces the same accessibility label as before

### Requirement: Content stays flat

Session cards, the countdown ring, the set map, primary action buttons, editor fields, and the Live Activity SHALL NOT use Liquid Glass. The system tab bar, sheets, and menus MAY keep the glass that the system applies to them.

#### Scenario: Timer content is not glass

- **GIVEN** iOS 26 and a running session
- **WHEN** the timer is shown
- **THEN** the ring, set map, and primary action are flat, and only the floating header controls and the system tab bar use glass

#### Scenario: Sessions content is not glass

- **GIVEN** iOS 26 and the SESSIONS tab
- **WHEN** the session cards and MOVEMENTS card are shown
- **THEN** those cards are flat and the add control is the only glass element in the page

### Requirement: Glass does not carry meaning alone

A control's state SHALL remain legible without relying on the material. The armed restart state SHALL keep its `TAP AGAIN` label and amber emphasis with and without Liquid Glass.

#### Scenario: Armed restart on both materials

- **GIVEN** an armed restart control
- **WHEN** it is shown on iOS 18 and on iOS 26
- **THEN** both versions show `TAP AGAIN` in the round-rest amber, not a material-only change
