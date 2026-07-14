import SwiftUI

// MARK: - Rewards screen

struct RewardsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Daily Reward")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.brandGradient)
                        Text("Your personal scratch card, refreshed every day")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Card area
                    if model.dailyScratchClaimed {
                        RewardClaimedCard()
                    } else {
                        RewardScratchCardContainer()
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Prize constant

private let kPrizeAmount: Double = 14.20
private let kScratchMinSpacing: CGFloat = 5     // min pt between appended points (visual mask)
private let kScratchPointCap: Int = 3000        // high cap so already-scratched areas never "heal"
// Reveal once this fraction of the card AREA has actually been scratched off,
// so most of the prize is visible before it auto-completes. Higher = scratch more.
private let kRevealCoverage: Double = 0.5
private let kCoverageCols = 16
private let kCoverageRows = 10

// MARK: - Scratch card container (owns all scratch state)

struct RewardScratchCardContainer: View {
    @EnvironmentObject var model: AppModel

    // Scratch gesture state
    @State private var scratchPoints: [CGPoint] = []
    @State private var scratchedCells: Set<Int> = []   // coarse grid cells scratched (area coverage)
    @State private var lastCoverageLoc: CGPoint? = nil
    @State private var hasLoggedStart = false

    // Reveal state
    @State private var revealed = false
    @State private var foilOpacity: Double = 1.0
    @State private var prizeScale: CGFloat = 0.7
    @State private var prizeOpacity: Double = 0.0
    @State private var showConfetti = false
    @State private var showClaimButton = false

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                let cardWidth = min(geo.size.width, 340)
                let cardHeight: CGFloat = 220

                ZStack {
                    // ── Bottom layer: prize reveal ──────────────────────────
                    RewardPrizeLayer(
                        amount: kPrizeAmount,
                        scale: prizeScale,
                        opacity: prizeOpacity
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    // ── Top layer: foil with scratch mask ──────────────────
                    RewardFoilLayer(
                        scratchPoints: scratchPoints,
                        cardSize: CGSize(width: cardWidth, height: cardHeight)
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .opacity(foilOpacity)
                    .gesture(
                        revealed ? nil :
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let local = value.location
                                // Only collect if within card bounds
                                guard local.x >= 0, local.y >= 0,
                                      local.x <= cardWidth, local.y <= cardHeight else { return }

                                if !hasLoggedStart {
                                    llog("rewards: scratch started")
                                    hasLoggedStart = true
                                }

                                let cardSize = CGSize(width: cardWidth, height: cardHeight)

                                // Track the scratched-off AREA (interpolated along the swipe).
                                markCoverage(from: lastCoverageLoc, to: local, cardSize: cardSize)
                                lastCoverageLoc = local

                                // Append a point for the visual hole-mask (decimated). Cap is high
                                // so already-scratched areas don't visually heal back.
                                if let last = scratchPoints.last {
                                    let dist = hypot(local.x - last.x, local.y - last.y)
                                    if dist >= kScratchMinSpacing { scratchPoints.append(local) }
                                } else {
                                    scratchPoints.append(local)
                                }
                                if scratchPoints.count > kScratchPointCap {
                                    scratchPoints.removeFirst(scratchPoints.count - kScratchPointCap)
                                }

                                // Auto-complete once enough of the card AREA has been scratched off.
                                let coverage = Double(scratchedCells.count) / Double(kCoverageCols * kCoverageRows)
                                if coverage >= kRevealCoverage && !revealed {
                                    triggerReveal()
                                }
                            }
                            .onEnded { _ in lastCoverageLoc = nil }
                    )

                    // ── Confetti burst overlay ─────────────────────────────
                    if showConfetti {
                        ConfettiView(colors: [.yellow, .purple, .pink, .green, .cyan, .orange])
                            .frame(width: cardWidth, height: cardHeight * 2)
                            .offset(y: -cardHeight * 0.5)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
            }
            .frame(height: 220)

            // Helper text / claim button
            if revealed && showClaimButton {
                RewardClaimButton(amount: kPrizeAmount)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity))
            } else if !revealed {
                Text("Scratch to reveal today's cashback")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(model.theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    private func triggerReveal() {
        guard !revealed else { return }
        llog("rewards: revealed")
        revealed = true

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            foilOpacity = 0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1)) {
            prizeScale = 1.0
            prizeOpacity = 1.0
        }
        showConfetti = true
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            showClaimButton = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showConfetti = false
        }
    }

    /// Mark the coarse grid cells covered by the brush along the segment from the
    /// previous touch to the current one, so coverage tracks real scratched area
    /// (and stays continuous on fast swipes).
    private func markCoverage(from a: CGPoint?, to b: CGPoint, cardSize: CGSize) {
        let cols = kCoverageCols, rows = kCoverageRows
        let cellW = cardSize.width / CGFloat(cols)
        let cellH = cardSize.height / CGFloat(rows)
        let brush: CGFloat = 23   // ≈ half the 46pt scratch stroke width
        let start = a ?? b
        let dx = b.x - start.x, dy = b.y - start.y
        let segLen = max(hypot(dx, dy), 0.001)
        let steps = max(1, Int(segLen / 6))
        for s in 0...steps {
            let t = CGFloat(s) / CGFloat(steps)
            let px = start.x + dx * t
            let py = start.y + dy * t
            let minC = max(0, Int((px - brush) / cellW))
            let maxC = min(cols - 1, Int((px + brush) / cellW))
            let minR = max(0, Int((py - brush) / cellH))
            let maxR = min(rows - 1, Int((py + brush) / cellH))
            guard minC <= maxC, minR <= maxR else { continue }
            for r in minR...maxR {
                for c in minC...maxC {
                    scratchedCells.insert(r * cols + c)
                }
            }
        }
    }
}

