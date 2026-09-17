//
//  MortAtmosphere.swift
//  MORT iOS V8 — Design System
//
//  The living MORT atmosphere: near-black sky, buried midnight-blue depth,
//  layered star field, drifting cloud banks, irregular meteors, and a rare
//  diagonal shimmer. Fully static (but still atmospheric) under Reduce Motion.
//

import SwiftUI

// MARK: - Model

private struct AtmoStar {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let alpha: Double
    let far: Bool
    let tint: Color
    let phase: Double
    let driftPerSec: CGFloat
}

private struct AtmoCloud {
    let seedX: CGFloat
    let seedY: CGFloat
    let rx: CGFloat
    let ry: CGFloat
    let tone: Color
    let alpha: Double
    let speedPerSec: CGFloat
    let rimLit: Bool
}

private struct AtmoMeteor: Identifiable {
    let id: Int
    let startX: CGFloat
    let startY: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let travel: CGFloat
    let duration: Double
    let startTime: Double
    let length: CGFloat
    let width: CGFloat
    let brightness: Double
}

/// Deterministic generator so the sky is stable across redraws.
private struct Seeded {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000.0
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
    mutating func bool(_ p: Double = 0.5) -> Bool { next() < p }
}

private func buildStars(width: CGFloat, height: CGFloat) -> [AtmoStar] {
    guard width > 0, height > 0 else { return [] }
    var rnd = Seeded(9)
    let tints: [Color] = [MortColor.starCold, MortColor.star, MortColor.starIce, MortColor.white]
    return (0..<95).map { _ in
        let far = rnd.bool(0.55)
        // Uneven distribution: one denser region, some sparse zones.
        let clustered = rnd.bool(0.32)
        let x: CGFloat = clustered
            ? width * CGFloat(0.45 + rnd.range(0.02, 0.5))
            : CGFloat(rnd.next()) * width
        return AtmoStar(
            x: x,
            y: CGFloat(rnd.next()) * height * 0.92,
            radius: far ? CGFloat(rnd.range(0.7, 1.8)) : CGFloat(rnd.range(1.1, 2.7)),
            alpha: (far ? 0.10 : 0.16) + rnd.range(0, 0.5),
            far: far,
            tint: rnd.bool(0.08) ? MortColor.starBlue : tints[Int(rnd.range(0, 3.99))],
            phase: rnd.range(0, .pi * 2),
            driftPerSec: far ? 0 : CGFloat(rnd.range(1.2, 3.4))
        )
    }
}

private func buildClouds(width: CGFloat, height: CGFloat) -> [AtmoCloud] {
    guard width > 0, height > 0 else { return [] }
    var rnd = Seeded(101)
    let scale = min(2.0, Double(width) / 420.0)
    var clouds: [AtmoCloud] = []
    for layer in 0..<3 {
        let count = 7 + layer * 3
        for _ in 0..<count {
            let roll = rnd.next()
            let tone: Color
            let alpha: Double
            if roll < 0.16 {
                tone = MortColor.night3   // midnight depth
                alpha = rnd.range(0.05, 0.12)
            } else if roll < 0.52 {
                tone = MortColor.graphite4 // graphite interior
                alpha = rnd.range(0.10, 0.19)
            } else {
                tone = MortColor.ink3      // black mass
                alpha = rnd.range(0.18, 0.32)
            }
            let rx = CGFloat(rnd.range(130, 390) * scale * (1 + Double(layer) * 0.28))
            clouds.append(AtmoCloud(
                seedX: CGFloat(rnd.next()) * width,
                seedY: height * CGFloat(0.42 + rnd.range(0, 0.52)),
                rx: rx,
                ry: rx * CGFloat(rnd.range(0.32, 0.62)),
                tone: tone,
                alpha: alpha,
                speedPerSec: CGFloat((1.6 + Double(layer) * 2.6) * scale),
                rimLit: layer >= 1 && rnd.bool(0.34)
            ))
        }
    }
    return clouds
}

