import SwiftUI
import UIKit

// MARK: - Logging

/// Greppable device-log prefix for Revyl replay. Every key event logs through here.
func llog(_ message: String) { print("[Lumen] \(message)") }

// MARK: - Color helpers

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Theme

/// Two full palettes (dark / light). The Profile light-switch toggles `AppModel.isDark`,
/// which swaps the whole app's palette plus `.preferredColorScheme`.
struct Theme {
    let bg: Color
    let surface: Color
    let surfaceHi: Color
    let textPrimary: Color
    let textSecondary: Color
    let separator: Color
    let violet: Color
    let magenta: Color
    let gold: Color
    let success: Color

    /// Primary brand gradient (violet -> magenta). Used on CTAs, the Lumen wordmark, accents.
    var brand: [Color] { [violet, magenta] }
    /// Warm "lumen" glow gradient for reward / cashback emphasis.
    var glow: [Color] { [Color(hex: 0xFBD9A0), gold, Color(hex: 0xE8932F)] }

    var brandGradient: LinearGradient {
        LinearGradient(colors: brand, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var glowGradient: LinearGradient {
        LinearGradient(colors: glow, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let dark = Theme(
        bg: Color(hex: 0x0A0A0F),
        surface: Color(hex: 0x14141C),
        surfaceHi: Color(hex: 0x1E1E2A),
        textPrimary: Color(hex: 0xF4F3FB),
        textSecondary: Color(hex: 0x9B98B3),
        separator: Color.white.opacity(0.08),
        violet: Color(hex: 0x7C5CFF),
        magenta: Color(hex: 0xC44CFF),
        gold: Color(hex: 0xF6C65B),
        success: Color(hex: 0x4ADE80)
    )

    static let light = Theme(
        bg: Color(hex: 0xF3F2FA),
        surface: Color(hex: 0xFFFFFF),
        surfaceHi: Color(hex: 0xF1EEFB),
        textPrimary: Color(hex: 0x16131F),
        textSecondary: Color(hex: 0x6B6880),
        separator: Color.black.opacity(0.10),
        violet: Color(hex: 0x6A45F5),
        magenta: Color(hex: 0xB033E8),
        gold: Color(hex: 0xD99524),
        success: Color(hex: 0x16A34A)
    )
}

// MARK: - Models

struct RewardCard: Identifiable, Hashable {
    let id = UUID()
    let brand: String
    let tier: String
    let balance: Double
    let last4: String
    let colors: [UInt]   // gradient hexes; resolved to Color where rendered

    var gradient: [Color] { colors.map { Color(hex: $0) } }
}

struct Offer: Identifiable, Hashable {
    let id = UUID()
    let merchant: String
    let blurb: String
    let cashbackPct: Int
    let symbol: String   // SF Symbol name
    let accent: UInt     // accent hex
    var liked: Bool = false

    var accentColor: Color { Color(hex: accent) }
}

// MARK: - App state

final class AppModel: ObservableObject {
    // Auth
    @Published var isAuthenticated = false

    // Appearance (driven by the Profile light-switch)
    @Published var isDark = true

    // Wallet
    @Published var balance: Double = 248.50      // cashback balance, dollars
    @Published var points: Int = 12_480           // Lumen points
    @Published var cards: [RewardCard] = RewardCard.sample

    // Offers
    @Published var offers: [Offer] = Offer.sample
    @Published var cartCount: Int = 0

    // Daily scratch reward
    @Published var dailyScratchClaimed = false
    @Published var lastClaimedAmount: Double = 0

    var theme: Theme { isDark ? .dark : .light }

    func signIn() {
        llog("auth: sign-in success")
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            isAuthenticated = true
        }
    }

    func signOut() {
        llog("auth: sign-out")
        withAnimation(.easeInOut) { isAuthenticated = false }
    }

    func toggleLike(_ offer: Offer) {
        guard let i = offers.firstIndex(of: offer) else { return }
        offers[i].liked.toggle()
        llog("offer like \(offers[i].liked ? "on" : "off"): \(offers[i].merchant)")
    }

    func addToCart(_ offer: Offer) {
        cartCount += 1
        llog("offer added to cart: \(offer.merchant) (cart=\(cartCount))")
    }

    /// Apply a redemption: credits cart count down and bumps balance.
    func redeem(_ offer: Offer, value: Double) {
        balance += value
        if cartCount > 0 { cartCount -= 1 }
        llog("redeemed \(offer.merchant) for $\(String(format: "%.2f", value)) (balance=$\(String(format: "%.2f", balance)))")
    }

    func claimScratch(_ amount: Double) {
        guard !dailyScratchClaimed else { return }
        dailyScratchClaimed = true
        lastClaimedAmount = amount
        balance += amount
        points += Int(amount * 10)
        llog("scratch claimed: $\(String(format: "%.2f", amount)) (balance=$\(String(format: "%.2f", balance)))")
    }

    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.45)) { isDark.toggle() }
        llog("theme -> \(isDark ? "dark" : "light")")
    }
}

