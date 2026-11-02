import SwiftUI

// MARK: - PreferenceKeys for frame tracking in named coordinate space

struct OffersAddButtonFrameKey: PreferenceKey {
    typealias Value = [UUID: CGRect]
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct OffersCartBadgeFrameKey: PreferenceKey {
    typealias Value = CGRect
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let n = nextValue()
        if n != .zero { value = n }
    }
}

// MARK: - OffersView (entry point for the Offers tab)

struct OffersView: View {
    @EnvironmentObject var model: AppModel

    @State private var selectedOffer: Offer? = nil
    @State private var isRefreshing = false
    @State private var refreshProgress: CGFloat = 0
    @State private var revealedRows: Set<UUID> = []
    @State private var cartBadgeBump = false

    // Fly-to-cart overlay state
    @State private var flyingOffers: [OffersFlightToken] = []

    // Cart badge position anchor (in "offersRoot" space)
    @State private var cartBadgeFrame: CGRect = .zero

    // Add-button frames keyed by offer ID (in "offersRoot" space)
    @State private var addButtonFrames: [UUID: CGRect] = [:]

    var body: some View {
        let theme = model.theme

        ZStack(alignment: .top) {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                offersHeader(theme: theme)
                refreshBar(theme: theme)
                offersList(theme: theme)
            }

            // Fly-to-cart particles overlay (rendered above everything, same coordinate space)
            ForEach(flyingOffers) { token in
                OffersCartFlyParticle(
                    token: token,
                    targetFrame: cartBadgeFrame,
                    theme: theme,
                    onLand: {
                        flyingOffers.removeAll { $0.id == token.id }
                        // Bump the badge
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                            cartBadgeBump = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            cartBadgeBump = false
                        }
                    }
                )
            }
        }
        // Named coordinate space — all frame captures and .position() use this same space
        .coordinateSpace(name: "offersRoot")
        // Receive cart-badge frame updates from the header
        .onPreferenceChange(OffersCartBadgeFrameKey.self) { frame in
            cartBadgeFrame = frame
        }
        // Receive add-button frame updates from each row
        .onPreferenceChange(OffersAddButtonFrameKey.self) { frames in
            addButtonFrames = frames
        }
        .onReceive(Harness.shared.addRequests) { index in
            let offer = model.offers[index]
            model.addToCart(offer)
            let frame = addButtonFrames[offer.id] ?? .zero
            Harness.shared.log("add frame \(frame) -> badge \(cartBadgeFrame)")
            spawnFlyParticle(offer: offer, from: frame)
        }
        .sheet(item: $selectedOffer) { offer in
            RedeemView(offer: offer)
                .environmentObject(model)
        }
    }

    // MARK: Header

    @ViewBuilder
    private func offersHeader(theme: Theme) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Offers")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            Spacer()

            // Cart badge — report its frame in "offersRoot" space via PreferenceKey
            OffersCartBadge(
                count: model.cartCount,
                bump: cartBadgeBump,
                theme: theme
            )
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: OffersCartBadgeFrameKey.self,
                        value: geo.frame(in: .named("offersRoot"))
                    )
                }
            )

            // Refresh button
            OffersRefreshButton(isRefreshing: isRefreshing, theme: theme) {
                triggerRefresh()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Refresh bar

    @ViewBuilder
    private func refreshBar(theme: Theme) -> some View {
        if isRefreshing {
            OffersRefreshBar(progress: refreshProgress, theme: theme)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }

    // MARK: Offers list

    @ViewBuilder
    private func offersList(theme: Theme) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(Array(model.offers.enumerated()), id: \.element.id) { index, offer in
                    OffersRow(
                        offer: offer,
                        offerId: offer.id,
                        isRevealed: revealedRows.contains(offer.id),
                        theme: theme,
                        onLike: {
                            model.toggleLike(offer)
                        },
                        onAdd: {
                            model.addToCart(offer)
                            let frame = addButtonFrames[offer.id] ?? .zero
                            spawnFlyParticle(offer: offer, from: frame)
                        },
                        onRedeem: {
                            selectedOffer = offer
                        }
                    )
                    .offset(y: revealedRows.contains(offer.id) ? 0 : 30)
                    .opacity(revealedRows.contains(offer.id) ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 4)
        }
        .onAppear {
            revealRowsStaggered(offers: model.offers)
        }
    }

    // MARK: Refresh logic

    private func triggerRefresh() {
        guard !isRefreshing else { return }
        llog("offers: refresh")
        // Keep rows visible while the pill loader runs — don't clear revealedRows yet
        withAnimation(.easeIn(duration: 0.15)) {
            isRefreshing = true
            refreshProgress = 0
        }
        // Animate pill fill over 1.2s
        withAnimation(.easeInOut(duration: 1.2)) {
            refreshProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeOut(duration: 0.2)) {
                isRefreshing = false
                refreshProgress = 0
            }
            // Only now hide rows so the re-stagger is visible
            revealedRows.removeAll()
            revealRowsStaggered(offers: model.offers)
        }
    }

    private func revealRowsStaggered(offers: [Offer]) {
        for (i, offer) in offers.enumerated() {
            let id = offer.id
            let delay: Double = Double(i) * 0.09
            let deadline: DispatchTime = .now() + delay
            DispatchQueue.main.asyncAfter(deadline: deadline) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    _ = revealedRows.insert(id)
                }
            }
        }
    }

    // MARK: Fly-to-cart

    private func spawnFlyParticle(offer: Offer, from sourceFrame: CGRect) {
        let token = OffersFlightToken(
            id: UUID(),
            symbol: offer.symbol,
            accentColor: offer.accentColor,
            startFrame: sourceFrame
        )
        flyingOffers.append(token)
    }
}

