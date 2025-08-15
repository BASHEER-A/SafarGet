import Foundation
import Network
import Combine

// MARK: - Network Monitor for Internet Connection
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var lastDisconnectTime: Date?
    
    // Downloads that were active before disconnection
    private var pausedDownloadsBeforeDisconnect: Set<UUID> = []
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
        
        var description: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .unknown: return "Unknown"
            case .none: return "No Connection"
            }
        }
    }
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Update connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }
        
        // Handle connection state changes
        if !wasConnected && isConnected {
            // Internet reconnected
            handleReconnection()
        } else if wasConnected && !isConnected {
            // Internet disconnected
            handleDisconnection()
        }
    }
    
    private func handleDisconnection() {
        print("🔴 Internet disconnected")
        lastDisconnectTime = Date()
        
        // Store currently downloading items and pause them
        NotificationCenter.default.post(
            name: .internetDisconnected,
            object: nil,
            userInfo: ["pausedDownloads": pausedDownloadsBeforeDisconnect]
        )
    }
    
    private func handleReconnection() {
        print("🟢 Internet reconnected")
        
        // Resume downloads that were paused due to disconnection
        NotificationCenter.default.post(
            name: .internetReconnected,
            object: nil,
            userInfo: ["resumeDownloads": pausedDownloadsBeforeDisconnect]
        )
        
        // Clear the list
        pausedDownloadsBeforeDisconnect.removeAll()
    }
    
    func storePausedDownload(_ downloadId: UUID) {
        pausedDownloadsBeforeDisconnect.insert(downloadId)
    }
    
    func removePausedDownload(_ downloadId: UUID) {
        pausedDownloadsBeforeDisconnect.remove(downloadId)
    }
    
    deinit {
        monitor.cancel()
    }
}

// أضف بعد دالة handleReconnection() - حوالي السطر 98
func updateDownloadSpeedsOnDisconnect(_ downloads: [DownloadItem]) {
    for download in downloads where download.status == .downloading {
        DispatchQueue.main.async {
            download.instantSpeed = 0
            download.downloadSpeed = "No Connection"
            // احتفظ بآخر قيمة progress
            download.lastProgressBeforeDisconnect = download.progress
        }
    }
}


// MARK: - Notification Names
extension Notification.Name {
    static let internetDisconnected = Notification.Name("internetDisconnected")
    static let internetReconnected = Notification.Name("internetReconnected")
}

// MARK: - File Visibility Manager
class FileVisibilityManager {
    static let shared = FileVisibilityManager()
    
    private let hiddenFilePrefix = "."
    private let tempFileSuffix = ".downloading"
    
    // Hide file during download
    func hideDownloadingFile(at path: String, fileName: String) -> String {
        let hiddenFileName = "\(hiddenFilePrefix)\(fileName)\(tempFileSuffix)"
        return hiddenFileName
    }
    
    // Reveal file after completion
    func revealCompletedFile(at path: String, tempFileName: String, finalFileName: String) -> Bool {
        let fileManager = FileManager.default
        let tempFileURL = URL(fileURLWithPath: path).appendingPathComponent(tempFileName)
        let finalFileURL = URL(fileURLWithPath: path).appendingPathComponent(finalFileName)
        
        do {
            // Move temp file to final location
            if fileManager.fileExists(atPath: tempFileURL.path) {
                // Remove existing file if exists
                if fileManager.fileExists(atPath: finalFileURL.path) {
                    try fileManager.removeItem(at: finalFileURL)
                }
                
                // Move temp to final
                try fileManager.moveItem(at: tempFileURL, to: finalFileURL)
                
                // Remove hidden attribute
                removeHiddenAttribute(from: finalFileURL)
                
                return true
            }
        } catch {
            print("❌ Error revealing file: \(error)")
        }
        
        return false
    }
    
    private func removeHiddenAttribute(from url: URL) {
        // On macOS, files starting with . are automatically hidden
        // No additional attributes needed
    }
    
    // Get temporary file name for download
    func getTempFileName(for originalFileName: String) -> String {
        return "\(hiddenFilePrefix)\(originalFileName)\(tempFileSuffix)"
    }
    
    // Clean up incomplete downloads
    func cleanupIncompleteDownloads(at path: String) {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: path)
            
            for file in files {
                if file.hasPrefix(hiddenFilePrefix) && file.hasSuffix(tempFileSuffix) {
                    let fileURL = URL(fileURLWithPath: path).appendingPathComponent(file)
                    
                    // Check if file is older than 24 hours
                    if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let creationDate = attributes[.creationDate] as? Date,
                       Date().timeIntervalSince(creationDate) > 86400 { // 24 hours
                        
                        try? fileManager.removeItem(at: fileURL)
                        print("🧹 Cleaned up old temp file: \(file)")
                    }
                }
            }
        } catch {
            print("❌ Error cleaning up temp files: \(error)")
        }
    }
}
