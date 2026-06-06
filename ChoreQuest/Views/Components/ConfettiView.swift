import SwiftUI

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let birth: Date
    let startX: CGFloat       // 0...1 of width
    let angle: Double         // launch angle in radians (screen coords, y-down)
    let speed: CGFloat        // points / second
    let color: Color
    let size: CGFloat
    let spin: Double          // radians / second
    let lifetime: Double      // seconds
}

/// A lightweight confetti burst drawn with `Canvas` + `TimelineView` — no
/// third-party dependency. Increment `trigger` to fire a burst from the upper
/// middle of the view. The animation pauses itself when no pieces are alive.
struct ConfettiView: View {
    let trigger: Int

    @State private var pieces: [ConfettiPiece] = []

    private let gravity: Double = 900

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: pieces.isEmpty)) { timeline in
                Canvas { context, size in
                    let now = timeline.date
                    for piece in pieces {
                        let t = now.timeIntervalSince(piece.birth)
                        guard t >= 0, t < piece.lifetime else { continue }
                        draw(piece, t: t, size: size, into: context)
                    }
                }
            }
            .onChange(of: trigger) { _, _ in
                addBurst(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ piece: ConfettiPiece, t: Double, size: CGSize, into context: GraphicsContext) {
        let originX = piece.startX * size.width
        let originY = size.height * 0.42
        let vx = cos(piece.angle) * piece.speed
        let vy = sin(piece.angle) * piece.speed
        let x = originX + vx * t
        let y = originY + vy * t + 0.5 * gravity * t * t

        let progress = t / piece.lifetime
        let opacity = progress < 0.7 ? 1.0 : max(0, 1 - (progress - 0.7) / 0.3)

        var ctx = context
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .radians(piece.spin * t))
        ctx.opacity = opacity
        let rect = CGRect(
            x: -piece.size / 2,
            y: -piece.size / 2,
            width: piece.size,
            height: piece.size * 0.55
        )
        ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
    }

    private func addBurst(in size: CGSize) {
        guard size.width > 0 else { return }
        let colors = Palette.colors.map { Color(hex: $0) }
        let birth = Date()
        let newPieces = (0..<26).map { _ in
            ConfettiPiece(
                birth: birth,
                startX: CGFloat.random(in: 0.3...0.7),
                angle: Double.random(in: (-.pi * 0.85)...(-.pi * 0.15)), // upward fan
                speed: CGFloat.random(in: 250...620),
                color: colors.randomElement() ?? .accentColor,
                size: CGFloat.random(in: 7...12),
                spin: Double.random(in: -6...6),
                lifetime: Double.random(in: 1.1...1.7)
            )
        }
        pieces.append(contentsOf: newPieces)

        // Prune this batch once it has finished so the TimelineView can pause.
        let maxLife = (newPieces.map(\.lifetime).max() ?? 1.7) + 0.1
        Task {
            try? await Task.sleep(for: .seconds(maxLife))
            let cutoff = Date()
            pieces.removeAll { cutoff.timeIntervalSince($0.birth) >= $0.lifetime }
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State private var n = 0
        var body: some View {
            ZStack {
                Color(.systemBackground)
                ConfettiView(trigger: n)
                Button("Burst") { n += 1 }
            }
        }
    }
    return Wrapper()
}
