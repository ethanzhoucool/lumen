import SwiftUI

// MARK: - WalletView (entry point)

struct WalletView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    WalletHeader()
                    WalletBalanceBlock()
                        .padding(.top, 28)
                    WalletCardStack()
                        .padding(.top, 32)
                    WalletTrendingSection()
                        .padding(.top, 32)
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .onAppear { llog("wallet: appeared") }
    }
}

// MARK: - WalletHeader

private struct WalletHeader: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        HStack(alignment: .center) {
            Text("Wallet")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Spacer()
            WalletSyncBadge()
        }
    }
}

// MARK: - WalletSyncBadge  (Wi-Fi signal indicator)

struct WalletSyncBadge: View {
    @EnvironmentObject var model: AppModel
    @State private var pulse: Bool = false

    var body: some View {
        let theme = model.theme
        HStack(spacing: 6) {
            WalletWifiSignal(color: theme.success, pulse: pulse)
                .frame(width: 18, height: 14)
            Text("Synced just now")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(theme.surface)
                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
            ) { pulse = true }
        }
    }
}

// MARK: - WalletWifiSignal  (concentric pulsing arcs)

private struct WalletWifiSignal: View {
    var color: Color
    var pulse: Bool

    // Three arc layers: small / medium / large
    private let arcs: [(scale: CGFloat, delay: Double)] = [
        (0.38, 0.0),
        (0.65, 0.18),
        (1.00, 0.36)
    ]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack(alignment: .bottom) {
                ForEach(arcs.indices, id: \.self) { i in
                    WalletArcShape()
                        .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .frame(width: size * arcs[i].scale, height: size * arcs[i].scale * 0.6)
                        .opacity(pulse ? 1.0 : 0.25)
                        .animation(
                            .easeInOut(duration: 1.1)
                                .repeatForever(autoreverses: true)
                                .delay(arcs[i].delay),
                            value: pulse
                        )
                }
                // dot at bottom center
                Circle()
                    .fill(color)
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - WalletArcShape  (single upward-facing arc)

private struct WalletArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Draw a semicircular arc opening upward, centered at bottom-center
        var path = Path()
        let cx = rect.midX
        let cy = rect.maxY
        let r = min(rect.width, rect.height * 2) / 2
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: r,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        return path
    }
}

// MARK: - WalletBalanceBlock  (count-up animation)

private struct WalletBalanceBlock: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(spacing: 6) {
            Text("Cashback Balance")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(1.1)

            WalletCountUpText(
                value: model.balance,
                gradient: theme.glowGradient
            )

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.violet)
                Text("\(model.points.formatted()) Lumen points")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.top, 2)
        }
    }
}

// MARK: - WalletCountUpText

private struct WalletCountUpText: View {
    var value: Double
    var gradient: LinearGradient
    @State private var displayed: Double = 0
    @State private var hasAnimated = false
    @State private var runID = 0

    var body: some View {
        Text(displayed, format: .currency(code: "USD"))
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(gradient)
            .onAppear {
                guard !hasAnimated else { displayed = value; return }
                hasAnimated = true
                animate(to: value)
            }
            .onChange(of: value) { newValue in animate(to: newValue) }
    }

    // iOS 16-safe count-up: step the displayed value with an ease-out curve.
    private func animate(to target: Double) {
        runID += 1
        let token = runID
        let steps = 45
        let duration = 1.05
        let start = displayed
        for i in 0...steps {
            let frac = Double(i) / Double(steps)
            let eased = 1 - pow(1 - frac, 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * frac) {
                guard token == runID else { return }
                displayed = start + (target - start) * eased
            }
        }
    }
}

// MARK: - WalletCardStack  (swipeable depth stack)

struct WalletCardStack: View {
    @EnvironmentObject var model: AppModel
    @State private var order: [Int] = []           // indices into model.cards
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let stackSpacing: CGFloat = 14
    private let backScale: CGFloat = 0.92
    private let swipeThreshold: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let cardW = geo.size.width
            let cardH = geo.size.height

