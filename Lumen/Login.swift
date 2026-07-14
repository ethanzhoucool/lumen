import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var focusedField: LoginField?

    @State private var email = "ethan@lumen.app"
    @State private var password = ""
    @State private var wordmarkReady = false
    @State private var taglineReady = false
    @State private var fieldsReady = false
    @State private var submitState: LoginSubmitState = .idle

    var body: some View {
        let theme = model.theme
        ZStack {
            // Full-bleed background
            theme.bg.ignoresSafeArea()

            // Radial glow at top
            LoginBackgroundGlow(colors: theme.brand)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    // Wordmark
                    LoginWordmark(ready: wordmarkReady, theme: theme)
                        .padding(.bottom, 14)

                    // Tagline
                    LoginTagline(ready: taglineReady, theme: theme)

                    Spacer().frame(height: 52)

                    // Fields
                    VStack(spacing: 14) {
                        LoginInputField(
                            text: $email,
                            placeholder: "Email",
                            icon: "at",
                            isSecure: false,
                            isFocused: focusedField == .email,
                            theme: theme
                        )
                        .focused($focusedField, equals: .email)

                        LoginInputField(
                            text: $password,
                            placeholder: "Password",
                            icon: "lock.fill",
                            isSecure: true,
                            isFocused: focusedField == .password,
                            theme: theme
                        )
                        .focused($focusedField, equals: .password)
                    }
                    .padding(.horizontal, 20)
                    .opacity(fieldsReady ? 1 : 0)
                    .offset(y: fieldsReady ? 0 : 24)

                    Spacer().frame(height: 28)

                    // Submit button
                    LoginSubmitButton(state: submitState, theme: theme) {
                        guard submitState == .idle else { return }
                        llog("login: submit")
                        focusedField = nil
                        submitState = .loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                submitState = .success
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                model.signIn()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(fieldsReady ? 1 : 0)
                    .offset(y: fieldsReady ? 0 : 24)

                    Spacer().frame(height: 24)

                    // Forgot link
                    Button(action: {}) {
                        Text("Forgot access?")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.textSecondary.opacity(0.6))
                    }
                    .opacity(fieldsReady ? 1 : 0)

                    Spacer().frame(height: 48)
                }
            }
        }
        .onChange(of: focusedField) { newValue in
            if let field = newValue {
                llog("login: focus \(field == .email ? "email" : "password")")
            }
        }
        .onAppear {
            // Staggered entrance
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                wordmarkReady = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.55)) {
                taglineReady = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.75)) {
                fieldsReady = true
            }
        }
    }
}

// MARK: - Focus enum

private enum LoginField: Hashable {
    case email, password
}

// MARK: - Submit State

enum LoginSubmitState: Equatable {
    case idle, loading, success
}

// MARK: - Background Glow

private struct LoginBackgroundGlow: View {
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [colors[0].opacity(0.28), colors[1].opacity(0.14), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.65
                        )
                    )
                    .frame(width: geo.size.width * 1.2, height: geo.size.width * 0.85)
                    .blur(radius: 48)
                    .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.05)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Wordmark

struct LoginWordmark: View {
    let ready: Bool
    let theme: Theme

    private let letters: [Character] = Array("LUMEN")

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<letters.count, id: \.self) { i in
                LoginLetterCell(
                    character: letters[i],
                    index: i,
                    ready: ready,
                    delay: Double(i) * 0.07,
                    gradient: theme.brandGradient
                )
            }
        }
    }
}

private struct LoginLetterCell: View {
    let character: Character
    let index: Int
    let ready: Bool
    let delay: Double
    let gradient: LinearGradient

    @State private var appeared = false

    // Alternating direction swirl: even indices tilt right, odd tilt left, magnitude grows with index
    private var startRotation: Double {
        let dir = index.isMultiple(of: 2) ? 1.0 : -1.0
        return dir * (35.0 + Double(index) * 8.0)
    }

