import SwiftUI

// MARK: - ProfileView (entry point)

struct ProfileView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ProfileHeader()
                    ProfileStatRow()
                    ProfileAppearanceCard()
                    ProfilePreferencesCard()
                    ProfileSyncCard()
                    ProfileSignOutButton()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { llog("profile: appeared") }
    }
}

// MARK: - Header

struct ProfileHeader: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(spacing: 10) {
            // Gradient avatar
            ZStack {
                Circle()
                    .fill(theme.brandGradient)
                    .frame(width: 80, height: 80)
                    .shadow(color: theme.violet.opacity(0.45), radius: 18, x: 0, y: 8)
                Text("EZ")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 12)

            Text("Ethan Zhou")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)

            // Tier chip
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Signature Member")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(theme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(theme.gold.opacity(0.14))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}

// MARK: - Stat Row

struct ProfileStatChip: View {
    let label: String
    let value: String
    let accent: Color
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(accent)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ProfileStatRow: View {
    @EnvironmentObject var model: AppModel

    var formattedBalance: String {
        String(format: "$%.2f", model.balance)
    }

    var formattedPoints: String {
        model.points >= 1000
            ? String(format: "%.1fk", Double(model.points) / 1000)
            : "\(model.points)"
    }

    var body: some View {
        let theme = model.theme
        HStack(spacing: 10) {
            ProfileStatChip(label: "Cashback", value: formattedBalance, accent: theme.gold)
            ProfileStatChip(label: "Points", value: formattedPoints, accent: theme.violet)
            ProfileStatChip(label: "Tier", value: "Signature", accent: theme.magenta)
        }
    }
}

// MARK: - Section Card Container

struct ProfileSectionCard<Content: View>: View {
    let title: String
    @EnvironmentObject var model: AppModel
    @ViewBuilder var content: () -> Content

    var body: some View {
        let theme = model.theme
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(0.6)
            content()
        }
        .padding(20)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - 1. Light Switch (Appearance Toggle)

struct ProfileBulbRays: View {
    let isOn: Bool
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2, height: isOn ? 8 : 4)
                    .opacity(isOn ? 0.9 : 0.3)
                    .offset(y: -(isOn ? 22 : 18))
                    .rotationEffect(.degrees(angle))
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.6)
                            .delay(Double(i) * 0.02),
                        value: isOn
                    )
            }
        }
    }
}

struct ProfileLightSwitch: View {
    @EnvironmentObject var model: AppModel

    // The switch knob is "on" when light mode is active (not dark)
    private var isOn: Bool { !model.isDark }

    var body: some View {
        let theme = model.theme
        HStack(spacing: 16) {
            // Bulb + rays assembly
            ZStack {
                // Outer glow halo
                Circle()
                    .fill(Color(hex: 0xF6C65B).opacity(isOn ? 0.22 : 0))
                    .frame(width: 54, height: 54)
                    .animation(.easeInOut(duration: 0.4), value: isOn)

                // Rays
                ProfileBulbRays(isOn: isOn, color: Color(hex: 0xF6C65B))

                // Bulb body
                ZStack {
                    Circle()
                        .fill(
                            isOn
                                ? LinearGradient(colors: [Color(hex: 0xFDE68A), Color(hex: 0xF6C65B)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [theme.surfaceHi, theme.surfaceHi],
                                                 startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: Color(hex: 0xF6C65B).opacity(isOn ? 0.6 : 0), radius: isOn ? 12 : 0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: isOn)

                    // Filament cross detail
                    Image(systemName: isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isOn ? .white : theme.textSecondary)
                        .animation(.easeInOut(duration: 0.2), value: isOn)
                }
            }
            .frame(width: 54, height: 54)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text("Appearance")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(isOn ? "Light mode" : "Dark mode")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textSecondary)
                    .animation(.easeInOut(duration: 0.2), value: isOn)
            }

            Spacer()

            // Pull-cord / toggle knob
            ProfilePullCord(isOn: isOn)
                .onTapGesture { model.toggleTheme() }
        }
    }
}

struct ProfilePullCord: View {
    let isOn: Bool
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        ZStack {
            // Track
            Capsule()
                .fill(isOn ? Color(hex: 0xF6C65B).opacity(0.25) : Color(hex: 0x3A3A4A))
                .frame(width: 52, height: 30)
                .overlay(
                    Capsule()
                        .stroke(isOn ? Color(hex: 0xF6C65B).opacity(0.5) : theme.separator, lineWidth: 1)
                )

            // Knob
            Circle()
                .fill(isOn
                    ? LinearGradient(colors: [Color(hex: 0xFDE68A), Color(hex: 0xF6C65B)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(hex: 0xC0BDD4), Color(hex: 0x9B98B3)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 24, height: 24)
                .shadow(
                    color: isOn
                        ? Color(hex: 0xF6C65B).opacity(0.5)
                        : Color.black.opacity(model.isDark ? 0.3 : 0.12),
                    radius: 4, y: 2
                )
                .offset(x: isOn ? 11 : -11)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.7), value: isOn)
    }
}

struct ProfileAppearanceCard: View {
    var body: some View {
        ProfileSectionCard(title: "Appearance") {
            ProfileLightSwitch()
        }
    }
}

// MARK: - 2. Yin-Yang Toggle (Round-up purchases)

struct ProfileYinYang: View {
    let isOn: Bool
    let onColor: Color
    let offColor: Color

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let r = size.width / 2
                let cx = size.width / 2
                let cy = size.height / 2

                // Full circle background (off-color fills right half via path)
                // Left half: onColor, Right half: offColor
                var leftHalf = Path()
                leftHalf.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                leftHalf.closeSubpath()
                ctx.fill(leftHalf, with: .color(onColor))

