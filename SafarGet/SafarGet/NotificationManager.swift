import Foundation
import UserNotifications
import AppKit

// MARK: - Notification Manager
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isEnabled: Bool = true
    @Published var soundEnabled: Bool = true
    
    private var notificationCenter: UNUserNotificationCenter?
    
    override init() {
        super.init()
        loadSettings()
        
        // ✅ إصلاح: التحقق من وجود bundle قبل تهيئة NotificationCenter
        if Bundle.main.bundleIdentifier != nil {
            notificationCenter = UNUserNotificationCenter.current()
            notificationCenter?.delegate = self
        } else {
            print("⚠️ Warning: No bundle identifier found, notifications disabled")
        }
    }
    
    // MARK: - Permission Management
    func requestPermission(completion: @escaping (Bool) -> Void) {
        guard let notificationCenter = notificationCenter else {
            completion(false)
            return
        }
        
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                    completion(false)
                } else {
                    completion(granted)
                }
            }
        }
    }
    
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        guard let notificationCenter = notificationCenter else {
            completion(false)
            return
        }
        
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Settings
    func enableNotifications() {
        isEnabled = true
        saveSettings()
    }
    
    func disableNotifications() {
        isEnabled = false
        saveSettings()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "NotificationsEnabled")
        UserDefaults.standard.set(soundEnabled, forKey: "NotificationSoundEnabled")
    }
    
    func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "NotificationsEnabled")
        soundEnabled = UserDefaults.standard.bool(forKey: "NotificationSoundEnabled")
        
        // Default to true if not set
        if !UserDefaults.standard.bool(forKey: "NotificationsEnabled") {
            isEnabled = true
            saveSettings()
        }
    }
    
    func resetToDefaults() {
        isEnabled = true
        soundEnabled = true
        saveSettings()
    }
    
    // MARK: - Send Notifications
    func sendDownloadCompleteNotification(for item: DownloadItem) {
        guard isEnabled else { return }
        
        checkPermissionStatus { [weak self] authorized in
            guard authorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Download Complete"
            content.subtitle = item.fileName
            content.body = "Your download has been completed successfully"
            
            if self?.soundEnabled == true {
                content.sound = .default
            }
            
            // Add file info to userInfo for click handling
            content.userInfo = [
                "downloadId": item.id.uuidString,
                "filePath": item.savePath,
                "fileName": item.fileName
            ]
            
            // Create category with actions
            let openAction = UNNotificationAction(
                identifier: "OPEN_FILE",
                title: "Open",
                options: .foreground
            )
            
            let showInFinderAction = UNNotificationAction(
                identifier: "SHOW_IN_FINDER",
                title: "Show in Finder",
                options: .foreground
            )
            
            let category = UNNotificationCategory(
                identifier: "DOWNLOAD_COMPLETE",
                actions: [openAction, showInFinderAction],
                intentIdentifiers: [],
                options: []
            )
            
            content.categoryIdentifier = "DOWNLOAD_COMPLETE"
            self?.notificationCenter?.setNotificationCategories([category])
            
            // Create request
            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: nil
            )
            
            // Send notification
            self?.notificationCenter?.add(request) { error in
                if let error = error {
                    print("❌ Failed to send notification: \(error)")
                }
            }
        }
    }
    
    func sendDownloadFailedNotification(for item: DownloadItem, reason: String? = nil) {
        guard isEnabled else { return }
        
        checkPermissionStatus { [weak self] authorized in
            guard authorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Download Failed"
            content.subtitle = item.fileName
            content.body = reason ?? "The download could not be completed"
            
            if self?.soundEnabled == true {
                content.sound = .default
            }
            
            content.userInfo = [
                "downloadId": item.id.uuidString,
                "fileName": item.fileName
            ]
            
            let request = UNNotificationRequest(
                identifier: "\(item.id.uuidString)-failed",
                content: content,
                trigger: nil
            )
            
            self?.notificationCenter?.add(request) { error in
                if let error = error {
                    print("❌ Failed to send notification: \(error)")
                }
            }
        }
    }
    
    func sendCustomNotification(title: String, body: String) {
        guard isEnabled else { return }
        
        checkPermissionStatus { [weak self] authorized in
            guard authorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            
            if self?.soundEnabled == true {
                content.sound = .default
            }
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            self?.notificationCenter?.add(request) { error in
                if let error = error {
                    print("❌ Failed to send custom notification: \(error)")
                }
            }
        }
    }
    
    func sendBatchDownloadCompleteNotification(count: Int) {
        guard isEnabled else { return }
        
        checkPermissionStatus { [weak self] authorized in
            guard authorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Downloads Complete"
            content.body = "\(count) downloads have been completed successfully"
            
            if self?.soundEnabled == true {
                content.sound = .default
            }
            
            let request = UNNotificationRequest(
                identifier: "batch-complete-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            
            self?.notificationCenter?.add(request) { error in
                if let error = error {
                    print("❌ Failed to send notification: \(error)")
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "OPEN_FILE":
            if let filePath = userInfo["filePath"] as? String,
               let fileName = userInfo["fileName"] as? String {
                openFile(at: filePath, named: fileName)
            }
            
        case "SHOW_IN_FINDER":
            if let filePath = userInfo["filePath"] as? String {
                showInFinder(at: filePath)
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User clicked on notification body
            if let filePath = userInfo["filePath"] as? String {
                showInFinder(at: filePath)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // MARK: - File Actions
    private func openFile(at path: String, named fileName: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(fileName)
        NSWorkspace.shared.open(fileURL)
    }
    
    private func showInFinder(at path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let folderURL = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
    }
}
