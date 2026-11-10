import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    /// Private drag type for plan rows. It is deliberately not `public.text`,
    /// so a name field cannot accept a dropped row as text.
    static let planRow = UTType(exportedAs: "com.whc.restless.plan-row")
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
struct PlanDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingID, source != targetID else { return }
        // A row that moves under a stationary pointer can report the same entry
        // again; reordering twice would undo the first move.
        guard dropTargetID != targetID else { return }
        dropTargetID = targetID
        onReorder(source, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if draggingID != nil, dropTargetID != targetID {
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
        // The row fades back in under the card, which settles into it.
        withAnimation(.easeOut(duration: 0.16)) {
            draggingID = nil
            dropTargetID = nil
        }
        onDropEnded()
        return true
    }
}

/// Accepts a drag in the header or footer outside the rows, so releasing
/// above the first row inserts at the top and below the last inserts at the
/// bottom instead of cancelling and springing the card back. Apple's lists
/// clamp such a drop to the nearest index; a per-row drop cannot.
struct PlanEdgeDropZone: View {
    let targetID: UUID
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void

    var body: some View {
        // Not `Color.clear`: UIKit skips alpha-zero drop targets. 2% white on
        // the dark background is invisible but keeps the view hit-testable.
        Color.white.opacity(0.02)
            .contentShape(Rectangle())
            .onDrop(
                of: [.planRow],
                delegate: PlanDropDelegate(
                    targetID: targetID,
                    draggingID: $draggingID,
                    dropTargetID: $dropTargetID,
                    onReorder: onReorder,
                    onDropEnded: onDropEnded
                )
            )
    }
}

/// The screen-level edge drop zones, applied while a row drag is live.
private struct PlanEdgeDropZonesModifier: ViewModifier {
    let rowIDs: [UUID]
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onReorder: (UUID, UUID) -> Void
    let onDropEnded: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                zone(rowIDs.first)
            }
            .overlay(alignment: .bottom) {
                zone(rowIDs.last)
            }
    }

    @ViewBuilder
    private func zone(_ targetID: UUID?) -> some View {
        if draggingID != nil, let targetID {
            PlanEdgeDropZone(
                targetID: targetID,
                draggingID: $draggingID,
                dropTargetID: $dropTargetID,
                onReorder: onReorder,
                onDropEnded: onDropEnded
            )
            .frame(height: 200)
        }
    }
}

extension View {
    func planEdgeDropZones(
        rowIDs: [UUID],
        draggingID: Binding<UUID?>,
        dropTargetID: Binding<UUID?>,
        onReorder: @escaping (UUID, UUID) -> Void,
        onDropEnded: @escaping () -> Void
    ) -> some View {
        modifier(
            PlanEdgeDropZonesModifier(
                rowIDs: rowIDs,
                draggingID: draggingID,
                dropTargetID: dropTargetID,
                onReorder: onReorder,
                onDropEnded: onDropEnded
            )
        )
    }
}

/// The grip's drag source. A UIKit drag interaction is the one place that
/// reports both ends of the session, so the lifted source clears even when the
/// drop lands outside every row. The card is rendered on touch-down, added when
/// the lift begins, and then follows the pointer without implicit animation.
/// How much the card grows while it is lifted, matching the prototype's
/// `scale(1.02)` ghost.
private let dragLiftScale: CGFloat = 1.02
/// A release UIKit never reports must not leave the source row hidden.
private let dragEndWatchdog: CFTimeInterval = 0.45

struct PlanDragHandle<Preview: View>: UIViewRepresentable {
    let itemID: UUID
    /// The row card's live frame: the lift size, the place the card starts from,
    /// and the slot it settles into on drop.
    let metrics: PlanCardMetrics
    let previewCornerRadius: CGFloat
    let trailingInset: CGFloat
    @Binding var draggingID: UUID?
    @Binding var dropTargetID: UUID?
    let onDragBegan: () -> Void
    let onDragEnded: (Bool) -> Void
    @ViewBuilder let preview: (CGSize) -> Preview