                var rightHalf = Path()
                rightHalf.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                                 startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                rightHalf.closeSubpath()
                ctx.fill(rightHalf, with: .color(offColor))

                // Top teardrop bulge (onColor, pointing upward on left side)
                let sr = r / 2
                var topTeardrop = Path()
                topTeardrop.addArc(center: CGPoint(x: cx, y: cy - sr), radius: sr,
                                   startAngle: .degrees(270), endAngle: .degrees(90), clockwise: false)
                topTeardrop.closeSubpath()
                ctx.fill(topTeardrop, with: .color(onColor))

                // Bottom teardrop (offColor, pointing downward)
                var bottomTeardrop = Path()
                bottomTeardrop.addArc(center: CGPoint(x: cx, y: cy + sr), radius: sr,
                                      startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
                bottomTeardrop.closeSubpath()
                ctx.fill(bottomTeardrop, with: .color(offColor))

                // Small dot top (offColor dot inside onColor region)
                let dotR = r / 6
                var dotTop = Path()
                dotTop.addEllipse(in: CGRect(x: cx - dotR, y: cy - sr * 2 + sr - dotR,
                                              width: dotR * 2, height: dotR * 2))
                ctx.fill(dotTop, with: .color(offColor))

                // Small dot bottom (onColor dot inside offColor region)
                var dotBottom = Path()
                dotBottom.addEllipse(in: CGRect(x: cx - dotR, y: cy + sr - dotR,
                                                 width: dotR * 2, height: dotR * 2))
                ctx.fill(dotBottom, with: .color(onColor))
            }
        }
    }
}

struct ProfileYinYangToggle: View {
    @EnvironmentObject var model: AppModel
    @State private var roundUpEnabled = false
    @State private var rotation: Double = 0

    var body: some View {
        let theme = model.theme
        HStack(spacing: 16) {
            // Yin-Yang with spring rotation on tap
            ZStack {
                Circle()
                    .fill(roundUpEnabled ? theme.violet.opacity(0.12) : theme.surfaceHi)
                    .frame(width: 44, height: 44)

                ProfileYinYang(
                    isOn: roundUpEnabled,
                    onColor: roundUpEnabled ? theme.violet : theme.textPrimary,
                    offColor: roundUpEnabled ? theme.magenta.opacity(0.18) : theme.surface
                )
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(rotation))
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    rotation += 180
                    roundUpEnabled.toggle()
                }
                llog("profile: round-up \(roundUpEnabled ? "on" : "off")")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Round up purchases")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text("Spare change earns Lumen points")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            Text(roundUpEnabled ? "On" : "Off")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(roundUpEnabled ? theme.violet : theme.textSecondary)
                .animation(.easeInOut(duration: 0.2), value: roundUpEnabled)
        }
    }
}

struct ProfilePreferencesCard: View {
    var body: some View {
        ProfileSectionCard(title: "Preferences") {
            ProfileYinYangToggle()
        }
    }
}

// MARK: - 3. Infinity Loader (Sync row)

struct ProfileInfinityPath: Shape {
    /// Lemniscate of Bernoulli parametric: x = a·cos(t)/(1+sin²(t)), y = a·sin(t)·cos(t)/(1+sin²(t))
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let a = min(rect.width, rect.height) * 0.44
        var path = Path()
        let steps = 120
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let denom = 1 + pow(sin(t), 2)
            let x = cx + CGFloat(a * cos(t) / denom)
            let y = cy + CGFloat(a * sin(t) * cos(t) / denom)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}

/// Draws one or two trim strokes of `ProfileInfinityPath` so the comet
/// stays a constant length (segmentLength) as it wraps past the 1.0 seam.
private struct ProfileInfinityComet: View {
    let phase: CGFloat
    let segmentLength: CGFloat = 0.35
    let gradient: AngularGradient

    var body: some View {
        let tail = phase + segmentLength
        if tail > 1.0 {
            // Comet straddles the seam — render two arcs.
            ZStack {
                ProfileInfinityPath()
                    .trim(from: phase, to: 1.0)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ProfileInfinityPath()
                    .trim(from: 0, to: tail - 1.0)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        } else {
            ProfileInfinityPath()
                .trim(from: phase, to: tail)
                .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}

struct ProfileInfinityLoader: View {
    @EnvironmentObject var model: AppModel
    @State private var phase: CGFloat = 0

    var body: some View {
        let theme = model.theme
        let gradient = AngularGradient(
            gradient: Gradient(colors: theme.brand + [theme.brand.first ?? theme.violet]),
            center: .center
        )
        ProfileInfinityComet(phase: phase, gradient: gradient)
            .frame(width: 44, height: 22)
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

struct ProfileSyncRow: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let theme = model.theme
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.violet.opacity(0.12))
                    .frame(width: 44, height: 44)
                ProfileInfinityLoader()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Syncing transactions…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text("Fetching latest activity")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer()

            LumenSpinner(size: 18, gradient: theme.brand)
        }
    }
}

struct ProfileSyncCard: View {
    var body: some View {
        ProfileSectionCard(title: "Transactions") {
            ProfileSyncRow()
        }
    }
}

// MARK: - Sign Out

struct ProfileSignOutButton: View {
    @EnvironmentObject var model: AppModel
    @State private var isPressed = false

    var body: some View {
        // Fill/stroke opacities: dark mode keeps the subtle wash; light mode bumps
        // them so the red tint reads clearly against a light surface.
        let fillOpacity: Double = model.isDark ? 0.09 : 0.13
        let strokeOpacity: Double = model.isDark ? 0.22 : 0.45
        Button {
            llog("profile: sign-out tapped")
            model.signOut()
        } label: {
            Text("Sign Out")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: 0xFF5F6D))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: 0xFF5F6D).opacity(fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xFF5F6D).opacity(strokeOpacity), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
