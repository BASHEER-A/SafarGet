//
//  MainViews.swift
//  SafarGet
//
//  Created by Your Name on 24/07/2025.

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SafariServices

// MARK: - Custom Blur View
struct CustomBlurView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @StateObject var viewModel = DownloadManagerViewModel()
    @State private var showSafariExtensionStatus = false
    @State private var hasCheckedExtensionStatus = false
    
    // Appearance settings state
    @State private var appTransparency: Double = max(0.3, UserDefaults.standard.object(forKey: "AppTransparency") as? Double ?? 1.0)
    @State private var appColorTint: Double = UserDefaults.standard.object(forKey: "AppColorTint") as? Double ?? 0.5
    
    var body: some View {
        ZStack {
            // Main app content
            ZStack {
                CustomBlurView()
                    .ignoresSafeArea()
                Color.black.opacity(0.12 * appTransparency)
                    .ignoresSafeArea()
                DownloadManagerWindow(viewModel: viewModel, appTransparency: appTransparency, appColorTint: appColorTint)
                    .frame(minWidth: 660, minHeight: 520)
            }
            .opacity(showSafariExtensionStatus ? 0 : 1.0) // Keep content fully opaque for interaction - DO NOT CHANGE
            .overlay(
                // Color tint overlay - MUST have allowsHitTesting(false) to prevent blocking interactions
                Color.blue.opacity(appColorTint * 0.1)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                    .allowsHitTesting(false) // Allow interaction with elements behind this overlay
            )
            .animation(.easeInOut(duration: 0.3), value: showSafariExtensionStatus)
            .animation(.easeInOut(duration: 0.2), value: appTransparency)
            .animation(.easeInOut(duration: 0.2), value: appColorTint)
            
            // Safari Extension Status Overlay
            if showSafariExtensionStatus {
                SafariExtensionStatusView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Load appearance settings
            loadAppearanceSettings()
            
            // Request notification permission on first launch
            if UserDefaults.standard.object(forKey: "NotificationPermissionRequested") == nil {
                NotificationManager.shared.requestPermission { granted in
                    UserDefaults.standard.set(true, forKey: "NotificationPermissionRequested")
                    if granted {
                        print("✅ Notification permission granted")
                    }
                }
            }
            
            if viewModel.showDiskAccessAlert {
                showDiskAccessAlert()
            }
            
            // Check Safari Extension status on first launch or if not checked recently
            checkAndShowSafariExtensionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            // Monitor UserDefaults changes for appearance settings
            loadAppearanceSettings()
        }
        .alert(isPresented: $viewModel.showDiskAccessAlert) {
            Alert(
                title: Text("Full Disk Access Required"),
                message: Text("SafarGet requires Full Disk Access to download files. Please enable it in System Preferences."),
                primaryButton: .default(Text("Open Settings")) {
                    viewModel.openPrivacySettings()
                },
                secondaryButton: .cancel(Text("Cancel")) {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.saveDownloads()
            viewModel.saveSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSafariExtensionStatus)) { _ in
            // Force show Safari Extension Status when requested via menu
            showSafariExtensionStatus = true
        }
        .sheet(isPresented: $showSafariExtensionStatus) {
            SafariExtensionStatusView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
    
    private func loadAppearanceSettings() {
        let savedTransparency = UserDefaults.standard.object(forKey: "AppTransparency") as? Double ?? 1.0
        appTransparency = max(0.3, savedTransparency) // Ensure minimum transparency for usability
        appColorTint = UserDefaults.standard.object(forKey: "AppColorTint") as? Double ?? 0.5
        
        // Save the corrected value back if it was below minimum
        if savedTransparency < 0.3 {
            UserDefaults.standard.set(appTransparency, forKey: "AppTransparency")
        }
    }
    
    private func showDiskAccessAlert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            viewModel.showDiskAccessAlert = true
        }
    }
    
    private func checkAndShowSafariExtensionStatus() {
        // Check if we should show Safari Extension status
        let lastStatusCheck = UserDefaults.standard.double(forKey: "LastSafariExtensionStatusCheck")
        let currentTime = Date().timeIntervalSince1970
        let oneDayInSeconds: TimeInterval = 24 * 60 * 60
        
        // Show status if:
        // 1. Never checked before
        // 2. Last check was more than a day ago
        // 3. User explicitly wants to see it (forced check)
        let shouldCheck = lastStatusCheck == 0 || 
                         (currentTime - lastStatusCheck) > oneDayInSeconds ||
                         UserDefaults.standard.bool(forKey: "ForceShowExtensionStatus")
        
        if shouldCheck && !hasCheckedExtensionStatus {
            hasCheckedExtensionStatus = true
            
            // Delay a bit to let the main UI load first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                checkSafariExtensionAvailability { hasExtension in
                    DispatchQueue.main.async {
                        if hasExtension {
                            self.showSafariExtensionStatus = true
                            UserDefaults.standard.set(currentTime, forKey: "LastSafariExtensionStatusCheck")
                            UserDefaults.standard.set(false, forKey: "ForceShowExtensionStatus")
                        }
                    }
                }
            }
        }
    }
    
    private func checkSafariExtensionAvailability(completion: @escaping (Bool) -> Void) {
        // Check if Safari extension bundle exists in Applications
        let appPath = "/Applications/SafarGet.app/Contents/PlugIns/SafarGet Extension.appex"
        let extensionExists = FileManager.default.fileExists(atPath: appPath)
        
        if extensionExists {
            // Additionally check if Safari extension process might be running
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["aux"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let _ = String(data: data, encoding: .utf8) ?? ""
                
                // Extension exists, show status regardless of running state
                completion(true)
            } catch {
                completion(extensionExists)
            }
        } else {
            completion(false)
        }
    }
}

