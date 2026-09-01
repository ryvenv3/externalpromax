import SwiftUI

// MARK: - LicenseGateView

struct LicenseGateView<Content: View>: View {
    @StateObject private var license = LicenseService.shared
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if let state = license.licenseState, state.isValid {
            content()
        } else {
            KeyEntryView()
        }
    }
}

// MARK: - KeyEntryView

struct KeyEntryView: View {
    @StateObject private var license = LicenseService.shared
    @State private var keyInput = ""
    @State private var shaking = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                            .frame(width: 90, height: 90)
                        if let icon = UIImage(named: "AppIcon60x60")
                            ?? UIImage(named: "AppIcon") {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        } else {
                            Text("RX")
                                .font(.system(size: 36, weight: .black))
                                .foregroundStyle(.red)
                        }
                    }

                    VStack(spacing: 4) {
                        Text("REGSXD EXTERNAL IOS")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                        Text("</> REGS XD")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.55))
                        Text("Enter your license key to continue")
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.4))
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 48)

                // Key input card
                VStack(spacing: 16) {
                    TextField("License", text: $keyInput)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.red.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .offset(x: shaking ? -8 : 0)
                        .animation(shaking ? .default.repeatCount(4, autoreverses: true).speed(8) : .default, value: shaking)

                    if let error = license.lastError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                    }

                    Button(action: submitKey) {
                        ZStack {
                            if license.isChecking {
                                ProgressView().tint(.white)
                            } else {
                                Text("Activate Key")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            keyInput.isEmpty
                                ? Color.red.opacity(0.3)
                                : Color.red
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(keyInput.isEmpty || license.isChecking)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Contact buttons
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // Buy Key
                        Button {
                            if let url = URL(string: "https://wa.me/6283899369257") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 12))
                                Text("Buy Key")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(.white)
                            .background(Color(red: 0.07, green: 0.53, blue: 0.27))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Channel
                        Button {
                            if let url = URL(string: "https://whatsapp.com/channel/0029Vb800WiJkK74Ssu8Fx0i") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 12))
                                Text("Channel")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(.white)
                            .background(Color(red: 0.07, green: 0.53, blue: 0.27).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 12)

                Text("Key is bound to this device on first activation")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.2))
                    .padding(.bottom, 28)
            }
        }
    }

    private func submitKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            let success = await license.validate(key: trimmed)
            if !success {
                await MainActor.run {
                    shaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shaking = false }
                }
            }
        }
    }
}
