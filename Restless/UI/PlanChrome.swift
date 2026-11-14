import SwiftUI

/// Liquid Glass for the app's floating chrome on iOS 26, with the existing flat
/// translucent capsule or circle on iOS 18–25. Content (cards, the ring, the
/// map, primary buttons, editor fields) stays flat.
struct ChromeGlass<S: Shape>: ViewModifier {
    let tint: Color?
    let shape: S
    let fallbackFill: Color
    let fallbackStroke: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(shape.fill(fallbackFill))
                .overlay(shape.stroke(fallbackStroke, lineWidth: 1))
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        if let tint {
            return .regular.tint(tint).interactive()
        }
        return .regular.interactive()
    }
}

extension View {
    func chromeGlass<S: Shape>(
        tint: Color? = nil,
        in shape: S,
        fallbackFill: Color = .white.opacity(0.08),
        fallbackStroke: Color = .white.opacity(0.12)
    ) -> some View {
        modifier(
            ChromeGlass(
                tint: tint,
                shape: shape,
                fallbackFill: fallbackFill,
                fallbackStroke: fallbackStroke
            )
        )
    }
}

/// One confirmation for both restart entry points. The timer has its own copy
/// of the same alert; the words must stay identical.
struct RestartConfirmationAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert("Restart this session?", isPresented: $isPresented) {
            Button("Restart Session", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all completed sets, cancels the current rest, and returns to block 1, set 1.")
        }
    }
}

/// A header action whose whole visible capsule is the Button's label, so a
/// center tap fires. No padding-only content shape sits inside the label.
struct PlanPillButton: View {
    let title: String
    var prominent = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.TypeScale.compactAction.weight(prominent ? .bold : .semibold))
                .tracking(prominent ? 1.0 : 0.9)
                .foregroundStyle(foreground)
                .padding(.horizontal, prominent ? 18 : 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(background))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .disabled(!enabled)
    }

    private var foreground: Color {
        if prominent {
            return enabled ? Theme.ink : .white.opacity(0.3)
        }
        return .white.opacity(enabled ? 0.62 : 0.3)
    }

    private var background: Color {
        if prominent {
            return enabled ? .white : .white.opacity(0.07)
        }
        return .white.opacity(enabled ? 0.06 : 0.03)
    }
}
