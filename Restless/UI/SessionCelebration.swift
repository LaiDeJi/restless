import SwiftUI

/// The one-shot done effect: a short confetti burst over the done screen. It is
/// purely visual, ignores taps, and adds no accessibility element. With Reduce
/// Motion the particles are replaced by one static accent glow.
struct SessionCelebration: View {
    /// How long the overlay lives. The timer removes it after this.
    static let lifetime: TimeInterval = 2.5

    private static let pieceCount = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowOn = false
    @State private var startedAt = Date.now

    var body: some View {
        Group {
            if reduceMotion {
                glow
            } else {
                confetti
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var confetti: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                drawPieces(in: &context, size: size, elapsed: elapsed)
            }
        }
        .allowsHitTesting(false)
    }

    private var glow: some View {
        GeometryReader { proxy in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Theme.setAccent.opacity(0.24),
                            Theme.roundAccent.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 480, height: 480)
                .position(x: proxy.size.width / 2, y: proxy.size.height * 0.38)
                .opacity(glowOn ? 1 : 0)
                .animation(.easeOut(duration: 0.35), value: glowOn)
                .onAppear { glowOn = true }
        }
        .allowsHitTesting(false)
    }

    private func drawPieces(in context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let colors: [Color] = [Theme.setAccent, .white, Theme.roundAccent]
        let life = Self.lifetime
        let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.42)

        for index in 0..<Self.pieceCount {
            let piece = Piece(index: index)
            let delay = piece.delay
            let pieceTime = elapsed - delay
            guard pieceTime > 0, pieceTime < life - delay else { continue }

            let progress = pieceTime / (life - delay)
            let fadeIn = min(1, progress / 0.08)
            let fadeOut = min(1, (1 - progress) / 0.35)
            let opacity = max(0, min(fadeIn, fadeOut))
            let x = origin.x + piece.velocityX * size.width * progress
            let y = origin.y + piece.velocityY * size.height * progress
                + 0.7 * size.height * progress * progress
            let rect = CGRect(
                x: -piece.width / 2,
                y: -piece.height / 2,
                width: piece.width,
                height: piece.height
            )
            var pieceContext = context
            pieceContext.opacity = opacity
            pieceContext.translateBy(x: x, y: y)
            pieceContext.rotate(by: .degrees(piece.spin * progress * 360))
            pieceContext.fill(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(colors[index % colors.count])
            )
        }
    }
}

/// Deterministic piece geometry, so the burst looks the same on every run and
/// every re-render.
private struct Piece {
    /// Seconds before this piece joins the burst.
    let delay: Double
    /// Horizontal travel over the piece's life, as a fraction of the width.
    let velocityX: Double
    /// Vertical launch, as a fraction of the height; gravity finishes the fall.
    let velocityY: Double
    /// Turns over the piece's life.
    let spin: Double
    let width: CGFloat
    let height: CGFloat

    init(index: Int) {
        let seed = UInt64(index) * 2_654_435_761 &+ 1
        let angle = (Double(index) / 48.0 * 2 * .pi) + Double((seed >> 3) % 40) / 40 * 0.3
        let speed = 0.18 + Double((seed >> 7) % 40) / 100
        velocityX = cos(angle) * speed
        velocityY = sin(angle) * speed * 0.65 - 0.28
        delay = Double((seed >> 11) % 100) / 100 * 0.18
        spin = (Double((seed >> 5) % 3) + 1) * ((seed >> 9) % 2 == 0 ? -1 : 1)
        width = 5 + CGFloat((seed >> 13) % 4)
        height = 8 + CGFloat((seed >> 15) % 6)
    }
}
