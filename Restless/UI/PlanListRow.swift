import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The row card's latest on-screen rect, written by the row's geometry callback.
/// A reference box rather than state: the handle reads it at lift and on drop,
/// and a write during an animated reorder must not re-evaluate the row.
/// Written and read on the main actor only.
final class PlanCardMetrics: @unchecked Sendable {
    var rect: CGRect = .zero
}

/// One reorderable plan row. The card opens its editor, the trailing grip is the
/// drag source, and the trailing trash arms on the first tap. The same row is
/// used by the session editor's blocks and the block editor's movements.
struct PlanListRow<Destination: View, Content: View>: View {
    let itemID: UUID
    let canDelete: Bool
    let isArmed: Bool
    let isLocked: Bool
    let deleteLabel: String
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (Bool) -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let destination: () -> Destination

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The card's own on-screen rect, not the row's: the floating card is the
    /// size of the card it lifts and starts from that card's position, so it
    /// stays where the finger grabbed it while the list moves underneath.
    @State private var cardMetrics = PlanCardMetrics()

    private var isDragSource: Bool { !isLocked && draggingID == itemID }
    private var isDropTarget: Bool {
        !isLocked && dropTargetID == itemID && draggingID != nil && draggingID != itemID
    }

    var body: some View {
        if canDelete {
            row
                .accessibilityAction(named: "Delete") {
                    if !isLocked { onDelete() }
                }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 8) {
            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 12) {
                    content()

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(Theme.TypeScale.body.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isDropTarget ? Theme.setAccent.opacity(0.55) : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    cardMetrics.rect = frame
                }
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityAction(named: "Move up") {
                if !isLocked { onMoveUp() }
            }
            .accessibilityAction(named: "Move down") {
                if !isLocked { onMoveDown() }
            }
            // Hide the card, not the row's container: the empty slot must stay
            // hit-testable so dropping back onto it commits the provisional
            // order instead of cancelling (UIKit skips alpha-0 drop targets).
            .opacity(isDragSource ? 0 : 1)

            grip
                .opacity(isDragSource ? 0 : 1)

            if canDelete {
                trash
                    .opacity(isDragSource ? 0 : 1)
            }
        }
        // The hidden slot still needs a hit area: drop targeting follows the
        // container's content shape, not its invisible children.
        .contentShape(Rectangle())
        .onDrop(
            of: [.planRow],
            delegate: PlanDropDelegate(
                targetID: itemID,
                draggingID: $draggingID,
                dropTargetID: $dropTargetID,
                onReorder: onReorder,
                onDropEnded: onDropEnded
            )
        )
    }

    @ViewBuilder
    private var grip: some View {
        if isLocked {
            gripDots
        } else {
            gripDots
                .overlay {
                    PlanDragHandle(
                        itemID: itemID,
                        metrics: cardMetrics,
                        previewCornerRadius: 16,
                        trailingInset: 0,
                        draggingID: $draggingID,
                        dropTargetID: $dropTargetID,
                        onDragBegan: onDragBegan,
                        onDragEnded: onDragEnded,
                        preview: { size in dragPreview(size: size) }
                    )
                    .frame(width: 44, height: 44)
                }
        }
    }

    private func dragPreview(size: CGSize) -> some View {
        PlanDragCard {
            HStack(spacing: 12) {
                content()

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(Theme.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .frame(width: previewWidth(size), height: previewHeight(size))
    }

    private var gripDots: some View {
        PlanGripDots(dimmed: isLocked)
    }

    private var trash: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(Theme.TypeScale.body.weight(.semibold))
                .foregroundStyle(Theme.destructive.opacity(isArmed ? 1 : 0.62))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isArmed ? Theme.destructive.opacity(0.12) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isArmed ? Theme.destructive.opacity(0.34) : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.2 : 1)
        .accessibilityLabel(deleteLabel)
    }
}

/// The grip's dots, shared by the plan rows and the SESSIONS cards.
struct PlanGripDots: View {
    let dimmed: Bool

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 4) {
                    Circle().frame(width: 3, height: 3)
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(.white.opacity(dimmed ? 0.16 : 0.42))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

/// The floating card shared by the session, block, and movement drags: one
/// chrome, so the three lists lift the same way.
struct PlanDragCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
    }
}

/// The lift card is the size of the card it lifts, so it covers the row exactly
/// while the list moves underneath it. The fallback only covers a row that has
/// not measured itself yet, where the grip's 44 pt box is not a card.
private func previewWidth(_ size: CGSize) -> CGFloat {
    size.width > 120 ? size.width : 320
}

private func previewHeight(_ size: CGSize) -> CGFloat {
    size.height > 1 ? size.height : 68
}

/// A SESSIONS card with the same trailing grip and drop target as a plan row.
/// The card keeps its own tap action; the grip is a sibling, never the button.
struct SessionDragRow<Content: View>: View {
    let itemID: UUID
    let isActive: Bool
    let isLocked: Bool
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (Bool) -> Void
    let onOpen: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var cardMetrics = PlanCardMetrics()

    private var isDragSource: Bool { !isLocked && draggingID == itemID }
    private var isDropTarget: Bool {
        !isLocked && dropTargetID == itemID && draggingID != nil && draggingID != itemID
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onOpen) {
                content()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(isActive ? 0.075 : 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isDropTarget
                                    ? Theme.setAccent.opacity(0.55)
                                    : (isActive ? Theme.setAccent.opacity(0.28) : .white.opacity(0.055)),
                                lineWidth: 1
                            )
                    )
                    .contentShape(Rectangle())
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        cardMetrics.rect = frame
                    }
            }
            .buttonStyle(.plain)
            .accessibilityAction(named: "Move up") {
                if !isLocked { onMoveUp() }
            }
            .accessibilityAction(named: "Move down") {
                if !isLocked { onMoveDown() }
            }
            // Keep the row container hit-testable while its card is hidden, so
            // dropping back on the empty slot commits instead of cancelling.
            .opacity(isDragSource ? 0 : 1)

            grip
                .opacity(isDragSource ? 0 : 1)
        }
        // The hidden slot still needs a hit area: drop targeting follows the
        // container's content shape, not its invisible children.
        .contentShape(Rectangle())
        .onDrop(
            of: [.planRow],
            delegate: PlanDropDelegate(
                targetID: itemID,
                draggingID: $draggingID,
                dropTargetID: $dropTargetID,
                onReorder: onReorder,
                onDropEnded: onDropEnded
            )
        )
    }

    @ViewBuilder
    private var grip: some View {
        if isLocked {
            PlanGripDots(dimmed: true)
        } else {
            PlanGripDots(dimmed: false)
                .overlay {
                    PlanDragHandle(
                        itemID: itemID,
                        metrics: cardMetrics,
                        previewCornerRadius: 16,
                        trailingInset: 0,
                        draggingID: $draggingID,
                        dropTargetID: $dropTargetID,
                        onDragBegan: onDragBegan,
                        onDragEnded: onDragEnded,
                        preview: { size in dragPreview(size: size) }
                    )
                    .frame(width: 44, height: 44)
                }
        }
    }

    private func dragPreview(size: CGSize) -> some View {
        PlanDragCard { content() }
            .frame(width: previewWidth(size), height: previewHeight(size))
    }
}
