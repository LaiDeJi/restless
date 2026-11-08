import SwiftUI

/// Ends editing when the page outside the focused field is tapped, while a tap
/// inside the field keeps the keyboard. Each screen keeps its own
/// `@FocusState` and reports the field's frame in the named space.
private struct PageTapKeyboardDismiss: ViewModifier {
    let isFocused: Bool
    let fieldFrame: CGRect
    let coordinateSpace: String
    let endEditing: () -> Void

    func body(content: Content) -> some View {
        content
            .coordinateSpace(.named(coordinateSpace))
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard isFocused, !fieldFrame.contains(value.location) else { return }
                        endEditing()
                    }
            )
    }
}

extension View {
    /// A page tap outside the focused field dismisses the keyboard; the field
    /// itself stays tappable and the typed text is kept.
    func pageTapKeyboardDismiss(
        isFocused: Bool,
        fieldFrame: CGRect,
        coordinateSpace: String,
        endEditing: @escaping () -> Void
    ) -> some View {
        modifier(PageTapKeyboardDismiss(
            isFocused: isFocused,
            fieldFrame: fieldFrame,
            coordinateSpace: coordinateSpace,
            endEditing: endEditing
        ))
    }
}
