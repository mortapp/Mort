//
//  MortWordmark.swift
//  MORT iOS V8 — Design System
//
//  The MORT wordmark: a thin monoline mark that reads as if drawn by light.
//  With the intro, the letters write themselves M -> O -> R -> T while a small
//  light point traces the stroke, then settle into quiet silver.
//

import SwiftUI

/// Tracks whether the launch handwriting intro already played this session.
@Observable
final class MortIntroState {
    var wordmarkPlayed: Bool = false
}

// Design space: 268 wide x 100 tall, monoline strokes, natural pen ordering.
private let designWidth: CGFloat = 268
private let designHeight: CGFloat = 100

private func wordmarkStrokes() -> [Path] {
    func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        for (i, pt) in pts.enumerated() {
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
    func oval(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Path {
        var p = Path()
        let n = 48
        for i in 0...n {
            let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(n)
            let pt = CGPoint(x: cx + rx * CGFloat(cos(a)), y: cy + ry * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    let m = poly([
        .init(x: 0, y: 88), .init(x: 0, y: 12), .init(x: 32, y: 58),
        .init(x: 64, y: 12), .init(x: 64, y: 88),
    ])
    let o = oval(cx: 101, cy: 50, rx: 25, ry: 38)
    let rBowl = poly([
        .init(x: 140, y: 88), .init(x: 140, y: 12), .init(x: 172, y: 12),
        .init(x: 184, y: 18), .init(x: 188, y: 32), .init(x: 184, y: 46),
        .init(x: 172, y: 52), .init(x: 140, y: 52),
    ])
    let rLeg = poly([.init(x: 146, y: 52), .init(x: 190, y: 88)])
    let tBar = poly([.init(x: 206, y: 14), .init(x: 266, y: 14)])
    let tStem = poly([.init(x: 236, y: 14), .init(x: 236, y: 88)])
    return [m, o, rBowl, rLeg, tBar, tStem]
}

/// Approximate stroke lengths so progress distributes naturally across letters.
private let strokeWeights: [CGFloat] = [1.0, 0.85, 0.95, 0.35, 0.28, 0.42]

struct MortWordmark: View {
    var animateIntro: Bool
    var settledOpacity: Double = 0.92

    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var progress: CGFloat = 0

    private var paths: [Path] { wordmarkStrokes() }

    var body: some View {
        Canvas { ctx, size in
            let scale = size.width / designWidth
            let dy = (size.height - designHeight * scale) / 2
            let total = strokeWeights.reduce(0, +)
            let drawn = progress * total
            var acc: CGFloat = 0
            let writing = progress < 1 && animateIntro && !reducedMotion

            for (i, path) in paths.enumerated() {
                let weight = strokeWeights[i]
                let local = max(0, min(1, (drawn - acc) / weight))
                acc += weight
                guard local > 0 else { continue }

                let transform = CGAffineTransform(translationX: 0, y: dy)
                    .scaledBy(x: scale, y: scale)
                let scaled = path.applying(transform)
                let trimmed = scaled.trimmedPath(from: 0, to: local)

                if writing {
                    // Brief glow while the invisible pen writes.
                    ctx.stroke(
                        trimmed,
                        with: .color(MortColor.ice2.opacity(0.20)),
                        style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round, lineJoin: .round)
                    )
                }
                ctx.stroke(
                    trimmed,
                    with: .color(
                        writing
                            ? MortColor.ice2.opacity(0.92)
                            : MortColor.silver2.opacity(settledOpacity)
                    ),
                    style: StrokeStyle(lineWidth: 3.4 * scale, lineCap: .round, lineJoin: .round)
                )

                // Tiny silver/ice light point that follows the current stroke.
                if writing, local < 1, let tip = trimmed.currentPoint {
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: tip.x - 9 * scale, y: tip.y - 9 * scale,
                            width: 18 * scale, height: 18 * scale
                        )),
                        with: .color(MortColor.ice2.opacity(0.30))
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: tip.x - 3.6 * scale, y: tip.y - 3.6 * scale,
                            width: 7.2 * scale, height: 7.2 * scale
                        )),
                        with: .color(MortColor.white)
                    )
                }
            }
        }
        .task {
            // Reduced Motion shows the settled wordmark immediately — same
            // meaning, no animation.
            guard animateIntro, !reducedMotion else {
                progress = 1
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeInOut(duration: 2.6)) { progress = 1 }
        }
        .accessibilityLabel("MORT")
    }
}

/// Static quiet wordmark (no intro) — used in compact brand moments.
struct MortWordmarkStatic: View {
    var opacity: Double = 0.9
    var body: some View {
        MortWordmark(animateIntro: false, settledOpacity: opacity)
    }
}

/// Small abstract motion mark — the MORT silver double-arrow identity glyph.
struct MortMotionMark: View {
    var tint: Color = MortColor.ice1

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let style = StrokeStyle(lineWidth: w * 0.085, lineCap: .round, lineJoin: .round)

            // Large chevron: forward/upward motion.
            var big = Path()
            big.move(to: .init(x: w * 0.10, y: h * 0.62))
            big.addLine(to: .init(x: w * 0.50, y: h * 0.18))
            big.addLine(to: .init(x: w * 0.90, y: h * 0.62))

            // Smaller chevron behind: the double-stroke motion feel.
            var small = Path()
            small.move(to: .init(x: w * 0.22, y: h * 0.84))
            small.addLine(to: .init(x: w * 0.50, y: h * 0.52))
            small.addLine(to: .init(x: w * 0.78, y: h * 0.84))

            ctx.stroke(small, with: .color(MortColor.silver1.opacity(0.55)), style: style)
            ctx.stroke(big, with: .color(tint), style: style)

            // Single razor-thin icy accent on the leading edge.
            var accent = Path()
            accent.move(to: .init(x: w * 0.90, y: h * 0.62))
            accent.addLine(to: .init(x: w * 0.72, y: h * 0.42))
            ctx.stroke(
                accent,
                with: .color(MortColor.blueLight3.opacity(0.65)),
                style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