// MARK: - OffersCartBadge

struct OffersCartBadge: View {
    let count: Int
    let bump: Bool
    let theme: Theme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.surface)
                .overlay(Circle().stroke(theme.separator, lineWidth: 1))
                .frame(width: 42, height: 42)

            Image(systemName: "cart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: theme.brand, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .offset(x: 11, y: -12)
                    .scaleEffect(bump ? 1.45 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.45), value: bump)
            }
        }
        .scaleEffect(bump ? 1.12 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.45), value: bump)
    }
}

// MARK: - OffersRefreshButton

struct OffersRefreshButton: View {
    let isRefreshing: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.surface)
                    .overlay(Circle().stroke(theme.separator, lineWidth: 1))
                    .frame(width: 42, height: 42)

                if isRefreshing {
                    LumenSpinner(size: 20, gradient: theme.brand)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
    }
}

// MARK: - OffersRefreshBar

struct OffersRefreshBar: View {
    let progress: CGFloat
    let theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.surface)
                    .frame(height: 6)

                Capsule()
                    .fill(theme.brandGradient)
                    .frame(width: geo.size.width * progress, height: 6)
                    .animation(.easeInOut(duration: 1.2), value: progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - OffersRow

struct OffersRow: View {
    let offer: Offer
    let offerId: UUID
    let isRevealed: Bool
    let theme: Theme
    let onLike: () -> Void
    let onAdd: () -> Void
    let onRedeem: () -> Void

    var body: some View {
        Button(action: onRedeem) {
            HStack(spacing: 14) {
                // Icon circle
                OffersIconCircle(symbol: offer.symbol, accentColor: offer.accentColor)

                // Text block
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Text(offer.blurb)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Cashback badge
                OffersCashbackBadge(pct: offer.cashbackPct, theme: theme)

                // Like button — real Button so taps don't fall through to the row Button
                OffersLikeButton(liked: offer.liked, theme: theme, onTap: onLike)

                // Add button — reports its frame via PreferenceKey in "offersRoot" space
                OffersAddButton(theme: theme, onTap: onAdd)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: OffersAddButtonFrameKey.self,
                                value: [offerId: geo.frame(in: .named("offersRoot"))]
                            )
                        }
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.separator, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OffersIconCircle

struct OffersIconCircle: View {
    let symbol: String
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(accentColor)
        }
    }
}

// MARK: - OffersCashbackBadge

struct OffersCashbackBadge: View {
    let pct: Int
    let theme: Theme

    var body: some View {
        Text("\(pct)% back")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.black.opacity(0.75))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(theme.glowGradient)
            )
    }
}