            ZStack {
                // Render from back to front so front card is on top
                ForEach(orderIndices.reversed(), id: \.self) { stackPos in
                    let cardIndex = order[stackPos]
                    let card = model.cards[cardIndex]
                    let isFront = stackPos == 0

                    WalletCardFace(card: card)
                        .frame(width: cardW, height: cardH)
                        .scaleEffect(isFront ? 1.0 : scale(for: stackPos))
                        .offset(y: isFront ? 0 : verticalOffset(for: stackPos))
                        .opacity(isFront ? 1.0 : opacity(for: stackPos))
                        .rotationEffect(isFront ? tiltAngle : .zero)
                        .offset(x: isFront ? dragOffset : 0)
                        .zIndex(Double(orderIndices.count - stackPos))
                        .gesture(
                            isFront ? dragGesture : nil
                        )
                }
            }
        }
        .frame(height: 220)
        .onAppear { initOrder() }
        .onChange(of: model.cards.count) { _ in initOrder() }
    }

    // MARK: Stack helpers

    private var orderIndices: [Int] { Array(0..<order.count) }

    private func initOrder() {
        guard order.count != model.cards.count else { return }
        order = Array(0..<model.cards.count)
    }

    private func scale(for pos: Int) -> CGFloat {
        let factor = CGFloat(pos) * (1 - backScale) / max(1, CGFloat(order.count - 1))
        return 1.0 - factor
    }

    private func verticalOffset(for pos: Int) -> CGFloat {
        CGFloat(pos) * stackSpacing
    }

    private func opacity(for pos: Int) -> Double {
        max(0.3, 1.0 - Double(pos) * 0.22)
    }

    private var tiltAngle: Angle {
        let progress = dragOffset / 200
        return .degrees(Double(progress) * 8)
    }

    // MARK: Drag gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.width
                if abs(dragOffset) > swipeThreshold || abs(velocity) > 300 {
                    cycleCard(toLeft: dragOffset < 0)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        dragOffset = 0
                    }
                }
                isDragging = false
            }
    }

    private func cycleCard(toLeft: Bool) {
        guard !order.isEmpty else { return }
        let swipedIndex = order[0]
        let brand = model.cards[swipedIndex].brand
        let flyOut: CGFloat = toLeft ? -500 : 500

        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            dragOffset = flyOut
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                var newOrder = order
                let front = newOrder.removeFirst()
                newOrder.append(front)
                order = newOrder
                dragOffset = 0
            }
            llog("wallet: swiped to \(brand)")
        }
    }
}

// MARK: - WalletCardFace

struct WalletCardFace: View {
    let card: RewardCard

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card base gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: card.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glossy highlight overlay
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.brand)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(card.tier)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    Spacer()
                    // Card chip icon
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 32, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .padding(4)
                        )
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        Text("Balance")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                        Spacer()
                    }
                    Text(card.balance, format: .currency(code: "USD"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                HStack {
                    Text("•••• •••• •••• \(card.last4)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.85))
                        .kerning(2)
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .shadow(color: card.gradient.first?.opacity(0.45) ?? .clear, radius: 20, x: 0, y: 10)
    }
}

// MARK: - WalletTrendingSection

private struct WalletTrendingSection: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trending")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("Live cashback")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }

            WalletMarquee()
        }
    }
}

// MARK: - WalletMarqueeWidthKey  (PreferenceKey for measuring one row)

private struct WalletMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - WalletMarquee  (infinitely looping horizontal scroller)

struct WalletMarquee: View {
    @EnvironmentObject var model: AppModel
    @State private var rowWidth: CGFloat = 0

    // Build chip data from offers. Chip ids come from the offers, so they stay the
    // same from one TimelineView tick to the next.
    private var chips: [WalletChipData] {
        model.offers.map {
            WalletChipData(id: $0.id, label: "\($0.merchant)  \($0.cashbackPct)% back", accent: $0.accentColor)
        }
    }

    // One tick = how far we scroll per second (pts/sec)
    private let speed: CGFloat = 42

    var body: some View {
        let chips = self.chips
        let modulusWidth = rowWidth > 0 ? rowWidth : CGFloat(chips.count) * 174

        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            let scrollOffset = (t * speed).truncatingRemainder(dividingBy: modulusWidth)

            GeometryReader { _ in
                HStack(spacing: 0) {
                    // Duplicate content so the loop is seamless
                    WalletMarqueeRow(chips: chips)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(key: WalletMarqueeWidthKey.self, value: proxy.size.width)
                            }
                        )
                    WalletMarqueeRow(chips: chips)
                }
                .offset(x: -scrollOffset)
            }
            .frame(height: 40)
            .clipped()
        }
        .onPreferenceChange(WalletMarqueeWidthKey.self) { width in
            if width > 0 { rowWidth = width }
        }
    }
}

// MARK: - WalletMarqueeRow

/// `id` must be stable: the marquee rebuilds its rows on every animation frame, and a
/// fresh UUID per rebuild made ForEach tear down and recreate every chip view each frame.
private struct WalletChipData: Identifiable {
    let id: UUID
    let label: String
    let accent: Color
}

private struct WalletMarqueeRow: View {
    let chips: [WalletChipData]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(chips) { chip in
                WalletMarqueeChip(label: chip.label, accent: chip.accent)
            }
        }
        .fixedSize()
        .padding(.horizontal, 5)
    }
}

// MARK: - WalletMarqueeChip

private struct WalletMarqueeChip: View {
    @EnvironmentObject var model: AppModel
    let label: String
    let accent: Color

    var body: some View {
        let theme = model.theme
        HStack(spacing: 6) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(theme.surface)
                .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
        )
        .onAppear { Harness.chipAppears += 1 }
    }
}