    func makeUIView(context: Context) -> UIView {
        let view = PlanDragSurfaceView()
        view.backgroundColor = .clear
        view.trailingInset = trailingInset
        let interaction = UIDragInteraction(delegate: context.coordinator)
        interaction.isEnabled = true
        interaction.allowsSimultaneousRecognitionDuringLift = true
        view.addInteraction(interaction)

        // Zero-duration press: renders the card while the system's own lift
        // delay runs, so the layer can appear the moment the lift starts.
        let press = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePress(_:))
        )
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        press.delegate = context.coordinator
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PlanDragSurfaceView)?.trailingInset = trailingInset
        context.coordinator.parent = self
        context.coordinator.invalidateCachedPreview()
        context.coordinator.hidePreviewIfDragEnded()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIDragInteractionDelegate, UIGestureRecognizerDelegate {
        var parent: PlanDragHandle
        private var previewLayer: CALayer?
        private var sourceWindow: UIWindow?
        private var dragSession: UIDragSession?
        private var displayLink: CADisplayLink?
        private var cachedPreview: UIImage?
        private var liftPosition: CGPoint?
        /// Where the card sat relative to the finger at lift, kept for the whole
        /// gesture so the card neither trails nor jumps sideways.
        private var grabOffset: CGPoint?
        /// When the finger left the screen. A stationary hold-and-release can
        /// cancel the session without `didEndWith`, so the display link finishes
        /// it once this is older than `endWatchdog`.
        private var touchEndedAt: CFTimeInterval?

        init(_ parent: PlanDragHandle) {
            self.parent = parent
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            itemsForBeginning session: UIDragSession
        ) -> [UIDragItem] {
            let item = UIDragItem(
                itemProvider: NSItemProvider(
                    item: parent.itemID.uuidString as NSString,
                    typeIdentifier: UTType.planRow.identifier
                )
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

        /// Runs before the lift animation. `sessionWillBegin` is the fallback:
        /// the setup is idempotent so a skipped lift callback still gets a card.
        func dragInteraction(
            _ interaction: UIDragInteraction,
            willAnimateLiftWith animator: UIDragAnimating,
            session: UIDragSession
        ) {
            beginLift(session: session, interaction: interaction)
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            sessionWillBegin session: UIDragSession
        ) {
            beginLift(session: session, interaction: interaction)
        }

        /// The cancel animation starts at finger-up, before `didEndWith`. Send
        /// the card back to the slot it lifted from so it does not hang at the
        /// release point while the row returns; `didEndWith` removes it.
        func dragInteraction(
            _ interaction: UIDragInteraction,
            item: UIDragItem,
            willAnimateCancelWith animator: UIDragAnimating
        ) {
            returnPreviewHome()
        }

        @objc func handlePress(_ recognizer: UILongPressGestureRecognizer) {
            MainActor.assumeIsolated {
                switch recognizer.state {
                case .began:
                    guard dragSession == nil, let size = measuredSize else { return }
                    cachedPreview = makePreviewImage(
                        scale: recognizer.view?.window?.screen.scale ?? 3,
                        size: size
                    )
                case .ended, .cancelled, .failed:
                    if dragSession == nil {
                        // No lift means no drag; drop the render rather than hold it.
                        cachedPreview = nil
                    } else if touchEndedAt == nil {
                        touchEndedAt = CACurrentMediaTime()
                    }
                default:
                    break
                }
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        /// Called when SwiftUI hands the grip new content, so a name or number
        /// edited since the last touch-down is not baked into the lift card.
        func invalidateCachedPreview() {
            cachedPreview = nil
        }

        private func beginLift(session: UIDragSession, interaction: UIDragInteraction) {
            guard dragSession == nil else { return }
            guard let source = interaction.view, let window = source.window else { return }

            // Render before any state write: the writes re-render the row, which
            // would clear the cache this lift depends on.
            let frame = resolvedFrame(source, in: window)
            let image = cachedPreview
                ?? makePreviewImage(scale: window.screen.scale, size: frame.size)
                ?? fallbackPreview(size: frame.size)

            dragSession = session
            sourceWindow = window
            touchEndedAt = nil

            parent.dropTargetID = nil
            parent.draggingID = parent.itemID
            parent.onDragBegan()

            let layer = CALayer()
            layer.contents = image.cgImage
            layer.contentsScale = image.scale
            layer.bounds = CGRect(origin: .zero, size: image.size)
            layer.actions = [
                "position": NSNull(),
                "bounds": NSNull(),
                "transform": NSNull(),
                "contents": NSNull(),
                "opacity": NSNull()
            ]
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.7
            layer.shadowRadius = 26
            layer.shadowOffset = CGSize(width: 0, height: 16)
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: parent.previewCornerRadius
            ).cgPath
            window.layer.addSublayer(layer)
            previewLayer = layer

            // A short grow makes the lift read as picking the card up rather
            // than swapping the row for a picture.
            layer.transform = CATransform3DMakeScale(dragLiftScale, dragLiftScale, 1)
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 1
            grow.toValue = dragLiftScale
            grow.duration = 0.12
            grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(grow, forKey: "lift")

            // Lift from the card's own slot and keep that grab point under the
            // finger. The list may move; the card must not.
            let home = CGPoint(x: frame.midX, y: frame.midY)
            let grab = session.location(in: window)
            grabOffset = CGPoint(x: home.x - grab.x, y: home.y - grab.y)
            positionPreview(at: grab)
            liftPosition = home

            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tick() {
            MainActor.assumeIsolated {
                guard let session = dragSession,
                      let window = sourceWindow,
                      previewLayer != nil
                else { return }
                if let ended = touchEndedAt {
                    // Finger-up with no crossing can end the session without
                    // telling the delegate; finish it rather than freeze.
                    if CACurrentMediaTime() - ended > dragEndWatchdog {
                        finishDrag(operation: .cancel)
                    }
                    return
                }
                positionPreview(at: session.location(in: window))
            }
        }

        /// The card keeps the offset it was grabbed with; nothing clamps it to
        /// the window, so a grip at the row's right edge keeps the card to its
        /// left and the finger stays on the same point the whole way.
        private func positionPreview(at point: CGPoint) {
            guard let previewLayer, let grabOffset else { return }
            guard point.x.isFinite, point.y.isFinite else { return }
            previewLayer.position = CGPoint(
                x: point.x + grabOffset.x,
                y: point.y + grabOffset.y
            )
        }

        /// The card only: no shadow, no shadow padding. The layer draws the
        /// shadow with a path, so no Gaussian blur is rasterized per lift.
        /// The size is the row card's own size, so the lift covers the row.
        private func makePreviewImage(scale: CGFloat, size: CGSize) -> UIImage? {
            let renderer = ImageRenderer(content: parent.preview(size))
            renderer.scale = scale
            return renderer.uiImage
        }

        /// A card that cannot fail, so a render that comes back empty can never
        /// leave the source row hidden behind no card at all.
        private func fallbackPreview(size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let path = UIBezierPath(
                    roundedRect: CGRect(origin: .zero, size: size),
                    cornerRadius: parent.previewCornerRadius
                )
                UIColor(Theme.background).setFill()
                path.fill()
                UIColor.white.withAlphaComponent(0.14).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        }

        private var measuredSize: CGSize? {
            let size = parent.metrics.rect.size
            return size.width > 1 && size.height > 1 ? size : nil
        }

        /// The card's frame in window coordinates. A row that has not measured
        /// itself yet falls back to the grip, so a lift still gets a card near
        /// the finger instead of at the window's origin.
        private func resolvedFrame(_ source: UIView, in window: UIWindow) -> CGRect {
            let measured = parent.metrics.rect
            guard measured.width > 1, measured.height > 1 else {
                return source.convert(source.bounds, to: window)
            }
            return measured
        }

        /// Removes the card and stops the display link. Safe to call twice: the
        /// cancel callback or a cleared drag binding hides it, then `didEndWith`
        /// repeats the call as part of the full teardown.
        private func hidePreview() {
            displayLink?.invalidate()
            displayLink = nil
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
            liftPosition = nil
            grabOffset = nil
            touchEndedAt = nil
        }

        /// A drop clears `draggingID` before the system's drop animation ends.
        /// Move the card onto the slot that took the row and shrink it back into
        /// it over the same beat the row fades in, so the card lands instead of
        /// vanishing mid-air.
        private func settlePreview() {
            guard let layer = previewLayer else { return }
            displayLink?.invalidate()
            displayLink = nil
            previewLayer = nil
            liftPosition = nil
            grabOffset = nil
            touchEndedAt = nil

            let slot = parent.metrics.rect
            let target = slot.isEmpty ? layer.position : CGPoint(x: slot.midX, y: slot.midY)
            let duration: CFTimeInterval = 0.16

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = layer.position
            move.toValue = target
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = dragLiftScale
            shrink.toValue = 1
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
            fade.toValue = 0
            // Hold the card opaque while it slides onto the slot, then fade it:
            // fading during the slide shows the row underneath through it.
            fade.beginTime = CACurrentMediaTime() + 0.05
            fade.duration = duration - 0.05
            fade.fillMode = .both

            for animation in [move, shrink] {
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
            }
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fade.isRemovedOnCompletion = false

            layer.position = target
            layer.transform = CATransform3DIdentity
            layer.opacity = 0
            layer.add(move, forKey: "settle.position")
            layer.add(shrink, forKey: "settle.scale")
            layer.add(fade, forKey: "settle.opacity")

            // Captured layer: a new drag can start while this one settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                layer.removeFromSuperlayer()
            }
        }

        /// On a cancel, send the card back to the slot it lifted from, shrinking
        /// and fading as it lands under the returning row.
        private func returnPreviewHome() {
            guard let layer = previewLayer, let home = liftPosition else {
                hidePreview()
                return
            }
            displayLink?.invalidate()
            displayLink = nil
            touchEndedAt = nil

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = layer.position
            move.toValue = home
            move.duration = 0.25
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = dragLiftScale
            shrink.toValue = 1
            shrink.duration = 0.25
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
            fade.toValue = 0
            fade.duration = 0.18
            fade.beginTime = CACurrentMediaTime() + 0.07

            for animation in [move, shrink] {
                animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
            }
            // Both: hold the card visible through the delay, then at zero.
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            fade.fillMode = .both
            fade.isRemovedOnCompletion = false

            layer.position = home
            layer.transform = CATransform3DIdentity
            layer.opacity = 0
            layer.add(move, forKey: "return.position")
            layer.add(shrink, forKey: "return.scale")
            layer.add(fade, forKey: "return.opacity")
        }

        func hidePreviewIfDragEnded() {
            guard dragSession != nil, parent.draggingID == nil else { return }
            settlePreview()
        }

        /// One teardown for every end: the system's callback, and the watchdog
        /// that catches a release UIKit never reports.
        private func finishDrag(operation: UIDropOperation) {
            hidePreview()
            dragSession = nil
            sourceWindow = nil
            cachedPreview = nil
            parent.draggingID = nil
            parent.dropTargetID = nil
            parent.onDragEnded(operation == .move)
        }

        func dragInteraction(
            _ interaction: UIDragInteraction,
            session: UIDragSession,
            didEndWith operation: UIDropOperation
        ) {
            finishDrag(operation: operation)
        }
    }
}