// MARK: - OffersLikeButton (Animation 1: springy pop + ring burst)

struct OffersLikeButton: View {
    let liked: Bool
    let theme: Theme
    let onTap: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var ringScale: CGFloat = 0.1
    @State private var ringOpacity: Double = 0
    @State private var particlePhase: Double = 0
    @State private var showParticles: Bool = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Ring burst
                Circle()
                    .stroke(theme.magenta.opacity(ringOpacity), lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(ringScale)

                // Small particle dots
                if showParticles {
                    ForEach(0..<6, id: \.self) { i in
                        let angle = Double(i) / 6.0 * 2 * .pi
                        let r: CGFloat = 18 * particlePhase
                        Circle()
                            .fill(i % 2 == 0 ? theme.magenta : theme.violet)
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat(cos(angle)) * r,
                                y: CGFloat(sin(angle)) * r
                            )
                            .opacity(Double(1.0 - particlePhase))
                    }
                }

                // Heart icon
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(liked ? theme.magenta : theme.textSecondary)
                    .scaleEffect(scale)
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // onChange is the SOLE trigger for the pop/ring/particle animation — no inline call
        .onChange(of: liked) { newValue in
            if newValue {
                animateLike()
            } else {
                // Unlike: small bounce
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 0.85
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }
            }
        }
    }

    private func animateLike() {
        // Pop scale
        withAnimation(.spring(response: 0.28, dampingFraction: 0.42)) {
            scale = 1.55
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                scale = 1.0
            }
        }

        // Ring burst
        ringScale = 0.1
        ringOpacity = 0.9
        withAnimation(.easeOut(duration: 0.5)) {
            ringScale = 1.6
            ringOpacity = 0
        }

        // Particle dots
        showParticles = true
        particlePhase = 0
        withAnimation(.easeOut(duration: 0.55)) {
            particlePhase = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showParticles = false
            particlePhase = 0
        }
    }
}

// MARK: - OffersAddButton

struct OffersAddButton: View {
    let theme: Theme
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { pressed = false }
            }
            onTap()
        }) {
            Text("Add")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: theme.brand,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OffersFlightToken (data for fly-to-cart animation)

struct OffersFlightToken: Identifiable {
    let id: UUID
    let symbol: String
    let accentColor: Color
    let startFrame: CGRect
}

// MARK: - OffersCartFlyParticle (Animation 2: icon flies to cart)

struct OffersCartFlyParticle: View {
    let token: OffersFlightToken
    let targetFrame: CGRect
    let theme: Theme
    let onLand: () -> Void

    @State private var phase: CGFloat = 0   // 0 → 1
    @State private var hasLanded = false

    var body: some View {
        let start = CGPoint(
            x: token.startFrame.midX,
            y: token.startFrame.midY
        )
        let end = CGPoint(
            x: targetFrame.midX,
            y: targetFrame.midY
        )

        // Interpolated position
        let x = start.x + (end.x - start.x) * phase
        let rawY = start.y + (end.y - start.y) * phase
        // Arc upward in the middle
        let arcLift: CGFloat = -80 * sin(phase * .pi)
        let y = rawY + arcLift

        let iconScale = 1.0 - phase * 0.65

        ZStack {
            Circle()
                .fill(token.accentColor.opacity(0.2 * Double(1 - phase)))
                .frame(width: 38, height: 38)
            Image(systemName: token.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(token.accentColor)
        }
        .scaleEffect(iconScale)
        .opacity(Double(1.0 - max(0, phase - 0.75) / 0.25))
        .position(x: x, y: y)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                phase = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                guard !hasLanded else { return }
                hasLanded = true
                onLand()
            }
        }
    }
}
