import SwiftUI

// MARK: - Inject Button Model
struct InjectButton: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let targetPath: String
    let resourceFileName: String
    let resourceSubfolder: String
}

// MARK: - Inject Menu View
struct InjectMenuView: View {
    @State private var results: [UUID: InjectResult] = [:]
    @State private var working: UUID? = nil
    @State private var progress: [UUID: Double] = [:]

    let buttons: [InjectButton] = [
        InjectButton(
            name: "AIMNECK",
            bundleID: "com.dts.freefiremax",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimneck"
        ),
        InjectButton(
            name: "AIMDRAG",
            bundleID: "com.dts.freefiremax",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimdrag"
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(buttons) { button in
                            InjectButtonCard(
                                button: button,
                                result: results[button.id],
                                isWorking: working == button.id,
                                progress: progress[button.id] ?? 0
                            ) {
                                inject(button)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
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

        // Cari file dari subfolder di bundle
        let resourceURL: URL? = {
            let bundleBase = URL(fileURLWithPath: Bundle.main.bundlePath)
            let subfolderPath = bundleBase
                .appendingPathComponent(button.resourceSubfolder)
                .appendingPathComponent(button.resourceFileName)
            if FileManager.default.fileExists(atPath: subfolderPath.path) {
                return subfolderPath
            }
            // Fallback: root bundle
            let rootPath = bundleBase.appendingPathComponent(button.resourceFileName)
            return FileManager.default.fileExists(atPath: rootPath.path) ? rootPath : nil
        }()
        guard let resourceURL else {
            results[button.id] = .failed("File not found in bundle")
            return
        }

        working = button.id
        results[button.id] = .working
        progress[button.id] = 0

        // Progress animation over 5 seconds
        let id = button.id
        let startTime = Date()
        let duration: Double = 5.0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let pct = min(elapsed / duration, 1.0)
            DispatchQueue.main.async { progress[id] = pct }
            if pct >= 1.0 { timer.invalidate() }
        }

        Task.detached(priority: .userInitiated) {
            // Delay 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            do {
                let containerURL = try resolveContainer(bundleID: button.bundleID)
                let targetURL = containerURL.appendingPathComponent(button.targetPath)
                let dir = targetURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let data = try Data(contentsOf: resourceURL)
                let staging = dir.appendingPathComponent(".regsxd-inject-\(UUID().uuidString)")
                try data.write(to: staging, options: .atomic)
                _ = rename(staging.path, targetURL.path)

                await MainActor.run {
                    results[button.id] = .success
                    progress[button.id] = 1.0
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
    guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
        throw InjectError.containerNotFound(bundleID)
    }
    return URL(fileURLWithPath: path, isDirectory: true)
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
        case .containerNotFound(let id): return "App not found: \(id)"
        }
    }
}

// MARK: - Card View

private struct InjectButtonCard: View {
    let button: InjectButton
    let result: InjectResult?
    let isWorking: Bool
    let progress: Double
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top section
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(button.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Free Fire Max")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()

                // Status badge
                if let result {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                    case .working:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Progress bar (visible while working)
            if isWorking {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(white: 0.12))
                            .frame(height: 3)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width * progress, height: 3)
                            .animation(.linear(duration: 0.05), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.bottom, 4)
            }

            Divider()
                .background(Color(white: 0.12))

            // Error message
            if case .failed(let msg) = result {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }

            // Status text while working
            if isWorking {
                HStack(spacing: 6) {
                    ProgressView().tint(.red).controlSize(.mini)
                    Text("Applying… \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            // Button
            Button(action: onTap) {
                HStack {
                    if case .success = result {
                        Text("Applied ✓")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text(isWorking ? "Applying…" : "Apply")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isWorking ? Color(white: 0.4) : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Group {
                        if case .success = result {
                            Color.green.opacity(0.1)
                        } else {
                            isWorking ? Color(white: 0.08) : Color.red.opacity(0.85)
                        }
                    }
                )
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 0
                ))
            }
            .disabled(isWorking)
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isWorking ? Color.red.opacity(0.4) : Color(white: 0.12), lineWidth: 1)
        )
    }
}
