import SwiftUI

// MARK: - Inject Button Model
struct InjectButton: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let targetPath: String
    let resourceFileName: String // nama file di bundle app (tanpa path)
}

// MARK: - Inject Menu View
struct InjectMenuView: View {
    @State private var results: [UUID: InjectResult] = [:]
    @State private var working: UUID? = nil

    // ✅ Tambah tombol inject di sini
    // resourceFileName = nama file yang kamu taruh di Xcode Resources folder
    let buttons: [InjectButton] = [
        InjectButton(
            name: "AIMNECK",
            bundleID: "com.dts.freefiremax",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D"
        ),
        // Tambah tombol lain di sini:
        // InjectButton(name: "Button 2", bundleID: "com.dts.freefire", targetPath: "...", resourceFileName: "button2.dat"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(buttons) { button in
                            InjectButtonCard(
                                button: button,
                                result: results[button.id],
                                isWorking: working == button.id
                            ) {
                                inject(button)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Menu")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func inject(_ button: InjectButton) {
        guard working == nil else { return }

        // Cari file di app bundle — support nama file tanpa extension standar
        let resourceURL: URL?
        if let url = Bundle.main.url(forResource: button.resourceFileName, withExtension: nil) {
            resourceURL = url
        } else {
            // Coba cari di bundle root langsung
            let bundlePath = Bundle.main.bundlePath
            let direct = URL(fileURLWithPath: bundlePath).appendingPathComponent(button.resourceFileName)
            resourceURL = FileManager.default.fileExists(atPath: direct.path) ? direct : nil
        }
        guard let resourceURL else {
            results[button.id] = .failed("File not found in bundle: \(button.resourceFileName)")
            return
        }

        working = button.id
        results[button.id] = .working

        Task.detached(priority: .userInitiated) {
            do {
                // Resolve container untuk bundle ID
                let containerURL = try resolveContainer(bundleID: button.bundleID)
                let targetURL = containerURL.appendingPathComponent(button.targetPath)

                // Buat folder jika belum ada
                let dir = targetURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                // Load resource data
                let data = try Data(contentsOf: resourceURL)

                // Atomic write via staging
                let staging = dir.appendingPathComponent(".regsxd-inject-\(UUID().uuidString)")
                try data.write(to: staging, options: .atomic)
                _ = rename(staging.path, targetURL.path)

                await MainActor.run {
                    results[button.id] = .success
                    working = nil
                }
            } catch {
                await MainActor.run {
                    results[button.id] = .failed(error.localizedDescription)
                    working = nil
                }
            }
        }
    }
}

// MARK: - Resolve container helper
private func resolveContainer(bundleID: String) throws -> URL {
    let fm = FileManager.default
    let base = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application")
    let apps = try fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
    for app in apps {
        let meta = app.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
        if let dict = NSDictionary(contentsOf: meta) as? [String: Any],
           let id = dict["MCMMetadataIdentifier"] as? String,
           id == bundleID {
            return app
        }
    }
    throw InjectError.containerNotFound(bundleID)
}

// MARK: - Result & Error

enum InjectResult {
    case working
    case success
    case failed(String)
}

enum InjectError: LocalizedError {
    case containerNotFound(String)
    var errorDescription: String? {
        switch self {
        case .containerNotFound(let id): return "Container not found for \(id)"
        }
    }
}

// MARK: - Card View

private struct InjectButtonCard: View {
    let button: InjectButton
    let result: InjectResult?
    let isWorking: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(button.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            // Status
            if let result {
                switch result {
                case .working:
                    HStack(spacing: 8) {
                        ProgressView().tint(.red).controlSize(.small)
                        Text("Injecting…")
                            .font(.caption)
                            .foregroundStyle(Color(white: 0.5))
                    }
                case .success:
                    Label("Inject Success", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                case .failed(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            // Inject button
            Button(action: onTap) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Inject")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isWorking ? Color.red.opacity(0.3) : Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isWorking)
        }
        .padding(16)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}