extension RewardCard {
    static let sample: [RewardCard] = [
        RewardCard(brand: "Lumen Platinum", tier: "Signature",  balance: 1_284.20, last4: "4291", colors: [0x7C5CFF, 0xC44CFF]),
        RewardCard(brand: "Voyage",         tier: "Travel",     balance:   642.00, last4: "8810", colors: [0x12C2E9, 0x3A7BD5]),
        RewardCard(brand: "Ember",          tier: "Cashback",   balance:   318.75, last4: "2204", colors: [0xFBD786, 0xF6995C]),
        RewardCard(brand: "Bloom",          tier: "Dining",     balance:   126.40, last4: "5567", colors: [0xFF5F9E, 0xEF3B5B])
    ]
}

extension Offer {
    static let sample: [Offer] = [
        Offer(merchant: "Verde Market",  blurb: "Groceries & fresh produce", cashbackPct: 5,  symbol: "leaf.fill",            accent: 0x4ADE80),
        Offer(merchant: "Bloom Coffee",  blurb: "Daily brews & pastries",    cashbackPct: 8,  symbol: "cup.and.saucer.fill",  accent: 0xC97B53),
        Offer(merchant: "Nimbus Cloud",  blurb: "Storage & compute",         cashbackPct: 10, symbol: "cloud.fill",           accent: 0x60A5FA, liked: true),
        Offer(merchant: "Orbit Rides",   blurb: "Rides across the city",     cashbackPct: 4,  symbol: "car.fill",             accent: 0x7C5CFF),
        Offer(merchant: "Pixel Store",   blurb: "Apps, games & gadgets",     cashbackPct: 6,  symbol: "gamecontroller.fill",  accent: 0xF59E0B),
        Offer(merchant: "Skyline Air",   blurb: "Flights & getaways",        cashbackPct: 3,  symbol: "airplane",             accent: 0x22D3EE)
    ]
}

// MARK: - Shared reusable components
// Screens reference these; they MUST NOT be redefined elsewhere.

/// Indeterminate circular spinner (used by feeds / loading states).
struct LumenSpinner: View {
    var size: CGFloat = 28
    var gradient: [Color] = Theme.dark.brand
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(
                AngularGradient(colors: gradient + [gradient.first ?? .white], center: .center),
                style: StrokeStyle(lineWidth: max(2.5, size * 0.11), lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}

/// A one-shot confetti burst. Plays once when it appears — pieces launch (with a
/// small per-piece stagger), arc up under gravity, and fade out over ~1.5s — then
/// settles. It does NOT loop or re-burst.
struct ConfettiView: View {
    var colors: [Color] = [.pink, .purple, .yellow, .green, .blue, .orange]
    private let pieces = 90
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for i in 0..<pieces {
                    let seed = Double(i)
                    let phase = elapsed - seededRandom(seed + 3) * 0.18   // small launch stagger
                    guard phase >= 0, phase < 1.6 else { continue }       // one shot, then nothing
                    let x0 = (size.width / 2) + CGFloat(seededRandom(seed) - 0.5) * size.width * 0.28
                    let angle = (seededRandom(seed + 1) * 2 - 1) * .pi * 0.55
                    let speed = 240.0 + seededRandom(seed + 2) * 280.0
                    let vx = sin(angle) * speed
                    let vy = -cos(angle) * speed
                    let g = 560.0
                    let x = x0 + CGFloat(vx * phase)
                    let y = (size.height * 0.42) + CGFloat(vy * phase + 0.5 * g * phase * phase)
                    let opacity = max(0, 1 - phase / 1.5)
                    guard opacity > 0 else { continue }
                    let w = 6.0 + seededRandom(seed + 4) * 5.0
                    let h = 9.0 + seededRandom(seed + 5) * 6.0
                    let rot = Angle.degrees(phase * (180 + seededRandom(seed + 6) * 540))
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rot)
                    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                             with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { if start == nil { start = Date() } }
    }

    private func seededRandom(_ seed: Double) -> Double {
        let v = sin(seed * 127.1 + 311.7) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - Tab shell

struct MainTabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        TabView {
            WalletView()
                .tabItem { Label("Wallet", systemImage: "creditcard.fill") }
            OffersView()
                .tabItem { Label("Offers", systemImage: "tag.fill") }
            RewardsView()
                .tabItem { Label("Rewards", systemImage: "gift.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(theme.violet)
        .onAppear { Self.configureTabBar() }
    }

    /// Opaque tab bar that matches the current theme surface (instead of the default
    /// translucent material, which floats mismatched over the custom background).
    ///
    /// The colors are dynamic: they resolve against the bar's trait collection, which
    /// `.preferredColorScheme` flips together with the Profile light-switch. UIAppearance
    /// only styles a bar when it enters a window, so re-setting the proxy with static
    /// colors on every toggle never reached the bar that was already on screen.
    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themedColor { $0.surface }
        appearance.shadowColor = themedColor { $0.separator }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// A UIColor that picks the light or dark palette's value from the trait collection.
    private static func themedColor(_ pick: (Theme) -> Color) -> UIColor {
        let light = UIColor(pick(.light))
        let dark = UIColor(pick(.dark))
        return UIColor { traits in traits.userInterfaceStyle == .light ? light : dark }
    }
}

// MARK: - Root coordinator

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            model.theme.bg.ignoresSafeArea()
            if model.isAuthenticated {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(model.isDark ? .dark : .light)
        .onAppear { llog("launch") }
    }
}

@main
struct LumenApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
        }
    }
}