private func buildMeteors(width: CGFloat, height: CGFloat, window: Double) -> [AtmoMeteor] {
    guard width > 0, height > 0 else { return [] }
    var rnd = Seeded(77)
    var meteors: [AtmoMeteor] = []
    var t = 3.5
    var id = 0
    // Natural irregular rhythm: meteor, pause, pause, small cluster, long pause.
    while t < window {
        let roll = rnd.next()
        let big = roll > 0.82
        let count = roll < 0.18 ? 2 : 1
        for k in 0..<count {
            let dirRight = rnd.bool()
            let angle = rnd.range(0.32, 0.54)
            let speed = rnd.range(520, 940) * (big ? 1.35 : 1.0)
            let travel = width * CGFloat(rnd.range(0.55, 1.05))
            meteors.append(AtmoMeteor(
                id: id,
                startX: dirRight
                    ? CGFloat(rnd.next()) * width * 0.6
                    : width * CGFloat(0.4 + rnd.range(0, 0.6)),
                startY: CGFloat(rnd.next()) * height * 0.42,
                dx: CGFloat((dirRight ? 1 : -1) * cos(angle)),
                dy: CGFloat(sin(angle)),
                travel: travel,
                duration: Double(travel) / speed,
                startTime: t + Double(k) * 0.9,
                length: CGFloat(rnd.range(110, 300) * (big ? 1.5 : 1.0)),
                width: CGFloat((big ? 2.6 : 1.6) + rnd.range(0, 0.9)),
                brightness: rnd.range(0.45, 1.0)
            ))
            id += 1
        }
        t += rnd.range(3.8, 13.0)
    }
    return meteors
}

// MARK: - Drawing

private func drawMeteor(
    _ ctx: inout GraphicsContext,
    _ m: AtmoMeteor,
    time: Double,
    intensity: Double
) {
    let local = time - m.startTime
    guard local > 0, local < m.duration else { return }
    let p = local / m.duration
    let eased = p * p * (3 - 2 * p)
    let headX = m.startX + m.dx * m.travel * CGFloat(eased)
    let headY = m.startY + m.dy * m.travel * CGFloat(eased)
    let tailX = headX - m.dx * m.length
    let tailY = headY - m.dy * m.length

    // Life envelope: quick fade-in, slow fade-out.
    let env = min(1.0, sin(.pi * p) * 1.6)
    let b = m.brightness * env * intensity
    guard b > 0.01 else { return }

    // transparent -> faint midnight blue -> silver -> ice -> bright head
    let gradient = Gradient(stops: [
        .init(color: MortColor.night2.opacity(0), location: 0),
        .init(color: MortColor.blueLight3.opacity(0.20 * b), location: 0.35),
        .init(color: MortColor.silver2.opacity(0.55 * b), location: 0.68),
        .init(color: MortColor.ice1.opacity(0.85 * b), location: 0.9),
        .init(color: MortColor.white.opacity(b), location: 1),
    ])
    var path = Path()
    path.move(to: CGPoint(x: tailX, y: tailY))
    path.addLine(to: CGPoint(x: headX, y: headY))
    ctx.stroke(
        path,
        with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: tailX, y: tailY),
            endPoint: CGPoint(x: headX, y: headY)
        ),
        style: StrokeStyle(lineWidth: m.width, lineCap: .round)
    )
    let head = CGPoint(x: headX, y: headY)
    ctx.fill(
        Path(ellipseIn: CGRect(
            x: head.x - m.width * 1.5, y: head.y - m.width * 1.5,
            width: m.width * 3, height: m.width * 3
        )),
        with: .color(MortColor.white.opacity(0.85 * b))
    )
    ctx.fill(
        Path(ellipseIn: CGRect(
            x: head.x - m.width * 4, y: head.y - m.width * 4,
            width: m.width * 8, height: m.width * 8
        )),
        with: .color(MortColor.ice2.opacity(0.18 * b))
    )
}

// MARK: - Atmosphere

/// The MORT background atmosphere. `intensity` attenuates everything (quieter
/// behind message, settings and receipt surfaces).
struct MortAtmosphere: View {
    var intensity: Double = 1.0
    var allowShimmer: Bool = true

    @Environment(\.mortReducedMotion) private var reducedMotion

    /// Frozen timestamp used when motion is suppressed — the sky still has
    /// stars, cloud banks and a meteor mid-flight, it simply does not move.
    private let staticTime: Double = 8.0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let stars = buildStars(width: size.width, height: size.height)
            let clouds = buildClouds(width: size.width, height: size.height)
            let meteors = buildMeteors(width: size.width, height: size.height, window: 180)

