import Foundation
import UIKit

// MARK: - Models

struct LicenseValidateResponse: Codable {
    let valid: Bool
    let expiresAt: String?
    let durationDays: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case expiresAt = "expires_at"
        case durationDays = "duration_days"
        case error
    }
}

struct LicenseState: Codable {
    let key: String
    let expiresAt: Date
    let activatedAt: Date

    var isValid: Bool {
        Date() < expiresAt
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0)
    }
}

// MARK: - LicenseService

final class LicenseService: ObservableObject {

    // ⚠️ Replace with your Vercel deployment URL
    static let apiBaseURL = "https://regsxd-keys.vercel.app"

    static let shared = LicenseService()

    @Published var licenseState: LicenseState?
    @Published var isChecking = false
    @Published var lastError: String?

    private let stateKey = "regsxd_license_state"
    private let deviceID: String = {
        if let saved = UserDefaults.standard.string(forKey: "regsxd_device_id") {
            return saved
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "regsxd_device_id")
        return id
    }()

    private init() {
        loadSavedState()
    }

    // MARK: - Public

    /// Validate key against server. Call on app launch and after key entry.
    func validate(key: String) async -> Bool {
        await MainActor.run { isChecking = true; lastError = nil }

        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard let url = URL(string: "\(Self.apiBaseURL)/api/validate") else {
            await MainActor.run { isChecking = false; lastError = "Invalid server URL" }
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: String] = ["key": cleanKey, "device_id": deviceID]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(LicenseValidateResponse.self, from: data)

            if response.valid, let expiresAtStr = response.expiresAt {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let expiresAt = formatter.date(from: expiresAtStr)
                    ?? ISO8601DateFormatter().date(from: expiresAtStr)
                    ?? Date().addingTimeInterval(86400)

                let state = LicenseState(key: cleanKey, expiresAt: expiresAt, activatedAt: Date())
                saveState(state)
                await MainActor.run { self.licenseState = state; isChecking = false }
                return true
            } else {
                await MainActor.run {
                    isChecking = false
                    lastError = response.error ?? "Invalid key"
                    licenseState = nil
                }
                clearState()
                return false
            }
        } catch {
            // Offline fallback — use cached state if still valid
            if let cached = licenseState, cached.isValid {
                await MainActor.run { isChecking = false }
                return true
            }
            await MainActor.run {
                isChecking = false
                lastError = "Network error. Check your connection."
            }
            return false
        }
    }

    func logout() {
        clearState()
        DispatchQueue.main.async { self.licenseState = nil }
    }

    // MARK: - Private

    private func saveState(_ state: LicenseState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func loadSavedState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(LicenseState.self, from: data),
              state.isValid else {
            clearState()
            return
        }
        licenseState = state
    }

    private func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
    }
}
