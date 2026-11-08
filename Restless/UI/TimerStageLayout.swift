import SwiftUI

/// Marks a timer child so `TimerStageLayout` can place it by role instead of by
/// index. The block strip and watch strip come and go, so an index would drift.
enum TimerStageRole: LayoutValueKey {
    case header
    case blockStrip
    case positionStrip
    case hero
    case map
    case watch
    case actions

    static let defaultValue: TimerStageRole? = nil
}

/// The vertical placement maths for the timer stage, kept free of SwiftUI so
/// tests can cover a one-row and a three-row map, a wrapping position strip, a
/// tall map, and a short viewport.
struct TimerStageMetrics: Equatable {
    /// The gap between the ring and the map, the map and the watch strip, and
    /// the content and the actions.
    static let gap: CGFloat = 22
    /// The ring is never closer than this to the top chrome.
    static let chromeGap: CGFloat = 10

    let viewportHeight: CGFloat
    let chromeHeight: CGFloat
    let heroSide: CGFloat
    let mapHeight: CGFloat
    let watchHeight: CGFloat
    let actionsHeight: CGFloat

    /// The ring centre at the viewport's middle, clamped below the chrome when
    /// the two cannot both fit.
    var heroCenterY: CGFloat {
        max(viewportHeight / 2, chromeHeight + Self.chromeGap + heroSide / 2)
    }

    var heroTopY: CGFloat { heroCenterY - heroSide / 2 }

    var mapTopY: CGFloat { heroTopY + heroSide + Self.gap }

    var watchTopY: CGFloat {
        watchHeight > 0 ? mapTopY + mapHeight + Self.gap : mapTopY + mapHeight
    }

    var belowBottomY: CGFloat {
        watchHeight > 0 ? watchTopY + watchHeight : mapTopY + mapHeight
    }

    /// The actions sit at the bottom when they fit and below the below-ring
    /// content when the map is too tall.
    var actionsTopY: CGFloat {
        max(belowBottomY + Self.gap, viewportHeight - actionsHeight)
    }

    var totalHeight: CGFloat {
        max(viewportHeight, actionsTopY + actionsHeight)
    }
}

/// Places the timer's chrome, ring, map, watch strip, and actions against one
/// fixed ring centre. Its height is at least the viewport, so a tall map makes
/// the enclosing ScrollView scroll instead of moving the ring.
struct TimerStageLayout: Layout {
    let viewportHeight: CGFloat
    let heroSide: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(width: width, height: metrics(width: width, subviews: subviews).totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let width = bounds.width
        let metrics = metrics(width: width, subviews: subviews)
        let x = bounds.midX

        placeChrome(subviews, width: width, origin: bounds.origin)

        if let hero = subview(.hero, in: subviews) {
            hero.place(
                at: CGPoint(x: x, y: bounds.minY + metrics.heroTopY),
                anchor: .top,
                proposal: ProposedViewSize(width: heroSide, height: heroSide)
            )
        }

        if let map = subview(.map, in: subviews) {
            map.place(
                at: CGPoint(x: x, y: bounds.minY + metrics.mapTopY),
                anchor: .top,
                proposal: ProposedViewSize(width: width, height: metrics.mapHeight)
            )
        }

        if let watch = subview(.watch, in: subviews), metrics.watchHeight > 0 {
            watch.place(
                at: CGPoint(x: x, y: bounds.minY + metrics.watchTopY),
                anchor: .top,
                proposal: ProposedViewSize(width: width, height: metrics.watchHeight)
            )
        }

        if let actions = subview(.actions, in: subviews) {
            actions.place(
                at: CGPoint(x: x, y: bounds.minY + metrics.actionsTopY),
                anchor: .top,
                proposal: ProposedViewSize(width: width, height: metrics.actionsHeight)
            )
        }
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> TimerStageMetrics {
        let header = size(of: .header, width: width, subviews: subviews)
        let blockStrip = size(of: .blockStrip, width: width, subviews: subviews)
        let positionStrip = size(of: .positionStrip, width: width, subviews: subviews)
        let map = size(of: .map, width: width, subviews: subviews)
        let watch = size(of: .watch, width: width, subviews: subviews)
        let actions = size(of: .actions, width: width, subviews: subviews)

        let chrome = header.height + blockStrip.height + positionStrip.height

        return TimerStageMetrics(
            viewportHeight: viewportHeight,
            chromeHeight: chrome,
            heroSide: heroSide,
            mapHeight: map.height,
            watchHeight: watch.height,
            actionsHeight: actions.height
        )
    }

    @discardableResult
    private func placeChrome(_ subviews: Subviews, width: CGFloat, origin: CGPoint) -> CGFloat {
        var y = origin.y

        if let header = subview(.header, in: subviews) {
            let height = header.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            header.place(
                at: CGPoint(x: origin.x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
            y += height
        }

        if let strip = subview(.blockStrip, in: subviews) {
            let height = strip.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            strip.place(
                at: CGPoint(x: origin.x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
            y += height
        }

        if let position = subview(.positionStrip, in: subviews) {
            let height = position.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            position.place(
                at: CGPoint(x: origin.x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
            y += height
        }

        return y
    }

    private func size(of role: TimerStageRole, width: CGFloat, subviews: Subviews) -> CGSize {
        guard let subview = subview(role, in: subviews) else { return .zero }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    private func subview(_ role: TimerStageRole, in subviews: Subviews) -> LayoutSubview? {
        subviews.first { $0[TimerStageRole.self] == role }
    }
}

extension View {
    func timerStageRole(_ role: TimerStageRole) -> some View {
        layoutValue(key: TimerStageRole.self, value: role)
    }
}