// MARK: - Download Manager Window
struct DownloadManagerWindow: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var isDropTargeted = false
    let appTransparency: Double
    let appColorTint: Double

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel)
                .background(.ultraThinMaterial.opacity(max(0.3, 1.1 * appTransparency)))
                .overlay(
                    // Color tint overlay for toolbar - MUST have allowsHitTesting(false)
                    Color.blue.opacity(appColorTint * 0.03)
                        .blendMode(.overlay)
                        .allowsHitTesting(false) // Allow interaction with elements behind this overlay
                )
            Divider()
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    SidebarView(viewModel: viewModel)
                }
                .frame(width: 200)
                .background(.ultraThinMaterial.opacity(max(0.2, 0.8 * appTransparency)))
                .overlay(
                    // Color tint overlay for sidebar - MUST have allowsHitTesting(false)
                    Color.blue.opacity(appColorTint * 0.04)
                        .blendMode(.overlay)
                        .allowsHitTesting(false) // Allow interaction with elements behind this overlay
                )
                Divider()
                VStack(spacing: 0) {
                    DownloadsListView(viewModel: viewModel)
                        .background(.ultraThinMaterial.opacity(max(0.2, 0.8 * appTransparency)))
                        .overlay(
                            // Color tint overlay for downloads list - MUST have allowsHitTesting(false)
                            Color.blue.opacity(appColorTint * 0.05)
                                .blendMode(.overlay)
                                .allowsHitTesting(false) // Allow interaction with elements behind this overlay
                        )
                        .overlay(
                            // Drop target indicator - MUST have allowsHitTesting(false)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .padding(4)
                                .opacity(isDropTargeted ? 1 : 0)
                                .allowsHitTesting(false) // Allow interaction with elements behind this overlay
                        )
                        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                            viewModel.handleDroppedFiles(providers)
                        }
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddDownload) { AddDownloadSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showTorrentFiles) { TorrentFilesSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showSettings) { EnhancedSettingsView(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showSafariExtensionWindow) { SafariExtensionWindow() }
    }
}



