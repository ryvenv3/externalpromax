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
    @State private var consoleLogs: [String] = []

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            consoleLogs.append("[\(ts)] \(msg)")
            if consoleLogs.count > 40 { consoleLogs.removeFirst() }
        }
    }

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
            targetPath: "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/",
            resourceFileName: "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D",
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
            targetPath: "Library/Preferences/",
            resourceFileName: "com.dts.freefireth.plist",
            resourceSubfolder: "patches/fps 140",
            launchAfterInject: false
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
                VStack(spacing: 0) {
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
                        .padding(.bottom, 12)
                    }

                    // Console terminal
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Circle().fill(Color.yellow).frame(width: 8, height: 8)
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("console")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.4))
                                .padding(.leading, 6)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.08))

                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 3) {
                                    if consoleLogs.isEmpty {
                                        Text("> waiting for action...")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.3))
                                    } else {
                                        ForEach(Array(consoleLogs.enumerated()), id: \.offset) { i, line in
                                            Text(line)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(Color(white: 0.6))
                                                .id(i)
                                        }
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .onChange(of: consoleLogs.count) { _ in
                                if let last = consoleLogs.indices.last {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                        }
                        .frame(height: 110)
                        .background(Color(white: 0.04))
                    }
                    .overlay(
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: 1),
                        alignment: .top
                    )
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
        // Tiap button bisa jalan sendiri — cek hanya button ini yang sedang working
        guard working != button.id else { return }

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
            log("\(button.name) — file not found")
            return
        }

        working = button.id
        results[button.id] = .working
        progress[button.id] = 0
        log("\(button.name) — starting inject...")

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
                    log("\(button.name) — done")

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
                    log("\(button.name) — failed")
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

    @State private var pressed = false

    var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSuccess
                                ? [Color(white: 0.08), Color.green.opacity(0.08)]
                                : [Color(white: 0.10), Color(white: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Red glow when working
                if isWorking {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.04))
                }

                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        // Name
                        Text(button.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        // Status
                        if isWorking {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                        } else if isSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    // Progress bar
                    if isWorking {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(white: 0.08))
                                    .frame(height: 3)
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.6), Color.red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progress, height: 3)
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSuccess ? Color.green.opacity(0.3)
                    : isWorking ? Color.red.opacity(0.4)
                    : Color(white: 0.13),
                    lineWidth: 1
                )
        )
        .shadow(
            color: isWorking ? Color.red.opacity(0.15) : Color.clear,
            radius: 12, x: 0, y: 4
        )
    }
}

