import Foundation
import SwiftUI

// MARK: - File Downloader Extension (Simplified)
// Note: The main download logic has been moved to ViewModel.swift to avoid redeclaration errors.
// This file now contains only helper functions and utilities specific to file downloading.

extension DownloadManagerViewModel {
    
    // MARK: - File Download Utilities
    
    /// Validates if a URL is downloadable
    func validateDownloadURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Check if URL has a valid scheme
        guard let scheme = url.scheme, ["http", "https", "ftp", "ftps"].contains(scheme.lowercased()) else {
            return false
        }
        
        // Check if URL has a host
        guard url.host != nil else { return false }
        
        return true
    }
    
    /// Estimates file size from HTTP headers (if available)
    func estimateFileSize(for url: String, completion: @escaping (Int64?) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String,
               let fileSize = Int64(contentLength) {
                DispatchQueue.main.async {
                    completion(fileSize)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// Generates a safe filename from URL
    func generateSafeFileName(from url: String) -> String {
        guard let urlObject = URL(string: url) else { return "download" }
        
        var fileName = urlObject.lastPathComponent
        
        // If no filename in URL, generate one
        if fileName.isEmpty || fileName == "/" {
            fileName = "download"
        }
        
        // Remove query parameters if present
        if let queryIndex = fileName.firstIndex(of: "?") {
            fileName = String(fileName[..<queryIndex])
        }

        
        // Sanitize filename
        return sanitizeFileName(fileName)
    }
    
    /// Checks if file extension is supported for preview
    func isPreviewableFile(_ fileName: String) -> Bool {
        let previewableExtensions = [
            "pdf", "txt", "rtf", "doc", "docx",
            "jpg", "jpeg", "png", "gif", "bmp", "tiff",
            "mp4", "mov", "avi", "mkv", "mp3", "wav", "m4a"
        ]
        
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        return previewableExtensions.contains(fileExtension)
    }
    
    /// Gets appropriate icon for file type
    func getFileTypeIcon(for fileName: String) -> String {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return "doc.richtext"
        case "txt", "rtf":
            return "doc.text"
        case "doc", "docx":
            return "doc"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        case "mp4", "mov", "avi", "mkv":
            return "play.rectangle"
        case "mp3", "wav", "m4a", "flac":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "dmg", "pkg", "app", "exe":
            return "app.badge"
        default:
            return "doc"
        }
    }
    
    /// Calculates optimal number of chunks based on file size
    func calculateOptimalChunks(for fileSize: Int64) -> Int {
        if fileSize <= 0 {
            return 4 // Default for unknown size
        }
        
        let sizeInMB = Double(fileSize) / (1024 * 1024)
        
        switch sizeInMB {
        case 0..<10:        // < 10 MB
            return 2
        case 10..<50:       // 10-50 MB
            return 4
        case 50..<200:      // 50-200 MB
            return 8
        case 200..<500:     // 200-500 MB
            return 12
        case 500..<1000:    // 500MB-1GB
            return 16
        default:            // > 1GB
            return 20
        }
    }
    
    /// Validates download path and creates directory if needed
    func validateAndCreateDownloadPath(_ path: String) -> Bool {
        let expandedPath = expandTildePath(path)
        
        do {
            try FileManager.default.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            print("❌ Failed to create download directory: \(error)")
            return false
        }
    }
    
    /// Checks available disk space
    func checkAvailableDiskSpace(at path: String) -> Int64? {
        let expandedPath = expandTildePath(path)
        
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: expandedPath)
            return attributes[FileAttributeKey.systemFreeSize] as? Int64
        } catch {
            print("❌ Failed to check disk space: \(error)")
            return nil
        }
    }
    
    /// Validates if there's enough space for download
    func hasEnoughDiskSpace(for fileSize: Int64, at path: String) -> Bool {
        guard let availableSpace = checkAvailableDiskSpace(at: path) else {
            return true // Assume enough space if we can't check
        }
        
        // Require at least 1GB extra space as buffer
        let requiredSpace = fileSize + (1024 * 1024 * 1024)
        return availableSpace >= requiredSpace
    }
    
    /// Cleans up temporary download files
    func cleanupTemporaryFiles(for item: DownloadItem) {
        let expandedPath = expandTildePath(item.savePath)
        let tempFiles = [
            "\(item.fileName).part",
            "\(item.fileName).tmp",
            ".st",
            ".st~",
            ".st.tmp"
        ]
        
        for tempFile in tempFiles {
            let tempFilePath = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
            try? FileManager.default.removeItem(at: tempFilePath)
        }
    }
    
    /// Gets download statistics for a specific item
    func getDownloadStatistics(for item: DownloadItem) -> (averageSpeed: Double, timeElapsed: TimeInterval) {
    let avgSpeed = RealTimeSpeedTracker.shared.getAverageSpeed(for: item.id)
    let startTime = Date() // مؤقت - لأن RealTimeSpeedTracker لا يحفظ وقت البداية
    return (avgSpeed, Date().timeIntervalSince(startTime))
}
    
    /// Formats download statistics for display
    func formatDownloadStatistics(for item: DownloadItem) -> String {
        let stats = getDownloadStatistics(for: item)
        let avgSpeedStr = formatSpeedString(stats.averageSpeed)
        let timeStr = formatTimeInterval(stats.timeElapsed)
        
        return "Avg: \(avgSpeedStr) • Time: \(timeStr)"
    }
}

/// Formats time interval for display
    private func formatTimeInterval(_ seconds: TimeInterval) -> String {
        if seconds.isInfinite || seconds.isNaN || seconds <= 0 {
            return "--:--"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }    

// MARK: - Download Progress Tracking
extension DownloadManagerViewModel {
    
    /// Updates download progress with enhanced tracking
    func updateDownloadProgress(for item: DownloadItem, downloadedBytes: Int64, totalBytes: Int64) {
        DispatchQueue.main.async {
            item.downloadedSize = downloadedBytes
            item.fileSize = totalBytes
            
            if totalBytes > 0 {
                item.progress = Double(downloadedBytes) / Double(totalBytes)
            }
            
            // Update speed calculator
            // تحديث تتبع السرعة
_ = RealTimeSpeedTracker.shared.updateSpeed(
    for: item.id,
    currentBytes: downloadedBytes,
    totalBytes: item.fileSize
)
            
            // Update UI
            self.objectWillChange.send()
        }
    }
    
    /// Handles download completion
    func handleDownloadCompletion(for item: DownloadItem) {
        DispatchQueue.main.async {
            item.status = .completed
            item.progress = 1.0
            item.downloadSpeed = "Completed"
            item.remainingTime = "00:00"
            
            // Clean up temporary files
            self.cleanupTemporaryFiles(for: item)
            
            // Send notification
            self.notificationManager.sendDownloadCompleteNotification(for: item)
            
            // Save state
            self.saveDownloads()
            
            print("✅ Download completed: \(item.fileName)")
        }
    }
    
    /// Handles download failure
    func handleDownloadFailure(for item: DownloadItem, error: Error? = nil) {
        DispatchQueue.main.async {
            item.status = .failed
            
            let errorMessage = error?.localizedDescription ?? "Unknown error"
            print("❌ Download failed: \(item.fileName) - \(errorMessage)")
            
            // Send notification
            self.notificationManager.sendDownloadFailedNotification(
                for: item,
                reason: errorMessage
            )
            
            // Save state
            self.saveDownloads()
        }
    }
    } // نهاية دالة سابقة

/// Sanitizes filename by removing invalid characters
private func sanitizeFileName(_ fileName: String) -> String {
    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let sanitized = fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
    return sanitized.isEmpty ? "download" : sanitized
}

