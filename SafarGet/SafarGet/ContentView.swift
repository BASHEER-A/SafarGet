import SwiftUI
import UniformTypeIdentifiers
import Combine
import AppKit

// MARK: - Content View (Old Interface)
struct ContentView: View {
    @StateObject private var viewModel = DownloadManagerViewModel()
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
            .opacity(showSafariExtensionStatus ? 0 : 1.0)
            .overlay(
                // Color tint overlay
                Color.blue.opacity(appColorTint * 0.1)
                    .blendMode(.overlay)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
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
            UserDefaults.standard.set(currentTime, forKey: "LastSafariExtensionStatusCheck")
            UserDefaults.standard.set(false, forKey: "ForceShowExtensionStatus")
            
            // Show Safari Extension Status after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSafariExtensionStatus = true
            }
        }
    }
}
