//
//  SafariExtensionWindow.swift
//  SafarGet
//
//  Created by SafarGet Team on 2025.

import SwiftUI
import AppKit
import UserNotifications
import SafariServices

// MARK: - Safari Extension Window
struct SafariExtensionWindow: View {
    @Environment(\.dismiss) var dismiss
    @State private var isButtonHovered = false
    
    var body: some View {
        VStack(spacing: 24) {
            // الأيقونة
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // النص
            VStack(spacing: 8) {
                Text("SafarGet's extension is currently on.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("You can turn it off in the Extensions section of Safari Settings.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // الزر
            Button(action: {
                // إغلاق النافذة أولاً
                dismiss()
                // ثم فتح Extensions Preferences
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    openSafariExtensionsPreferences()
                }
            }) {
                Text("Quit and Open Safari Extensions Preferences…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isButtonHovered ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isButtonHovered = hovering
                }
            }
        }
        .padding(32)
        .frame(width: 400, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func openSafariExtensionsPreferences() {
        // استخدام SafariServices لفتح Extensions Preferences مباشرة
        let extensionBundleIdentifier = "BASHEER.SafarGet.Extension"
        
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error opening Safari Extensions: \(error)")
                    
                    // Fallback: فتح Safari فقط
                    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Safari.app"), configuration: NSWorkspace.OpenConfiguration())
                    
                    // إرسال إشعار للمستخدم
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let content = UNMutableNotificationContent()
                        content.title = "Safari Opened"
                        content.body = "Please press Cmd+, then click Extensions tab to manage SafarGet Extension."
                        
                        let request = UNNotificationRequest(identifier: "safari-opened", content: content, trigger: nil)
                        UNUserNotificationCenter.current().add(request)
                    }
                } else {
                    // تم فتح Extensions Preferences بنجاح
                    print("Safari Extensions Preferences opened successfully")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SafariExtensionWindow()
} 