// MARK: - Toolbar View
struct ToolbarView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var showDeleteConfirmation = false
    @State private var deleteAction: DeleteAction = .all
    @State private var isAddDownloadHovered = false
    @State private var isPlayHovered = false
    @State private var isPauseHovered = false
    @State private var isStopHovered = false
    @State private var isActionsHovered = false
    @State private var playButtonRotation: Double = 0
    @State private var pauseButtonScale: CGFloat = 1.0
    @State private var stopButtonPulse: Bool = false
    @State private var isAllFilterHovered = false
    @State private var isActiveFilterHovered = false
    @State private var isCompletedFilterHovered = false
    @State private var isFailedFilterHovered = false
    
    enum DeleteAction {
        case selected, completed, incomplete, all
        
        var title: String {
            switch self {
            case .selected: return NSLocalizedString("Delete Selected Downloads", comment: "Delete selected downloads alert title")
            case .completed: return NSLocalizedString("Delete Completed Downloads", comment: "Delete completed downloads alert title")
            case .incomplete: return NSLocalizedString("Delete Incomplete Downloads", comment: "Delete incomplete downloads alert title")
            case .all: return NSLocalizedString("Delete All Downloads", comment: "Delete all downloads alert title")
            }
        }
        
        var message: String {
            switch self {
            case .selected: return NSLocalizedString("Are you sure you want to delete the selected downloads?", comment: "Delete selected downloads confirmation message")
            case .completed: return NSLocalizedString("Are you sure you want to delete all completed downloads?", comment: "Delete completed downloads confirmation message")
            case .incomplete: return NSLocalizedString("Are you sure you want to delete all incomplete downloads?", comment: "Delete incomplete downloads confirmation message")
            case .all: return NSLocalizedString("Are you sure you want to delete all downloads? This action cannot be undone.", comment: "Delete all downloads confirmation message")
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Unified Control Bar - All buttons in one container
            HStack(spacing: 0) {
                // Add Download Menu Button
                Menu {
                    Button(action: {
                        print("DEBUG: Add Files selected")
                        viewModel.showAddDownload = true
                    }) {
                        Label(NSLocalizedString("Add Files", comment: "Add files menu item"), systemImage: "folder")
                    }
                    Button(action: {
                        print("DEBUG: Add Torrent selected")
                        selectTorrentFiles()
                    }) {
                        Label(NSLocalizedString("Add Torrent", comment: "Add torrent menu item"), systemImage: "arrow.down.doc")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(NSLocalizedString("Add", comment: "Add button text"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isAddDownloadHovered ? .white : .primary)
                    .frame(width: 70, height: 32)
                    .contentShape(Rectangle())
                    .background(
                        Color.white.opacity(isAddDownloadHovered ? 0.25 : 0)
                    )
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .help(NSLocalizedString("Add Download", comment: "Add download help text"))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAddDownloadHovered = hovering
                    }
                }
                
                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 20)
                
                // Play Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        playButtonRotation += 360
                    }
                    viewModel.resumeAll()
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isPlayHovered ? .white : .primary)
                        .frame(width: 40, height: 32)
                        .contentShape(Rectangle())
                        .rotationEffect(.degrees(playButtonRotation))
                        .background(
                            Color.white.opacity(isPlayHovered ? 0.25 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Resume All Downloads", comment: "Resume all downloads help text"))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPlayHovered = hovering
                    }
                }
                
                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 20)
                
                // Pause Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)) {
                        pauseButtonScale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        pauseButtonScale = 1.0
                    }
                    viewModel.pauseAll()
                }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isPauseHovered ? .white : .primary)
                        .frame(width: 40, height: 32)
                        .contentShape(Rectangle())
                        .scaleEffect(pauseButtonScale)
                        .background(
                            Color.white.opacity(isPauseHovered ? 0.25 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Pause All Downloads", comment: "Pause all downloads help text"))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPauseHovered = hovering
                    }
                }
                
                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 20)
                
                // Stop Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        stopButtonPulse.toggle()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        stopButtonPulse = false
                    }
                    viewModel.pauseAll()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isStopHovered ? .white : .primary)
                        .frame(width: 40, height: 32)
                        .contentShape(Rectangle())
                        .background(
                            Color.white.opacity(isStopHovered ? 0.25 : 0)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                                .scaleEffect(stopButtonPulse ? 1.8 : 1.0)
                                .opacity(stopButtonPulse ? 0 : 1)
                                .frame(width: 18, height: 18)
                        )
                }
                .buttonStyle(.plain)
                .help(NSLocalizedString("Stop All Downloads", comment: "Stop all downloads help text"))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isStopHovered = hovering
                    }
                }
                
                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 20)
                
                // Actions Menu Button
                Menu {
                    Button(action: { viewModel.selectAll() }) {
                        Label(NSLocalizedString("Select All", comment: "Select all downloads"), systemImage: "checkmark.square.fill")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    
                    Button(action: { viewModel.deselectAll() }) {
                        Label(NSLocalizedString("Deselect All", comment: "Deselect all downloads"), systemImage: "square")
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    Button(action: {
                        deleteAction = .selected
                        showDeleteConfirmation = true
                    }) {
                        Label(NSLocalizedString("Delete Selected", comment: "Delete selected downloads"), systemImage: "trash")
                    }
                    .disabled(viewModel.selectedDownloadIDs.isEmpty)
                    
                    Button(action: {
                        deleteAction = .completed
                        showDeleteConfirmation = true
                    }) {
                        Label(NSLocalizedString("Delete Completed", comment: "Delete completed downloads"), systemImage: "checkmark.circle")
                    }
                    .disabled(viewModel.downloads.filter { $0.status == .completed }.isEmpty)
                    
                    Button(action: {
                        deleteAction = .incomplete
                        showDeleteConfirmation = true
                    }) {
                        Label(NSLocalizedString("Delete Incomplete", comment: "Delete incomplete downloads"), systemImage: "xmark.circle")
                    }
                    .disabled(viewModel.downloads.filter { $0.status != .completed }.isEmpty)
                    
                    Divider()
                    
                    Button(action: {
                        viewModel.cleanupAllTempFiles()
                    }) {
                        Label(NSLocalizedString("Clean Temp Files", comment: "Clean temporary files"), systemImage: "trash.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        deleteAction = .all
                        showDeleteConfirmation = true
                    }) {
                        Label(NSLocalizedString("Delete All", comment: "Delete all downloads"), systemImage: "trash.fill")
                    }
                    .disabled(viewModel.downloads.isEmpty)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .medium))
                        Text(NSLocalizedString("Actions", comment: "Actions menu button"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isActionsHovered ? .white : .primary)
                    .frame(width: 70, height: 32)
                    .contentShape(Rectangle())
                    .background(
                        Color.white.opacity(isActionsHovered ? 0.25 : 0)
                    )
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .help(NSLocalizedString("Actions", comment: "Actions help text"))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isActionsHovered = hovering
                    }
                }
                
                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 20)
                
                // Filter Buttons - يظهر فقط عندما تكون هناك تحميلات
                if !viewModel.downloads.isEmpty {
                    // All Filter Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedCategory = "all"
                        }
                    }) {
                        Text(NSLocalizedString("All", comment: "All downloads filter"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.selectedCategory == "all" ? .white : .primary)
                            .frame(width: 40, height: 32)
                            .contentShape(Rectangle())
                            .background(
                                Color.white.opacity(viewModel.selectedCategory == "all" ? 0.25 : (isAllFilterHovered ? 0.15 : 0))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAllFilterHovered = hovering
                        }
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 20)
                    
                    // Active Filter Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedCategory = "downloading"
                        }
                    }) {
                        Text(NSLocalizedString("Active", comment: "Active downloads filter"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.selectedCategory == "downloading" ? .white : .primary)
                            .frame(width: 50, height: 32)
                            .contentShape(Rectangle())
                            .background(
                                Color.white.opacity(viewModel.selectedCategory == "downloading" ? 0.25 : (isActiveFilterHovered ? 0.15 : 0))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isActiveFilterHovered = hovering
                        }
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 20)
                    
                    // Completed Filter Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedCategory = "completed"
                        }
                    }) {
                        Text(NSLocalizedString("Completed", comment: "Completed downloads filter"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.selectedCategory == "completed" ? .white : .primary)
                            .frame(width: 70, height: 32)
                            .contentShape(Rectangle())
                            .background(
                                Color.white.opacity(viewModel.selectedCategory == "completed" ? 0.25 : (isCompletedFilterHovered ? 0.15 : 0))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCompletedFilterHovered = hovering
                        }
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 20)
                    
                    // Failed Filter Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedCategory = "failed"
                        }
                    }) {
                        Text(NSLocalizedString("Failed", comment: "Failed downloads filter"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(viewModel.selectedCategory == "failed" ? .white : .primary)
                            .frame(width: 50, height: 32)
                            .contentShape(Rectangle())
                            .background(
                                Color.white.opacity(viewModel.selectedCategory == "failed" ? 0.25 : (isFailedFilterHovered ? 0.15 : 0))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFailedFilterHovered = hovering
                        }
                    }
                }

            }
            
            .background(
    ZStack {
        // طبقة زجاج سائل زرقاء مع تعتيم
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.25),
                Color.blue.opacity(0.15),
                Color.white.opacity(0.07)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.4),
                    Color.clear,
                    Color.blue.opacity(0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .mask(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.3)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
        )
        .blur(radius: 2)

        // تأثير لمعان خفيف
        RoundedRectangle(cornerRadius: 24)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.6),
                        Color.blue.opacity(0.2),
                        Color.white.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .blur(radius: 0.5)
    }
)



            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
            .shadow(color: Color.purple.opacity(0.4), radius: 12, x: 0, y: 6)
            .overlay(
                // Top highlight for 3D effect
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .center
                        ),
                        lineWidth: 1.5
                    )
                    .blur(radius: 0.5)
                    .offset(y: 1)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black,
                                Color.black.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            
            Spacer()
            

            
            // Status indicators with matching style
            if !viewModel.downloads.isEmpty {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.green.opacity(0.4), lineWidth: 2)
                                    .scaleEffect(viewModel.downloads.contains { $0.status == .downloading } ? 1.4 : 1.0)
                                    .opacity(viewModel.downloads.contains { $0.status == .downloading } ? 0 : 1)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: viewModel.downloads.filter { $0.status == .downloading }.count)
                            )
                        
                        Text("\(viewModel.downloads.filter { $0.status == .downloading }.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        
                        Text("\(viewModel.downloads.filter { $0.status == .completed }.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
    RoundedRectangle(cornerRadius: 12)
        .fill(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "0A192F").opacity(0.7),
                    Color(hex: "64FFDA").opacity(0.6)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
)
                .shadow(color: Color.white.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            




            // Search field – liquid glass, curved edges, no white
HStack(spacing: 6) {
    Image(systemName: "magnifyingglass")
        .foregroundColor(Color.white.opacity(0.9))
        .font(.system(size: 12, weight: .medium))

    TextField("Search downloads...", text: $viewModel.searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Color.white)
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(
    ZStack {
        // خلفية زجاج سائل داكن-رمادي شفاف بدون بياض
        LinearGradient(
            gradient: Gradient(colors: [
                Color(white: 0.08).opacity(0.55),
                Color(white: 0.04).opacity(0.45),
                Color(white: 0.02).opacity(0.35)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // طبقة لمعان خفيفة جداً (بدون بيض)
        LinearGradient(
            gradient: Gradient(colors: [
                Color(white: 0.18).opacity(0.07),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .center
        )

        // حافة داكنة ناعمة تُبرز الشريط
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(white: 0.15).opacity(0.7),
                        Color(white: 0.08).opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
    }
)



.cornerRadius(12)
.shadow(color: Color(white: 0.0).opacity(0.25), radius: 4, x: 0, y: 2)
.frame(width: 180)

        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .alert(deleteAction.title, isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDeleteAction()
            }
        } message: {
            Text(deleteAction.message)
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.data, .audio, .video, .image, .pdf, .text, .executable]
        
        if panel.runModal() == .OK {
            print("DEBUG: Selected files: \(panel.urls)")
            for url in panel.urls {
                let filePath = url.path
                let fileType = viewModel.detectFileType(from: filePath)
                viewModel.addDownloadEnhanced(
                    url: filePath,
                    fileName: url.lastPathComponent,
                    fileType: fileType,
                    savePath: "~/Downloads",
                    chunks: 16,
                    cookiesPath: nil as String?
                )
            }
        }
    }
    
    private func selectTorrentFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "torrent")!]
        
        if panel.runModal() == .OK {
            print("DEBUG: Selected torrent files: \(panel.urls)")
            for url in panel.urls {
                viewModel.parseTorrentFile(url: url)
            }
        }
    }
    

    
    private func performDeleteAction() {
        switch deleteAction {
        case .selected:
            viewModel.deleteSelectedDownloads()
        case .completed:
            viewModel.deleteCompletedDownloads()
        case .incomplete:
            viewModel.deleteIncompleteDownloads()
        case .all:
            viewModel.deleteAllDownloads()
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var selectedSpeedLimit: String = "Unlimited"
    @State private var showAbout = false
    @State private var showSafarGetProView = false
    @State private var isSpeedLimitHovered = false

    @State private var isSettingsHovered = false
    @State private var isAboutHovered = false
    @State private var isProHovered = false
    @State private var isChromeExtensionHovered = false
    @State private var isSafariExtensionHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Category.all, id: \.id) { category in
                        SidebarItem(
                            category: category,
                            count: countForCategory(category.id),
                            isSelected: viewModel.selectedCategory == category.id,
                            systemName: category.icon,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedCategory = category.id
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(spacing: 8) {
                Menu {
                    ForEach(["Unlimited", "1 MB/s", "5 MB/s", "10 MB/s"], id: \.self) { speed in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                selectedSpeedLimit = speed
                            }
                        }) {
                            HStack {
                                Text(speed)
                                if speed == selectedSpeedLimit {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        
                        Text(NSLocalizedString("Speed Limit", comment: "Speed limit setting"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSpeedLimitHovered ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSpeedLimitHovered ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isSpeedLimitHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSpeedLimitHovered)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .onHover { hovering in
                    isSpeedLimitHovered = hovering
                }
                

                
                // MARK: - Safari Extension Button
                Button(action: {
                    handleSafariExtension()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 16)

                        Text(NSLocalizedString("Safari Extension", comment: "Safari extension button"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSafariExtensionHovered ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSafariExtensionHovered ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1),
                                            lineWidth: 1)
                            )
                    )
                    .scaleEffect(isSafariExtensionHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7),
                               value: isSafariExtensionHovered)
                }
                .buttonStyle(.plain)
                .help("Show Safari Extension status and open for installation")
                .onHover { hovering in
                    isSafariExtensionHovered = hovering
                }

                // MARK: - Chrome Extension Button
                Button(action: {
                    if let url = URL(string: "https://chromewebstore.google.com/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 16)

                        Text(NSLocalizedString("Chrome Extension", comment: "Chrome extension button"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isChromeExtensionHovered ? Color.red.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isChromeExtensionHovered ? Color.red.opacity(0.3) : Color.gray.opacity(0.1),
                                            lineWidth: 1)
                            )
                    )
                    .scaleEffect(isChromeExtensionHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7),
                               value: isChromeExtensionHovered)
                }
                .buttonStyle(.plain)
                .help("Open Chrome Web Store for extension installation")
                .onHover { hovering in
                    isChromeExtensionHovered = hovering
                }



                Button(action: { viewModel.showSettings = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .frame(width: 16)
                        
                        Text(NSLocalizedString("Settings", comment: "Settings button"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSettingsHovered ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSettingsHovered ? Color.green.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isSettingsHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSettingsHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isSettingsHovered = hovering
                }
                
                // SafarGet Pro Button
                Button(action: { showSafarGetProView = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                            .frame(width: 16)
                        
                        Text("SafarGet Pro")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isProHovered ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isProHovered ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isProHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isProHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isProHovered = hovering
                }
                .sheet(isPresented: $showSafarGetProView) {
                    SafarGetProView()
                }
                
                Button(action: { showAbout = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        
                        Text("About")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isAboutHovered ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isAboutHovered ? Color.orange.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isAboutHovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAboutHovered)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isAboutHovered = hovering
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                        .background(.ultraThinMaterial.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 20)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
    
    private func handleSafariExtension() {
        // فتح Safari Extensions Preferences مباشرة
        SFSafariApplication.showPreferencesForExtension(withIdentifier: "BASHEER.SafarGet.Extension") { error in
            if let error = error {
                print("Error opening Safari Extensions Preferences: \(error)")
                // إذا فشل، افتح النافذة البديلة
                DispatchQueue.main.async {
                    viewModel.showSafariExtensionWindow = true
                }
            } else {
                // إغلاق التطبيق بعد فتح Safari Extensions Preferences
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    

    
    private func countForCategory(_ categoryId: String) -> Int {
        switch categoryId {
        case "all": return viewModel.downloads.count
        case "downloading": return viewModel.downloads.filter { $0.status == .downloading || $0.status == .paused }.count
        case "completed": return viewModel.downloads.filter { $0.status == .completed }.count
        case "video": return viewModel.downloads.filter { $0.fileType == .video }.count
        case "document": return viewModel.downloads.filter { $0.fileType == .document }.count
        case "music": return viewModel.downloads.filter { $0.fileType == .audio }.count
        case "program": return viewModel.downloads.filter { $0.fileType == .executable }.count
        case "torrent": return viewModel.downloads.filter { $0.fileType == .torrent }.count
        default: return 0
        }
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    let category: Category
    let count: Int
    let isSelected: Bool
    let systemName: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : category.color)
                    .frame(width: 20)
                
                Text(category.title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected
                                ? Color.white.opacity(0.2)
                                : category.color.opacity(0.2)
                        )
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? category.color
                            : (isHovered ? Color.gray.opacity(0.1) : Color.clear)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Downloads List View (مصلح ومبسط)
struct DownloadsListView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    
    var body: some View {
        ScrollView {
            if viewModel.filteredDownloads.isEmpty {
                EmptyDownloadsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredDownloads) { download in
                        EnhancedDownloadItemCard(
                            item: download, 
                            viewModel: viewModel
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.99)))
                    }
                }
                .padding()
            }
        }
        // مراقبة تحديثات السرعة
        .onReceive(NotificationCenter.default.publisher(for: .downloadSpeedUpdated)) { _ in
            DispatchQueue.main.async {
                viewModel.objectWillChange.send()
            }
        }
        // مراقبة تحديثات التقدم
        .onReceive(NotificationCenter.default.publisher(for: .downloadProgressUpdated)) { _ in
            DispatchQueue.main.async {
                viewModel.objectWillChange.send()
            }
        }
    }
}

// MARK: - Empty Downloads View
struct EmptyDownloadsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.8))
            Text("No downloads")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text("Click '+' to add a download or drag files here")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - About View – Liquid Glass Edition
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    // حالات تفاعل الأزرار
    @State private var cancelHover  = false
    @State private var confirmHover = false
    
    var body: some View {
        ZStack {
            // خلفية زجاجية سائلة متعددة الطبقات
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    .linearGradient(
                        colors: [.blue.opacity(0.18),
                                 .purple.opacity(0.12),
                                 .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .overlay(
                    .linearGradient(
                        colors: [.white.opacity(0.25),
                                 .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .center)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
            
            VStack(spacing: 0) {
                // زر الإغلاق العائم
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.white, .gray.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom)
                            )
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.2), radius: 4)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding([.top, .trailing], 20)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 36) {
                        // الأيقونة المتحركة
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 78, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(
                                    .linearGradient(
                                        colors: [.cyan, .indigo],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                )
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                            
                            VStack(spacing: 6) {
                                Text("SafarGet")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .tracking(0.8)
                                
                                Text("Version 1.0.0 (25)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.secondary.opacity(0.9))
                            }
                        }
                        
                        // العنوان
                        Text("A powerful download manager for macOS")
                            .font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        // الميزات
                        VStack(spacing: 18) {
                            AboutRow(icon: "play.rectangle.fill", text: "Download videos from YouTube")
                            AboutRow(icon: "arrow.down.doc.fill", text: "Manage torrent downloads")
                            AboutRow(icon: "square.split.1x2.fill", text: "Multi-threaded downloads")
                            AboutRow(icon: "safari.fill", text: "Safari & Chrome extensions")
                        }
                        .padding(.horizontal, 20)
                        
                        // حقوق النشر
                        VStack(spacing: 8) {
                            Text("© 2025 SafarGet")
                                .font(.system(size: 14, weight: .semibold))
                            Text("All rights reserved")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                
                // أزرار الإجراء المضيئة
                VStack(spacing: 12) {
                    Divider()
                        .background(.white.opacity(0.15))
                    
                    HStack(spacing: 24) {
                        // زر Cancel
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            cancelHover
                                            ? Color.red.opacity(0.15)
                                            : Color.clear
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    cancelHover
                                                    ? Color.red.opacity(0.6)
                                                    : Color.white.opacity(0.3),
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .foregroundStyle(
                                    cancelHover
                                    ? Color.red
                                    : Color.white.opacity(0.9)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { cancelHover = $0 }
                        
                        // زر Got it
                        Button(action: { dismiss() }) {
                            Text("Got it")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            confirmHover
                                            ? Color.green.opacity(0.8)
                                            : Color.accentColor
                                        )
                                        .shadow(
                                            color: confirmHover
                                                ? Color.accentColor.opacity(0.4)
                                                : .clear,
                                            radius: 8)
                                )
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .onHover { confirmHover = $0 }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 450, height: 550)   // الأبعاد ثابتة
        .cornerRadius(32)
    }
}

// MARK: - About Row
private struct AboutRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    .linearGradient(
                        colors: [.accentColor, .cyan],
                        startPoint: .top,
                        endPoint: .bottom)
                )
                .frame(width: 22)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
}





// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexSanitized)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