    var body: some View {
        Text(String(character))
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .overlay(
                gradient
                    .mask(
                        Text(String(character))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                    )
            )
            .foregroundColor(.clear)
            .rotationEffect(.degrees(appeared ? 0 : startRotation))
            .scaleEffect(appeared ? 1 : 0.4)
            .blur(radius: appeared ? 0 : 6)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78).delay(delay),
                value: appeared
            )
            .onChange(of: ready) { newVal in
                if newVal { appeared = true }
            }
            .onAppear {
                if ready { appeared = true }
            }
    }
}

// MARK: - Tagline

struct LoginTagline: View {
    let ready: Bool
    let theme: Theme

    private let tagline = "Rewards that actually reward you."

    var body: some View {
        let chars = Array(tagline)
        return HStack(spacing: 0) {
            ForEach(0..<chars.count, id: \.self) { i in
                LoginTaglineChar(
                    character: chars[i],
                    ready: ready,
                    delay: Double(i) * 0.018,
                    color: theme.textSecondary
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
}

private struct LoginTaglineChar: View {
    let character: Character
    let ready: Bool
    let delay: Double
    let color: Color

    @State private var appeared = false

    var body: some View {
        Text(String(character))
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(color)
            .offset(y: appeared ? 0 : 14)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.68).delay(delay),
                value: appeared
            )
            .onChange(of: ready) { newVal in
                if newVal { appeared = true }
            }
            .onAppear {
                if ready { appeared = true }
            }
    }
}

// MARK: - Input Field

struct LoginInputField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    let isSecure: Bool
    let isFocused: Bool
    let theme: Theme

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isFocused
                                ? AnyShapeStyle(theme.brandGradient)
                                : AnyShapeStyle(theme.separator),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isFocused ? theme.violet.opacity(0.18) : .clear,
                    radius: isFocused ? 8 : 0,
                    y: 2
                )

            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isFocused ? theme.violet : theme.textSecondary)
                    .frame(width: 20)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)

                // Floating placeholder + text field
                ZStack(alignment: .leading) {
                    // Floating label
                    Text(placeholder)
                        .font(.system(
                            size: (isFocused || !text.isEmpty) ? 11 : 15,
                            weight: .medium
                        ))
                        .foregroundColor(
                            isFocused
                                ? theme.violet
                                : theme.textSecondary.opacity(0.7)
                        )
                        .offset(y: (isFocused || !text.isEmpty) ? -14 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isFocused)
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: text.isEmpty)

                    // Actual input
                    Group {
                        if isSecure {
                            SecureField("", text: $text)
                        } else {
                            TextField("", text: $text)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .offset(y: (isFocused || !text.isEmpty) ? 8 : 0)
                    .opacity((isFocused || !text.isEmpty) ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isFocused)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: text.isEmpty)
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 58)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Submit Button

struct LoginSubmitButton: View {
    let state: LoginSubmitState
    let theme: Theme
    let onTap: () -> Void

    // Width morphs from full-width pill → compact circle
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let targetWidth: CGFloat = {
                switch state {
                case .idle:    return fullWidth
                case .loading: return 56
                case .success: return 56
                }
            }()

            ZStack {
                // Gradient fill pill / circle
                RoundedRectangle(cornerRadius: state == .idle ? 16 : 28, style: .continuous)
                    .fill(theme.brandGradient)
                    .frame(width: targetWidth, height: 56)
                    .shadow(color: theme.violet.opacity(0.35), radius: 12, y: 4)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.78),
                        value: state
                    )

                // Content
                Group {
                    switch state {
                    case .idle:
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .transition(.opacity.combined(with: .scale))

                    case .loading:
                        LumenSpinner(size: 26, gradient: [.white, .white.opacity(0.5)])
                            .transition(.opacity.combined(with: .scale))

                    case .success:
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(state == .success ? 1 : 0.3)
                            .animation(
                                .spring(response: 0.35, dampingFraction: 0.6),
                                value: state
                            )
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.75),
                    value: state
                )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard state == .idle else { return }
                onTap()
            }
        }
        .frame(height: 56)
    }
}
