import SwiftUI

// MARK: - LicenseGateView
// Wrap your main ContentView with this to require a valid license key.
// Usage in App.swift:
//   LicenseGateView { ContentView() }

struct LicenseGateView<Content: View>: View {
    @StateObject private var license = LicenseService.shared
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if let state = license.licenseState, state.isValid {
                content()
                    .overlay(alignment: .bottom) {
                        LicenseBadge(state: state)
                    }
            } else {
                KeyEntryView()
            }
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
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.red.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                            .frame(width: 80, height: 80)
                        Text("RX")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.red)
                    }
                    Text("REGS XD EXPLORER")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Enter your license key to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 44)

                // Key input card
                VStack(spacing: 16) {
                    TextField("REGS-XXXX-XXXX-XXXX", text: $keyInput)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
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
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(keyInput.isEmpty ? Color.red.opacity(0.4) : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(keyInput.isEmpty || license.isChecking)
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("Key is bound to this device on first activation")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.bottom, 32)
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

// MARK: - LicenseBadge (small indicator inside app)

struct LicenseBadge: View {
    let state: LicenseState

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.daysRemaining <= 1 ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                Text(showDetail
                     ? "\(state.daysRemaining)d left · \(state.key)"
                     : "\(state.daysRemaining)d left")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}
