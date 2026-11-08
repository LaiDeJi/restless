import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @ViewBuilder let content: () -> Content
    @ViewBuilder let destination: () -> Destination

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var rowSize: CGSize = .zero

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
                .opacity(isDragSource ? 0.35 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityAction(named: "Move up") {
                if !isLocked { onMoveUp() }
            }
            .accessibilityAction(named: "Move down") {
                if !isLocked { onMoveDown() }
            }

            grip

            if canDelete {
                trash
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            rowSize = size
        }
        .onDrop(
            of: [.text],
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
                        previewSize: rowSize,
                        trailingInset: 0,
                        draggingID: $draggingID,
                        dropTargetID: $dropTargetID,
                        preview: { size in dragPreview(size: size) }
                    )
                    .frame(width: 44, height: 44)
                }
        }
    }

    private func dragPreview(size: CGSize) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.background)

            HStack(spacing: 12) {
                content()

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(Theme.TypeScale.body.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(width: max(size.width, 320), height: max(size.height, 68))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.7), radius: 26, x: 0, y: 16)
    }

    private var gripDots: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 4) {
                    Circle().frame(width: 3, height: 3)
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(.white.opacity(isLocked ? 0.16 : 0.42))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityHidden(true)
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

/// The grip's 44 × 44 area catches the drag; the floating preview is drawn
/// separately so it is not clipped to the grip. The hit test is bounded on both
/// axes: an x-only check would claim a vertical strip and steal taps from the
/// steppers and header actions above and below the row.
private final class PlanDragSurfaceView: UIView {
    var trailingInset: CGFloat = 0

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let gripMaxX = bounds.width - trailingInset
        return point.x >= gripMaxX - 44
            && point.x <= gripMaxX
            && point.y >= 0
            && point.y <= bounds.height
    }
}

/// Reorders as the dragged row enters another row, so the list follows the
/// finger instead of waiting for the drop. The handler receives stable ids, and
/// each screen looks up the live indexes, so a fast drag cannot use stale ones.
private struct PlanDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingID, source != targetID else { return }
        dropTargetID = targetID
        onReorder(source, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if draggingID != nil {
            dropTargetID = targetID
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetID {
            dropTargetID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        dropTargetID = nil
        onDropEnded()
        return true
    }
}

/// The grip's drag source. A UIKit drag interaction is the one place that
/// reports both ends of the session, so the lifted source clears even when the
/// drop lands outside every row.
private struct PlanDragHandle<Preview: View>: UIViewRepresentable {
    let itemID: UUID
    let previewSize: CGSize
    let trailingInset: CGFloat
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    @ViewBuilder let preview: (CGSize) -> Preview

    func makeUIView(context: Context) -> UIView {
        let view = PlanDragSurfaceView()
        view.backgroundColor = .clear
        view.trailingInset = trailingInset
        let interaction = UIDragInteraction(delegate: context.coordinator)
        interaction.isEnabled = true
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PlanDragSurfaceView)?.trailingInset = trailingInset
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDragInteractionDelegate {
        var parent: PlanDragHandle
        private var previewLayer: CALayer?
        private var sourceWindow: UIWindow?
        private var dragSession: UIDragSession?
        private var displayLink: CADisplayLink?

        init(_ parent: PlanDragHandle) {
            self.parent = parent
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            itemsForBeginning session: UIDragSession
        ) -> [UIDragItem] {
            let item = UIDragItem(
                itemProvider: NSItemProvider(object: parent.itemID.uuidString as NSString)
            )
            item.previewProvider = {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
                view.backgroundColor = .clear
                let parameters = UIDragPreviewParameters()
                parameters.backgroundColor = .clear
                parameters.visiblePath = UIBezierPath(rect: view.bounds)
                return UIDragPreview(view: view, parameters: parameters)
            }
            return [item]
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            previewForLifting item: UIDragItem,
            session: UIDragSession
        ) -> UITargetedDragPreview? {
            guard let source = interaction.view else { return nil }
            let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            view.backgroundColor = .clear
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(rect: view.bounds)
            let target = UIDragPreviewTarget(container: source, center: session.location(in: source))
            return UITargetedDragPreview(view: view, parameters: parameters, target: target)
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            sessionWillBegin session: UIDragSession
        ) {
            parent.dropTargetID = nil
            parent.draggingID = parent.itemID
            guard let source = interaction.view,
                  let window = source.window,
                  let image = makePreviewImage()
            else { return }
            dragSession = session
            sourceWindow = window

            let layer = CALayer()
            layer.contents = image.cgImage
            layer.contentsScale = image.scale
            layer.bounds = CGRect(origin: .zero, size: image.size)
            layer.opacity = 1
            window.layer.addSublayer(layer)
            previewLayer = layer
            positionPreview(at: session.location(in: window), in: window)

            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tick() {
            MainActor.assumeIsolated {
                guard let session = dragSession,
                      let window = sourceWindow,
                      previewLayer != nil
                else { return }
                positionPreview(at: session.location(in: window), in: window)
            }
        }

        private func positionPreview(at point: CGPoint, in window: UIWindow) {
            guard let previewLayer else { return }
            let halfWidth = previewLayer.bounds.width / 2
            let halfHeight = previewLayer.bounds.height / 2
            let x = min(max(point.x, halfWidth), window.bounds.width - halfWidth)
            let y = min(max(point.y - halfHeight - 12, halfHeight), window.bounds.height - halfHeight)
            previewLayer.position = CGPoint(x: x, y: y)
        }

        private func makePreviewImage() -> UIImage? {
            let size = CGSize(
                width: max(parent.previewSize.width, 320),
                height: max(parent.previewSize.height, 68)
            )
            let inset: CGFloat = 30
            let renderSize = CGSize(
                width: size.width + inset * 2,
                height: size.height + inset * 2
            )
            let renderer = ImageRenderer(
                content: parent.preview(size)
                    .padding(inset)
                    .frame(width: renderSize.width, height: renderSize.height)
            )
            renderer.scale = 3
            return renderer.uiImage
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            session: UIDragSession,
            didEndWith operation: UIDropOperation
        ) {
            displayLink?.invalidate()
            displayLink = nil
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
            dragSession = nil
            sourceWindow = nil
            parent.draggingID = nil
            parent.dropTargetID = nil
        }
    }
}
