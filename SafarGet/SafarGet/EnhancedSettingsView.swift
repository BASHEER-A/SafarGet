import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Enhanced Settings View
struct EnhancedSettingsView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @Environment(\.dismiss) var dismiss
    @State private var launchAtStartup = LaunchAtStartupManager.shared.isEnabled
    @State private var selectedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? "English"
    @State private var enableNotifications = NotificationManager.shared.isEnabled
    @State private var showNotificationAlert = false
    
    // New state variables for appearance settings
    @State private var appTransparency: Double = max(0.3, UserDefaults.standard.object(forKey: "AppTransparency") as? Double ?? 1.0)
    @State private var appColorTint: Double = UserDefaults.standard.object(forKey: "AppColorTint") as? Double ?? 0.5
    
    let languages = ["English", "العربية", "Français"]

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    generalSettings
                    downloadSettings
                    notificationSettings
                    appearanceSettings
                }
                .padding(20)
            }

            footerView
        }
        .frame(width: 600, height: 500)
        .background(backgroundView)
        .onAppear {
            loadSettings()
        }
        .alert(NSLocalizedString("Notification Permission", comment: "Notification permission alert title"), isPresented: $showNotificationAlert) {
            Button(NSLocalizedString("Open Settings", comment: "Open settings button")) {
                openNotificationSettings()
            }
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("Please enable notifications in System Preferences to receive download completion alerts.", comment: "Notification permission alert message"))
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "gear")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
                
                Text(NSLocalizedString("Settings", comment: "Settings title"))
                    .font(.system(size: 24, weight: .bold))
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - General Settings
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(.blue)
                Text(NSLocalizedString("General", comment: "General settings section"))
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                // Launch at Startup
                SettingToggleRow(
                    icon: "power",
                    title: NSLocalizedString("Launch at Startup", comment: "Launch at startup setting"),
                    subtitle: NSLocalizedString("Start SafarGet when macOS starts", comment: "Launch at startup description"),
                    isOn: $launchAtStartup
                )
                .onChange(of: launchAtStartup) { newValue in
                    setLaunchAtStartup(enabled: newValue)
                }
                
                Divider()
                
                // Language Selection
                SettingPickerRow(
                    icon: "globe",
                    title: NSLocalizedString("Language", comment: "Language setting"),
                    subtitle: NSLocalizedString("Choose your preferred language", comment: "Language setting description"),
                    selection: $selectedLanguage,
                    options: languages
                )
                .onChange(of: selectedLanguage) { newValue in
                    saveLanguagePreference(newValue)
                }
            }
            .padding(16)
            .background(settingCardBackground)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Download Settings
    private var downloadSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.green)
                Text(NSLocalizedString("Downloads", comment: "Downloads settings section"))
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                // Show in Menu Bar
                SettingToggleRow(
                    icon: "menubar.rectangle",
                    title: NSLocalizedString("Show in Menu Bar", comment: "Show in menu bar setting"),
                    subtitle: NSLocalizedString("Display download status in the menu bar", comment: "Show in menu bar description"),
                    isOn: .init(
                        get: { viewModel.settings.showInMenuBar },
                        set: { viewModel.settings.showInMenuBar = $0 }
                    )
                )
                
                Divider()
                
                // Smart Thread Management
                SettingInfoRow(
                    icon: "square.split.1x2",
                    title: NSLocalizedString("Smart Thread Management", comment: "Smart thread management setting"),
                    subtitle: NSLocalizedString("Automatically detects best thread count", comment: "Smart thread management description"),
                    value: NSLocalizedString("Enabled", comment: "Enabled status"),
                    valueColor: .green
                )
            }
            .padding(16)
            .background(settingCardBackground)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Notification Settings
    private var notificationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.orange)
                Text(NSLocalizedString("Notifications", comment: "Notifications settings section"))
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 12) {
                // Enable Notifications
                SettingToggleRow(
                    icon: "bell.badge",
                    title: NSLocalizedString("Download Notifications", comment: "Download notifications setting"),
                    subtitle: NSLocalizedString("Show notifications when downloads complete", comment: "Download notifications description"),
                    isOn: .init(
                        get: { NotificationManager.shared.isEnabled },
                        set: { newValue in
                            NotificationManager.shared.isEnabled = newValue
                            NotificationManager.shared.saveSettings()
                            if newValue {
                                NotificationManager.shared.requestPermission { granted in
                                    if !granted {
                                        showNotificationAlert = true
                                        NotificationManager.shared.isEnabled = false // Revert if permission not granted
                                        NotificationManager.shared.saveSettings()
                                    }
                                }
                            }
                        }
                    )
                )
                
                Divider()
                
                // Notification Sound
                SettingToggleRow(
                    icon: "speaker.wave.2",
                    title: NSLocalizedString("Notification Sound", comment: "Notification sound setting"),
                    subtitle: NSLocalizedString("Play sound with notifications", comment: "Notification sound description"),
                    isOn: .init(
                        get: { NotificationManager.shared.soundEnabled },
                        set: { NotificationManager.shared.soundEnabled = $0 }
                    )
                )
            }
            .padding(16)
            .background(settingCardBackground)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Appearance Settings
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintbrush")
                    .foregroundColor(.purple)
                Text(NSLocalizedString("Appearance", comment: "Appearance settings section"))
                    .font(.system(size: 16, weight: .semibold))
            }
            
            VStack(spacing: 16) {
                // App Transparency
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("App Transparency", comment: "App transparency setting"))
                                .font(.system(size: 14, weight: .medium))
                            Text(NSLocalizedString("Adjust the transparency level of the app", comment: "App transparency description"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(appTransparency * 100))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $appTransparency, in: 0.3...1.0, step: 0.05)
                        .onChange(of: appTransparency) { newValue in
                            let safeValue = max(0.3, newValue) // Ensure minimum transparency
                            appTransparency = safeValue // Update the state with safe value
                            UserDefaults.standard.set(safeValue, forKey: "AppTransparency")
                            // Trigger UserDefaults change notification
                            UserDefaults.standard.synchronize()
                        }
                }
                
                Divider()
                
                // App Color Tint
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("Color Tint", comment: "Color tint setting"))
                                .font(.system(size: 14, weight: .medium))
                            Text(NSLocalizedString("Adjust the color intensity of the app", comment: "Color tint description"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(appColorTint * 100))%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: $appColorTint, in: 0.0...1.0, step: 0.05)
                        .onChange(of: appColorTint) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "AppColorTint")
                            // Trigger UserDefaults change notification
                            UserDefaults.standard.synchronize()
                        }
                }
                
                Divider()
                
                // Reset to Default
                Button(action: resetAppearanceToDefault) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text(NSLocalizedString("Reset to Default", comment: "Reset to default button"))
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(settingCardBackground)
            .cornerRadius(10)
        }
    }
    
     // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Button(NSLocalizedString("Reset to Defaults", comment: "Reset to defaults button")) {
                resetToDefaults()
            }
            .buttonStyle(.link)
            
            Spacer()
            
            Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button(NSLocalizedString("Save", comment: "Save button")) {
                saveSettings()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    
    // MARK: - Helper Views
    private var backgroundView: some View {
        VisualEffectView(material: .popover, blendingMode: .behindWindow)
    }
    
    private var settingCardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
    
    // MARK: - Helper Functions
    private func loadSettings() {
        launchAtStartup = LaunchAtStartupManager.shared.isEnabled
        
        // Load appearance settings with defaults and ensure minimum values
        let savedTransparency = UserDefaults.standard.object(forKey: "AppTransparency") as? Double ?? 1.0
        appTransparency = max(0.3, savedTransparency) // Ensure minimum transparency for usability
        appColorTint = UserDefaults.standard.object(forKey: "AppColorTint") as? Double ?? 0.5
        
        // Save the corrected value back if it was below minimum
        if savedTransparency < 0.3 {
            UserDefaults.standard.set(appTransparency, forKey: "AppTransparency")
        }
        
        // Load saved language preference or detect from system
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            selectedLanguage = savedLanguage
        } else {
            // Detect system language and set default
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            switch systemLanguage {
            case "ar":
                selectedLanguage = "العربية"
            case "fr":
                selectedLanguage = "Français"
            default:
                selectedLanguage = "English"
            }
        }
        
        enableNotifications = NotificationManager.shared.isEnabled
    }
    
    private func saveSettings() {
        viewModel.saveSettings()
        NotificationManager.shared.saveSettings()
        
        // Save appearance settings with safety checks
        let safeTransparency = max(0.3, appTransparency)
        appTransparency = safeTransparency // Update the state with safe value
        UserDefaults.standard.set(safeTransparency, forKey: "AppTransparency")
        UserDefaults.standard.set(appColorTint, forKey: "AppColorTint")
    }
    
    private func resetToDefaults() {
        launchAtStartup = false
        selectedLanguage = "English"
        enableNotifications = true
        viewModel.settings = AppSettings()
        
        // Reset appearance settings
        appTransparency = 1.0
        appColorTint = 0.5
        UserDefaults.standard.set(appTransparency, forKey: "AppTransparency")
        UserDefaults.standard.set(appColorTint, forKey: "AppColorTint")
        
        setLaunchAtStartup(enabled: false)
        saveLanguagePreference("English")
        NotificationManager.shared.resetToDefaults()
    }
    
    private func resetAppearanceToDefault() {
        appTransparency = 1.0
        appColorTint = 0.5
        UserDefaults.standard.set(appTransparency, forKey: "AppTransparency")
        UserDefaults.standard.set(appColorTint, forKey: "AppColorTint")
        // Trigger UserDefaults change notification
        UserDefaults.standard.synchronize()
    }
    
    private func setLaunchAtStartup(enabled: Bool) {
        LaunchAtStartupManager.shared.setLaunchAtStartup(enabled)
    }
    
    private func saveLanguagePreference(_ language: String) {
        UserDefaults.standard.set(language, forKey: "AppLanguage")
        
        // Map display names to language codes
        let languageCode: String
        switch language {
        case "English":
            languageCode = "en"
        case "العربية":
            languageCode = "ar"
        case "Français":
            languageCode = "fr"
        default:
            languageCode = "en"
        }
        
        // Set the language for the app
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Show restart notification
        showRestartAlert()
    }
    
    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Language Changed", comment: "Language change alert title")
        alert.informativeText = NSLocalizedString("Please restart the app for the language change to take effect.", comment: "Language change alert message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
        alert.runModal()
    }
    
    private func requestNotificationPermission() {
        NotificationManager.shared.requestPermission { granted in
            if granted {
                NotificationManager.shared.enableNotifications()
            } else {
                showNotificationAlert = true
                enableNotifications = false
            }
        }
    }
    
    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Supporting Views (Moved outside EnhancedSettingsView)
struct SettingToggleRow: View {
    var icon: String
    var title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

struct SettingPickerRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }
    }
}

struct SettingInfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(valueColor)
        }
    }
}



// MARK: - Launch at Startup Manager
class LaunchAtStartupManager {
    static let shared = LaunchAtStartupManager()
    
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions
            // This part might need a helper app or a different mechanism for older macOS versions
            // For now, returning false as a placeholder.
            return false
        }
    }
    
    func setLaunchAtStartup(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at startup: \(error)")
            }
        } else {
            // For older macOS versions
            // SMLoginItemSetEnabled("com.SafarGet.LaunchHelper" as CFString, enabled)
            // This part would require a separate helper application and its bundle identifier.
            // For now, no action for older macOS versions.
        }
    }
}




