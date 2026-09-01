import SwiftUI

// MARK: - Models

struct InjectButton: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let bundleID: String
    let targetPath: String
    let resourceFileName: String
    let resourceSubfolder: String
    var launchAfterInject: Bool = false
}

// MARK: - Inject Menu View

struct InjectMenuView: View {
    @State private var results: [UUID: InjectResult] = [:]
    @State private var working: UUID? = nil
    @State private var progress: [UUID: Double] = [:]

    let buttons: [InjectButton] = [
        // AIMBOT
        InjectButton(
            name: "AIMNECK",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimneck"
        ),
        InjectButton(
            name: "AIMDRAG",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.PENojQAQf9a1l6Dzjs0n1Z3rtVU~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimdrag"
        ),
        InjectButton(
            name: "AIMBODY",
            category: "AIMBOT",
            bundleID: "com.dts.freefireth",
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceFileName: "cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D",
            resourceSubfolder: "patches/aimbody"
        ),
        // EXTRA
        InjectButton(
            name: "FPS 140",
            category: "EXTRA",
            bundleID: "com.dts.freefireth",
            targetPath: "Library/Preferences/com.dts.freefireth.plist",
            resourceFileName: "com.dts.freefireth.plist",
            resourceSubfolder: "patches/fps140",
            launchAfterInject: true
        ),
    ]

    // Group buttons by category
    private var categories: [String] {
        var seen = Set<String>()
        return buttons.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 10) {
                                // Category header
                                HStack {
                                    Text(category)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.red.opacity(0.8))
                                        .kerning(1.5)
                                    Rectangle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 16)

                                // Buttons in this category
                                VStack(spacing: 10) {
                                    ForEach(buttons.filter { $0.category == category }) { button in
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
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
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

                    // Launch Free Fire jika launchAfterInject = true
                    if button.launchAfterInject {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let ffBundleID = button.bundleID
                            // Coba buka via URL scheme Free Fire
                            let schemes = [
                                "freefire://",
                                "garena://",
                            ]
                            for scheme in schemes {
                                if let url = URL(string: scheme),
                                   UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                    return
                                }
                            }
                            // Fallback: buka via settings URL
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(ffBundleID)") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
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
            // Top row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconFor(button.name))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(button.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if let result {
                    switch result {
                    case .success:
                        Text("✓")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.green)
                    case .failed, .working:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Progress bar
            if isWorking {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(white: 0.1)).frame(height: 2)
                        Rectangle().fill(Color.red)
                            .frame(width: geo.size.width * progress, height: 2)
                            .animation(.linear(duration: 0.05), value: progress)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 5) {
                    ProgressView().tint(.red).controlSize(.mini)
                    Text("Applying \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            if case .failed(_) = result {
                // error disembunyikan
                EmptyView()
            }

            Divider().background(Color(white: 0.1))

            // Apply button
            Button(action: onTap) {
                Group {
                    if case .success = result {
                        Text("Applied ✓")
                            .foregroundStyle(.green)
                    } else {
                        Text(isWorking ? "Applying…" : "Apply")
                            .foregroundStyle(isWorking ? Color(white: 0.35) : .white)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(applyBg)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 0
                ))
            }
            .disabled(isWorking)
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isWorking ? Color.red.opacity(0.5) : Color(white: 0.11), lineWidth: 1)
        )
    }

    private var applyBg: Color {
        if case .success = result { return Color.green.opacity(0.08) }
        return isWorking ? Color(white: 0.06) : Color.red.opacity(0.8)
    }

    private func iconFor(_ name: String) -> String {
        switch name.uppercased() {
        case "AIMNECK": return "scope"
        case "AIMDRAG": return "hand.draw"
        case "AIMBODY": return "person.fill"
        case "FPS 140": return "speedometer"
        default: return "bolt.fill"
        }
    }
}