// MARK: - Prize layer (revealed underneath)

struct RewardPrizeLayer: View {
    @EnvironmentObject var model: AppModel
    var amount: Double
    var scale: CGFloat
    var opacity: Double

    @State private var glowPulse = false

    var body: some View {
        let theme = model.theme
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.surface)

            // Glow pulse behind the amount
            Ellipse()
                .fill(theme.glowGradient.opacity(glowPulse ? 0.45 : 0.2))
                .frame(width: 200, height: 110)
                .blur(radius: 32)
                .scaleEffect(glowPulse ? 1.12 : 1.0)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
                .onAppear { glowPulse = true }

            VStack(spacing: 8) {
                // Sparkle row
                HStack(spacing: 6) {
                    ForEach(["✦", "✧", "✦"], id: \.self) { s in
                        Text(s)
                            .font(.system(size: 11))
                            .foregroundColor(theme.gold.opacity(0.9))
                    }
                }

                // Prize amount
                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.glowGradient)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // Caption
                Text("You won cashback!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .opacity(opacity)
            }

            // Corner sparkle accents
            VStack {
                HStack {
                    Text("✦").font(.system(size: 16)).foregroundColor(theme.gold.opacity(0.6))
                    Spacer()
                    Text("✧").font(.system(size: 12)).foregroundColor(theme.violet.opacity(0.7))
                }
                Spacer()
                HStack {
                    Text("✧").font(.system(size: 10)).foregroundColor(theme.magenta.opacity(0.5))
                    Spacer()
                    Text("✦").font(.system(size: 14)).foregroundColor(theme.gold.opacity(0.55))
                }
            }
            .padding(18)
        }
    }
}

// MARK: - Foil layer (scratched away by the mask)

struct RewardFoilLayer: View {
    @EnvironmentObject var model: AppModel
    var scratchPoints: [CGPoint]
    var cardSize: CGSize

    var body: some View {
        let theme = model.theme

        ZStack {
            // Metallic gradient surface
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0xC8C0D8),
                            theme.violet.opacity(0.7),
                            Color(hex: 0xA89EC0),
                            theme.magenta.opacity(0.5),
                            Color(hex: 0xD0CCDE)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle sparkle dot pattern
            RewardSparklePattern()
                .opacity(0.35)

            // Hint label
            VStack(spacing: 6) {
                Text("✦  Scratch here  ✦")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Text("Daily cashback reward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .mask {
            RewardScratchMask(points: scratchPoints, size: cardSize)
        }
    }
}

// MARK: - Scratch mask (destination-out punch-through)

struct RewardScratchMask: View {
    var points: [CGPoint]
    var size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            // 1. Fill entire rect opaque — the foil is fully visible by default.
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.white)
            )

            guard !points.isEmpty else { return }

            // 2. Switch to destination-out to erase (punch holes in the mask).
            var ctx = context
            ctx.blendMode = .destinationOut

            if points.count == 1 {
                // Single tap: draw a filled dot so the first contact is immediately visible.
                let dotRadius: CGFloat = 23
                let pt = points[0]
                let dotRect = CGRect(
                    x: pt.x - dotRadius,
                    y: pt.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                ctx.fill(Path(ellipseIn: dotRect), with: .color(.white))
            } else {
                var path = Path()
                path.move(to: points[0])
                for pt in points.dropFirst() {
                    path.addLine(to: pt)
                }
                ctx.stroke(
                    path,
                    with: .color(.white),
                    style: StrokeStyle(
                        lineWidth: 46,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Decorative sparkle pattern on the foil

struct RewardSparklePattern: View {
    private let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (0.12, 0.18, 3.5), (0.35, 0.12, 2.5), (0.65, 0.20, 3.0),
        (0.85, 0.14, 2.0), (0.22, 0.50, 2.8), (0.78, 0.55, 3.2),
        (0.48, 0.75, 2.5), (0.08, 0.80, 2.0), (0.92, 0.75, 2.5),
        (0.55, 0.40, 2.2), (0.30, 0.85, 3.0), (0.72, 0.88, 2.5)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<dots.count, id: \.self) { i in
                let (rx, ry, r) = dots[i]
                Circle()
                    .fill(Color.white)
                    .frame(width: r * 2, height: r * 2)
                    .position(x: geo.size.width * rx, y: geo.size.height * ry)
            }
        }
    }
}

// MARK: - Claim button

struct RewardClaimButton: View {
    @EnvironmentObject var model: AppModel
    var amount: Double
    @State private var claimed = false
    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        let theme = model.theme

        Button {
            guard !claimed else { return }
            claimed = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                bounceScale = 1.12
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.15)) {
                bounceScale = 1.0
            }
            model.claimScratch(amount)
        } label: {
            HStack(spacing: 10) {
                if claimed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(claimed ? "Claimed!" : "Claim $\(String(format: "%.2f", amount))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                claimed
                    ? AnyShapeStyle(theme.success)
                    : AnyShapeStyle(theme.brandGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(bounceScale)
        }
        .disabled(claimed)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: claimed)
    }
}

// MARK: - Claimed state card

struct RewardClaimedCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.surface)

            // Soft glow
            Ellipse()
                .fill(theme.glowGradient.opacity(0.25))
                .frame(width: 200, height: 80)
                .blur(radius: 28)

            VStack(spacing: 14) {
                // Check badge
                ZStack {
                    Circle()
                        .fill(theme.success.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(theme.success)
                }

                // Amount
                Text("$\(String(format: "%.2f", model.lastClaimedAmount)) claimed")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.glowGradient)

                // Message
                VStack(spacing: 4) {
                    Text("You scratched today's reward!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text("Come back tomorrow for your next scratch")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: 340)
        .frame(height: 240)
    }
}
