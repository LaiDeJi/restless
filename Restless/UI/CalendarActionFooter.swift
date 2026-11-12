import SwiftUI

/// The day sheet's plan actions: outline buttons under a hairline, stacked at
/// accessibility sizes so their 44 pt targets survive.
struct CalendarActionFooter: View {
    let actions: [(String, () -> Void)]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
            layout
        }
        .padding(.top, 4)
    }

    private var layout: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                outlineButton(action.0, action: action.1)
            }
        }
    }

    private func outlineButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.TypeScale.micro.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(Capsule().fill(.clear))
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
