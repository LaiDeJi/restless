import SwiftUI
import UIKit

/// One full-surface stepper chip. A `UIButton` gives the whole 48 × 44 body a
/// reliable tap and a reliable touch-down for the hold; the SwiftUI shapes
/// around it could lose the touch-down to the row gestures. A tap steps once;
/// holding repeats after 500 ms and every 100 ms until release, disable, lock,
/// or the range bound.
struct PlanStepButton: UIViewRepresentable {
    let systemName: String
    let accessibilityLabel: String
    let enabled: Bool
    let initialDelay: Duration
    let repeatInterval: Duration
    let step: @MainActor () -> Bool

    init(
        systemName: String,
        accessibilityLabel: String,
        enabled: Bool,
        initialDelay: Duration = .milliseconds(500),
        repeatInterval: Duration = .milliseconds(100),
        step: @escaping @MainActor () -> Bool
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.enabled = enabled
        self.initialDelay = initialDelay
        self.repeatInterval = repeatInterval
        self.step = step
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(initialDelay: initialDelay, repeatInterval: repeatInterval)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.pressed),
            for: .touchDown
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.released),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        context.coordinator.step = step
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.step = step
        button.isEnabled = enabled
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(enabled ? 0.85 : 0.18)
        button.backgroundColor = UIColor.white.withAlphaComponent(enabled ? 0.08 : 0.03)
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = .button
        if !enabled {
            context.coordinator.stop()
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UIButton,
        context: Context
    ) -> CGSize? {
        CGSize(width: 48, height: 44)
    }

    static func dismantleUIView(_ uiView: UIButton, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator: NSObject {
        var step: (@MainActor () -> Bool)?

        private let repeater: StepRepeater
        private var didRepeat = false

        init(initialDelay: Duration, repeatInterval: Duration) {
            repeater = StepRepeater(initialDelay: initialDelay, interval: repeatInterval)
        }

        @objc func pressed() {
            didRepeat = false
            repeater.start { [weak self] in
                guard let self else { return false }
                self.didRepeat = true
                return self.step?() ?? false
            }
        }

        @objc func released() {
            repeater.stop()
            if didRepeat {
                didRepeat = false
            } else {
                _ = step?()
            }
        }

        func stop() {
            repeater.stop()
        }
    }
}
