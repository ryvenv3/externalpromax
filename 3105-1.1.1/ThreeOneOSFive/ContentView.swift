import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        ZStack(alignment: .bottom) {
            // Content
            ZStack {
                ForEach(featureVisibility.visibleSections) { section in
                    sectionContent(section)
                        .opacity(tabNavigation.selectedTab == section.rawValue ? 1 : 0)
                        .allowsHitTesting(tabNavigation.selectedTab == section.rawValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 70)

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(featureVisibility.visibleSections) { section in
                    let isSelected = tabNavigation.selectedTab == section.rawValue
                    Button {
                        tabNavigation.select(section.rawValue)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                                .foregroundStyle(isSelected ? Color.red : Color(white: 0.45))
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            Text(language.text(section.titleKey))
                                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.red : Color(white: 0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected
                                ? Color.red.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
            .padding(.top, 6)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.85))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color.red.opacity(0.2)),
                alignment: .top
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("REGSXD EXTERNAL")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: wallpapersSupported
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession
            )
        case .patches:
            PatchProjectsView()
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "gearshape.fill"
        case .files: return "folder.fill"
        case .patches: return "square.grid.2x2.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @StateObject private var license = LicenseService.shared
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var showLicenseKey = false
    @State private var showLogoutConfirm = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    brandSection
                    licenseSection
                    deviceSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("REGSXD EXTERNAL IOS")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.red)
                        Text("by </> REGS XD")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
            .confirmationDialog("Logout?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Logout", role: .destructive) {
                    LicenseService.shared.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your license key will need to be re-entered.")
            }
        }
    }

    private var brandSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        .frame(width: 48, height: 48)
                    if let icon = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
                        Image(uiImage: icon)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Text("RX")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("REGSXD EXTERNAL IOS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("</> REGS XD")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(white: 0.5))
                    Text("v\(AppInfo.appVersion)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.35))
                }
                Spacer()
            }
            .listRowBackground(Color(white: 0.07))
        }
    }

    private var licenseSection: some View {
        Section {
            if let state = license.licenseState {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.red)
                    if showLicenseKey {
                        Text(state.key)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("••••-••••-••••-••••")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showLicenseKey.toggle()
                    } label: {
                        Image(systemName: showLicenseKey ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color(white: 0.07))

                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(state.daysRemaining <= 1 ? .red : .green)
                    Text("Expires")
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(state.expiresAt, style: .date)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("\(state.daysRemaining) day\(state.daysRemaining == 1 ? "" : "s") remaining")
                            .font(.caption)
                            .foregroundStyle(state.daysRemaining <= 1 ? .red : .green)
                    }
                }
                .listRowBackground(Color(white: 0.07))

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("Logout / Change Key", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                .listRowBackground(Color(white: 0.07))
            }
        } header: {
            Text("LICENSE")
                .foregroundStyle(.red.opacity(0.8))
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent("iPhone Model") {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            .listRowBackground(Color(white: 0.07))
            LabeledContent("iOS Version") {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            .listRowBackground(Color(white: 0.07))
            HStack {
                Text("Compatibility")
                Spacer()
                Text(appState.isSupported ? "Supported" : "Unsupported")
                    .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }
            .listRowBackground(Color(white: 0.07))

            if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                HStack {
                    Text(language.text("dashboard.kernel_status"))
                    Spacer()
                    if appState.kernelExploitRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(language.text("dashboard.kernel_running"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                            .foregroundStyle(appState.exploitStatus.isSuccess ? Color.green : Color.secondary)
                    }
                }
                .listRowBackground(Color(white: 0.07))
            }
        } header: {
            Text("DEVICE")
                .foregroundStyle(.red.opacity(0.8))
        } footer: {
            Text("Support iOS 15 – 27")
                .foregroundStyle(Color(white: 0.4))
        }
    }
}
