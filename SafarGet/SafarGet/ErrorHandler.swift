import Foundation
import SwiftUI

// MARK: - Simple Error Handler
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: DownloadError?
    @Published var showErrorAlert = false
    
    // MARK: - Download Error
    struct DownloadError: Identifiable {
        let id = UUID()
        let type: ErrorType
        let message: String
        let fileName: String
        let isRetryable: Bool
        
        var formattedMessage: String {
            return "\(type.rawValue): \(message)"
        }
    }
    
    enum ErrorType: String {
        case network = "Network Error"
        case fileSystem = "File System Error"
        case permission = "Permission Error"
        case server = "Server Error"
        case process = "Process Error"
        case unknown = "Unknown Error"
    }
    
    // MARK: - Error Detection
    func detectError(from output: String, exitCode: Int32, fileName: String) -> DownloadError? {
        let lowercasedOutput = output.lowercased()
        
        // Network Errors
        if lowercasedOutput.contains("timeout") || lowercasedOutput.contains("connection refused") {
            return DownloadError(
                type: .network,
                message: "Connection timeout or refused",
                fileName: fileName,
                isRetryable: true
            )
        }
        
        // Server Errors
        if lowercasedOutput.contains("404") || lowercasedOutput.contains("not found") {
            return DownloadError(
                type: .server,
                message: "File not found (404)",
                fileName: fileName,
                isRetryable: false
            )
        }
        
        if lowercasedOutput.contains("403") || lowercasedOutput.contains("forbidden") {
            return DownloadError(
                type: .server,
                message: "Access forbidden (403)",
                fileName: fileName,
                isRetryable: false
            )
        }
        
        if lowercasedOutput.contains("429") || lowercasedOutput.contains("too many requests") {
            return DownloadError(
                type: .server,
                message: "Too many requests (429) - Rate limited",
                fileName: fileName,
                isRetryable: true
            )
        }
        
        // File System Errors
        if lowercasedOutput.contains("no space left") || lowercasedOutput.contains("disk full") {
            return DownloadError(
                type: .fileSystem,
                message: "No disk space available",
                fileName: fileName,
                isRetryable: false
            )
        }
        
        if lowercasedOutput.contains("permission denied") || lowercasedOutput.contains("access denied") {
            return DownloadError(
                type: .permission,
                message: "Permission denied - Check disk access",
                fileName: fileName,
                isRetryable: false
            )
        }
        
        // Process Errors
        if exitCode == 15 || exitCode == 9 {
            return DownloadError(
                type: .process,
                message: "Process terminated",
                fileName: fileName,
                isRetryable: true
            )
        }
        
        // Unknown Error
        return DownloadError(
            type: .unknown,
            message: "Unknown error occurred",
            fileName: fileName,
            isRetryable: true
        )
    }
    
    // MARK: - Error Handling
    func handleError(_ error: DownloadError, for downloadItem: DownloadItem) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showErrorAlert = true
        }
        
        print("❌ [ERROR] \(error.formattedMessage)")
        print("📁 File: \(error.fileName)")
        print("🔄 Retryable: \(error.isRetryable)")
        
        // Handle specific error types
        switch error.type {
        case .network:
            handleNetworkError(error, for: downloadItem)
        case .fileSystem:
            handleFileSystemError(error, for: downloadItem)
        case .permission:
            handlePermissionError(error, for: downloadItem)
        case .server:
            handleServerError(error, for: downloadItem)
        case .process:
            handleProcessError(error, for: downloadItem)
        case .unknown:
            handleUnknownError(error, for: downloadItem)
        }
    }
    
    // MARK: - Specific Error Handlers
    private func handleNetworkError(_ error: DownloadError, for downloadItem: DownloadItem) {
        if error.isRetryable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                downloadItem.status = .waiting
                NotificationCenter.default.post(
                    name: .retryDownload,
                    object: nil,
                    userInfo: ["downloadId": downloadItem.id]
                )
            }
        } else {
            downloadItem.status = .failed
        }
    }
    
    private func handleFileSystemError(_ error: DownloadError, for downloadItem: DownloadItem) {
        if error.message.contains("No disk space") {
            checkDiskSpace(for: downloadItem)
        }
        downloadItem.status = .failed
    }
    
    private func handlePermissionError(_ error: DownloadError, for downloadItem: DownloadItem) {
        requestDiskAccess()
        downloadItem.status = .failed
    }
    
    private func handleServerError(_ error: DownloadError, for downloadItem: DownloadItem) {
        if error.isRetryable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                downloadItem.status = .waiting
                NotificationCenter.default.post(
                    name: .retryDownload,
                    object: nil,
                    userInfo: ["downloadId": downloadItem.id]
                )
            }
        } else {
            downloadItem.status = .failed
        }
    }
    
    private func handleProcessError(_ error: DownloadError, for downloadItem: DownloadItem) {
        if downloadItem.status != .paused {
            downloadItem.status = .failed
        }
    }
    
    private func handleUnknownError(_ error: DownloadError, for downloadItem: DownloadItem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            downloadItem.status = .waiting
            NotificationCenter.default.post(
                name: .retryDownload,
                object: nil,
                userInfo: ["downloadId": downloadItem.id]
            )
        }
    }
    
    // MARK: - Utility Functions
    private func checkDiskSpace(for downloadItem: DownloadItem) {
        let expandedPath = (downloadItem.savePath as NSString).expandingTildeInPath
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: expandedPath)
            let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
            let requiredSpace = downloadItem.fileSize + (1024 * 1024 * 1024) // 1GB buffer
            
            if freeSpace < requiredSpace {
                let alert = NSAlert()
                alert.messageText = "Insufficient Disk Space"
                alert.informativeText = "You need at least \(formatFileSize(requiredSpace)) of free space to download '\(downloadItem.fileName)'. Available: \(formatFileSize(freeSpace))"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } catch {
            print("❌ Failed to check disk space: \(error)")
        }
    }
    
    private func requestDiskAccess() {
        let alert = NSAlert()
        alert.messageText = "Disk Access Required"
        alert.informativeText = "SafarGet needs full disk access to download files. Please grant permission in System Preferences > Security & Privacy > Privacy > Full Disk Access."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
    

}

// MARK: - Notification Extensions
extension Notification.Name {
    static let retryDownload = Notification.Name("retryDownload")
} 