            ZStack {
                skyGradient(height: size.height)

                if reducedMotion {
                    canvas(stars: stars, clouds: clouds, meteors: meteors, time: staticTime, size: size)
                } else {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 180)
                        canvas(stars: stars, clouds: clouds, meteors: meteors, time: t, size: size)
                    }
                }

                // Gentle bottom vignette so UI surfaces sit into black.
                LinearGradient(
                    colors: [.clear, MortColor.black.opacity(0.55)],
                    startPoint: .init(x: 0.5, y: 0.55),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func skyGradient(height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    MortColor.black,
                    MortColor.ink1,
                    Color(hex: 0x02040A),
                    MortColor.night1.opacity(0.85),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [MortColor.night2.opacity(0.5), .clear],
                center: .init(x: 0.5, y: 1.05),
                startRadius: 0,
                endRadius: height * 0.95
            )
        }
    }

    private func canvas(
        stars: [AtmoStar],
        clouds: [AtmoCloud],
        meteors: [AtmoMeteor],
        time: Double,
        size: CGSize
    ) -> some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Far stars (almost stationary).
            for s in stars where s.far {
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: s.x.truncatingRemainder(dividingBy: max(w, 1)) - s.radius,
                        y: s.y - s.radius,
                        width: s.radius * 2, height: s.radius * 2
                    )),
                    with: .color(s.tint.opacity(s.alpha * intensity * 0.85))
                )
            }

            // Cloud banks drift horizontally and wrap.
            for c in clouds {
                let drift = CGFloat(time) * c.speedPerSec
                let x = (c.seedX - drift).truncatingRemainder(dividingBy: w + c.rx * 2)
                let cx = x < -c.rx ? x + w + c.rx * 2 : x
                let rect = CGRect(x: cx - c.rx, y: c.seedY - c.ry, width: c.rx * 2, height: c.ry * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(c.tone.opacity(c.alpha * intensity)))
                if c.rimLit {
                    // Only some upper edges catch light: mostly silver, rare cold blue.
                    var rim = Path()
                    rim.addArc(
                        center: CGPoint(x: cx, y: c.seedY),
                        radius: c.rx * 0.92,
                        startAngle: .degrees(197),
                        endAngle: .degrees(343),
                        clockwise: false
                    )
                    ctx.stroke(
                        rim,
                        with: .color(MortColor.ice2.opacity(0.05 * intensity)),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                    )
                }
            }

            // Near stars twinkle and drift slowly.
            for s in stars where !s.far {
                let twinkle = 0.68 + 0.32 * sin(time * (0.6 + s.phase) + s.phase)
                let x = (s.x + CGFloat(time) * s.driftPerSec)
                    .truncatingRemainder(dividingBy: max(w, 1))
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: x - s.radius, y: s.y - s.radius,
                        width: s.radius * 2, height: s.radius * 2
                    )),
                    with: .color(s.tint.opacity(s.alpha * intensity * twinkle))
                )
            }

            // Meteors.
            var context = ctx
            for m in meteors {
                drawMeteor(&context, m, time: time, intensity: intensity)
            }

            // Rare diagonal shimmer: a reflection, not a beam.
            if allowShimmer {
                let cycle = time.truncatingRemainder(dividingBy: 64)
                if cycle < 1.9 {
                    let p = cycle / 1.9
                    let env = sin(.pi * p)
                    let x = w * CGFloat(-0.4 + 1.8 * p)
                    var shimmer = Path(CGRect(x: x, y: -h * 0.4, width: w * 0.22, height: h * 1.8))
                    shimmer = shimmer.applying(
                        CGAffineTransform(translationX: w / 2, y: h / 2)
                            .rotated(by: -26 * .pi / 180)
                            .translatedBy(x: -w / 2, y: -h / 2)
                    )
                    context.fill(shimmer, with: .color(MortColor.ice2.opacity(0.03 * env * intensity)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Sparse meteors drawn ABOVE content — a few pass in front of the MORT
/// wordmark for real atmospheric depth. Non-interactive.
struct MortAtmosphereForeground: View {
    @Environment(\.mortReducedMotion) private var reducedMotion

    var body: some View {
        GeometryReader { geo in
            let meteors = buildMeteors(width: geo.size.width, height: geo.size.height, window: 180)
                .filter { $0.id % 3 == 0 }
            if reducedMotion {
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 180)
                    Canvas { ctx, _ in
                        var context = ctx
                        for m in meteors {
                            drawMeteor(&context, m, time: t, intensity: 0.6)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
