import SwiftUI

// MARK: - RedeemView (entry point)
// Presented by OffersView as .sheet(item:) { offer in RedeemView(offer: offer) }

struct RedeemView: View {
    let offer: Offer
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    // Redeem state machine
    @State private var phase: RedeemPhase = .idle
    @State private var progress: Double = 0
    @State private var redeemCalled = false
    @State private var appeared = false
    // Cancellable handle for the progress→success delayed completion
    @State private var completionWork: DispatchWorkItem?

    private var value: Double { Double(offer.cashbackPct) * 1.5 }

    var body: some View {
        let theme = model.theme
        ZStack {
            theme.bg.ignoresSafeArea()

            // Confetti behind everything when success
            if phase == .success {
                ConfettiView(colors: theme.brand + theme.glow)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Grab handle
                RedeemHandle(theme: theme)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Offer header
                        RedeemOfferHeader(offer: offer, theme: theme)

                        // Cashback value display
                        RedeemValueDisplay(value: value, pct: offer.cashbackPct, merchant: offer.merchant, theme: theme)

                        Spacer(minLength: 0)

                        // Action zone
                        RedeemActionZone(
                            phase: $phase,
                            progress: $progress,
                            redeemCalled: $redeemCalled,
                            completionWork: $completionWork,
                            offer: offer,
                            value: value,
                            theme: theme,
                            onDone: { dismiss() }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            // Cancel any in-flight completion so a dismissed sheet can't flip to
            // .success and call model.redeem after the view is gone.
            completionWork?.cancel()
            completionWork = nil
        }
        // Side effect: call model.redeem exactly once when success fires
        .onChange(of: phase) { newPhase in
            if newPhase == .success && !redeemCalled {
                redeemCalled = true
                model.redeem(offer, value: value)
                llog("redeem: complete")
            }
        }
    }
}

// MARK: - Phase enum

enum RedeemPhase: Equatable {
    case idle
    case loading
    case success
}

// MARK: - RedeemHandle

private struct RedeemHandle: View {
    let theme: Theme
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(theme.separator)
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

// MARK: - RedeemOfferHeader

private struct RedeemOfferHeader: View {
    let offer: Offer
    let theme: Theme

    var body: some View {
        VStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(offer.accentColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: offer.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(offer.accentColor)
            }
            .overlay(
                Circle()
                    .stroke(offer.accentColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
            )

            VStack(spacing: 4) {
                Text(offer.merchant)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text(offer.blurb)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - RedeemValueDisplay

private struct RedeemValueDisplay: View {
    let value: Double
    let pct: Int
    let merchant: String
    let theme: Theme

    var body: some View {
        VStack(spacing: 8) {
            Text("Cashback reward")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .textCase(.uppercase)
                .kerning(1.0)

            Text("$\(String(format: "%.2f", value))")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(theme.glowGradient)

            Text("\(pct)% back at \(merchant)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.separator, lineWidth: 1)
                )
        )
    }
}

// MARK: - RedeemActionZone

private struct RedeemActionZone: View {
    @Binding var phase: RedeemPhase
    @Binding var progress: Double
    @Binding var redeemCalled: Bool
    @Binding var completionWork: DispatchWorkItem?
    let offer: Offer
    let value: Double
    let theme: Theme
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            switch phase {
            case .idle:
                RedeemConfirmButton(theme: theme) {
                    llog("redeem: confirm \(offer.merchant)")
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        phase = .loading
                    }
                }

            case .loading:
                RedeemProgressBar(
                    progress: $progress,
                    completionWork: $completionWork,
                    theme: theme,
                    onComplete: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            phase = .success
                        }
                    }
                )

            case .success:
                RedeemSuccess(
                    value: value,
                    merchant: offer.merchant,
                    theme: theme,
                    onDone: onDone
                )
            }
        }
    }
}

// MARK: - RedeemConfirmButton

private struct RedeemConfirmButton: View {
    let theme: Theme
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.brandGradient)
                    .frame(height: 58)
                Text("Confirm Redemption")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(RedeemPressStyle())
    }
}

// MARK: - RedeemPressStyle

private struct RedeemPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - RedeemProgressBar

private struct RedeemProgressBar: View {
    @Binding var progress: Double
    @Binding var completionWork: DispatchWorkItem?
    let theme: Theme
    let onComplete: () -> Void

    @State private var animating = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceHi)
                    .frame(height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.separator, lineWidth: 1)
                    )

                // Fill
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.brandGradient)
                        .frame(width: max(0, geo.size.width * progress), height: 58)
                        .animation(.easeInOut(duration: 1.5), value: progress)
                }
                .frame(height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Label
                HStack {
                    Spacer()
                    if progress < 1 {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(progress > 0.3 ? 1 : 0))
                            .animation(.easeIn(duration: 0.2), value: progress)
                    } else {
                        LumenSpinner(size: 20, gradient: [.white, .white.opacity(0.6)])
                    }
                    Spacer()
                }
                .frame(height: 58)
            }
            .frame(height: 58)

            Text("Processing redemption…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .onAppear {
            guard !animating else { return }
            animating = true
            // Drive progress from 0 → 1 over ~1.5s then fire completion.
            // Store the work item so RedeemView can cancel it on dismiss.
            withAnimation(.easeInOut(duration: 1.5)) {
                progress = 1.0
            }
            let work = DispatchWorkItem {
                // Guard: only advance if the work item itself was not cancelled.
                // DispatchWorkItem.isCancelled is checked implicitly by the runtime
                // when using asyncAfter(deadline:execute:), so if cancel() was called
                // before the deadline fires the block simply never runs.
                onComplete()
            }
            completionWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65, execute: work)
        }
    }
}

// MARK: - RedeemSuccess

private struct RedeemSuccess: View {
    let value: Double
    let merchant: String
    let theme: Theme
    let onDone: () -> Void

    @State private var circleScale: CGFloat = 0.4
    @State private var circleOpacity: Double = 0
    @State private var checkProgress: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            // Checkmark circle
            ZStack {
                Circle()
                    .fill(theme.success.opacity(0.15))
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(theme.success, lineWidth: 2.5)
                    .frame(width: 88, height: 88)

                RedeemCheckmark(progress: checkProgress, color: theme.success)
                    .frame(width: 40, height: 40)
            }
            .scaleEffect(circleScale)
            .opacity(circleOpacity)

            // Success text
            VStack(spacing: 6) {
                Text("Redeemed!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
                Text("$\(String(format: "%.2f", value)) added to your cashback")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(textOpacity)

            // Done button
            Button(action: onDone) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.success)
                        .frame(height: 54)
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(RedeemPressStyle())
            .opacity(textOpacity)
        }
        .onAppear {
            // Sequence: circle scale in → checkmark draws → text fades in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                circleScale = 1
                circleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
                checkProgress = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
                textOpacity = 1
            }
        }
    }
}

// MARK: - RedeemCheckmark (animatable Shape)

private struct RedeemCheckmark: View {
    var progress: Double
    var color: Color

    var body: some View {
        RedeemCheckmarkShape()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            .animation(.easeOut(duration: 0.55), value: progress)
    }
}

private struct RedeemCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Classic checkmark: from lower-left through a mid-dip to upper-right
        let startX = rect.minX + rect.width * 0.12
        let startY = rect.minY + rect.height * 0.52
        let midX   = rect.minX + rect.width * 0.40
        let midY   = rect.maxY - rect.height * 0.10
        let endX   = rect.maxX - rect.width * 0.05
        let endY   = rect.minY + rect.height * 0.15

        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: midX, y: midY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        return path
    }
}
