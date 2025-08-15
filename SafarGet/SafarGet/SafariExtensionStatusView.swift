//
//  SafariExtensionStatusView.swift
//  SafarGet
//
//  Created by Assistant on 02/08/2025.
//

import SwiftUI
import AppKit
import SafariServices

// MARK: - Safari Extension Status View
struct SafariExtensionStatusView: View {
    @State private var extensionStatus: SafariExtensionStatus = .checking
    @State private var showingStatusView = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    enum SafariExtensionStatus {
        case checking
        case enabled
        case disabled
        case notInstalled
    }
    
    var body: some View {
        ZStack {
            // Background blur
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Status Content
                VStack(spacing: 16) {
                    statusContent
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                
                // Action Button
                if extensionStatus != .checking {
                    Button(action: handleActionButton) {
                        HStack {
                            Image(systemName: "safari")
                                .font(.system(size: 16, weight: .medium))
                            Text(actionButtonTitle)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    // Secondary button for continuing without extension
                    if extensionStatus == .disabled || extensionStatus == .notInstalled {
                        Button("Continue without Extension") {
                            showingStatusView = false
                        }
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: 500)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkExtensionStatus()
        }
        .onChange(of: showingStatusView) { showing in
            if !showing {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private var statusContent: some View {
        switch extensionStatus {
        case .checking:
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                
                Text("Checking Safari Extension Status...")
                    .font(.title2)
                    .fontWeight(.medium)
            }
            
        case .enabled:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("SafarGet's extension is currently on.")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("You can turn it off in the Extensions section of Safari Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
        case .disabled:
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("SafarGet's extension is currently off.")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("You can turn it on in the Extensions section of Safari Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
        case .notInstalled:
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("You can turn on SafarGet's extension in the Extensions section of Safari Settings.")
                    .font(.title2)
                    .fontWeight(.medium)
                    .lineLimit(nil)
            }
        }
    }
    
    private var actionButtonTitle: String {
        switch extensionStatus {
        case .checking:
            return ""
        case .enabled:
            return "Quit and Open Safari Settings..."
        case .disabled:
            return "Open Safari Extensions"
        case .notInstalled:
            return "Open Safari Extensions"
        }
    }
    
    private func checkExtensionStatus() {
        // Check if Safari extension is available and enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkSafariExtensionAvailability { status in DispatchQueue.main.async {
                    self.extensionStatus = status
                }
            }
        }
    }
    
    private func checkSafariExtensionAvailability(completion: @escaping (SafariExtensionStatus) -> Void) {
        // Try to detect if Safari extension is running by checking for processes
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if output.contains("SafarGet Extension") {
            // Extension process is running, likely enabled
            completion(.enabled)
        } else {
            // Check if extension bundle exists in Applications
            let appPath = "/Applications/SafarGet.app/Contents/PlugIns/SafarGet Extension.appex"
            if FileManager.default.fileExists(atPath: appPath) {
                completion(.disabled)
            } else {
                completion(.notInstalled)
            }
        }
    }
    
    private func handleActionButton() {
        switch extensionStatus {
        case .enabled, .disabled, .notInstalled:
            openSafariExtensions()
        case .checking:
            break
        }
    }
    
    private func openSafariExtensions() {
        // Close the status view first
        presentationMode.wrappedValue.dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Hide main app window temporarily
            NSApp.windows.first?.miniaturize(nil)
            
            // Method 1: Try opening Safari Extensions preferences directly
            if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions?Extensions") {
                NSWorkspace.shared.open(url)
            }
            
            // Method 2: Fallback with AppleScript to open Safari settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.openSafariSettingsWithAppleScript()
            }
            
            // Show a notification after opening settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NotificationManager.shared.sendCustomNotification(
                    title: "Safari Extensions Opened",
                    body: "Look for SafarGet Extension in the Extensions list to enable it."
                )
                
                // Restore window if extension is disabled/not installed
                if self.extensionStatus != .enabled {
                    NSApp.windows.first?.deminiaturize(nil)
                }
            }
        }
    }
    
    private func openSafariSettingsWithAppleScript() {
        let script = """
        try
            tell application "Safari" to activate
            delay 1
            tell application "System Events"
                keystroke "," using command down
                delay 1.5
                try
                    tell process "Safari"
                        -- Try to click Extensions tab in different possible locations
                        try
                            click button "Extensions" of toolbar of window 1
                        on error
                            try
                                click button "Extensions" of tab group 1 of window 1
                            on error
                                try
                                    click UI element "Extensions" of window 1
                                end try
                            end try
                        end try
                        
                        -- Wait a moment for the extensions to load
                        delay 2
                        
                        -- Try to find and enable SafarGet extension
                        try
                            tell window 1
                                set extensionRows to every row of table 1 of scroll area 1
                                repeat with theRow in extensionRows
                                    if (value of static text 1 of theRow as string) contains "SafarGet" then
                                        set extensionCheckbox to checkbox 1 of theRow
                                        if (value of extensionCheckbox as boolean) is false then
                                            click extensionCheckbox
                                            delay 0.5
                                        end if
                                    end if
                                end repeat
                            end tell
                        end try
                    end tell
                end try
            end tell
        on error errMsg
            -- If AppleScript fails, just try to open Safari
            tell application "Safari" to activate
        end try
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("❌ AppleScript error: \(error)")
                // Fallback: just open Safari
                if let safariPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
                    let configuration = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: safariPath, configuration: configuration) { _, error in
                        if let error = error {
                            print("❌ Failed to open Safari: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// VisualEffectView is defined in Sheets.swift

// MARK: - Preview
#if DEBUG
struct SafariExtensionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SafariExtensionStatusView()
            .frame(width: 600, height: 400)
    }
}
#endif