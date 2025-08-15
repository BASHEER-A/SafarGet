import Foundation
import SwiftUI

// ✅ أضف هذا في أول الملف بعد الـ imports
extension Notification.Name {
    static let downloadProgressUpdated = Notification.Name("downloadProgressUpdated")
    static let downloadSpeedUpdated = Notification.Name("downloadSpeedUpdated")
    static let showSafariExtensionStatus = Notification.Name("showSafariExtensionStatus")
    static let newDownload = Notification.Name("newDownload")
    static let youtubeDownloadRequest = Notification.Name("youtubeDownloadRequest")
}

// ✅ إضافة DownloadPriority enum
enum DownloadPriority: String, Codable, CaseIterable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"
    case urgent = "Urgent"
    
    var displayText: String {
        return self.rawValue
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

class DownloadItem: Identifiable, ObservableObject, Codable {
    enum Status: String, Codable {
        case waiting = "Waiting"
        case downloading = "Downloading"
        case paused = "Paused"
        case completed = "Completed"
        case failed = "Failed"
        case stopped = "Stopped"
        case cancelled = "Cancelled"
        
        var displayText: String {
            return self.rawValue
        }
        
        var color: Color {
            switch self {
            case .waiting: return .gray
            case .downloading: return .blue
            case .paused: return .orange
            case .completed: return .green
            case .failed: return .red
            case .stopped: return .purple
            case .cancelled: return .red
            }
        }
    }
    
    enum FileType: String, CaseIterable, Codable {
        case video = "Video"
        case audio = "Audio"
        case document = "Document"
        case executable = "Executable"
        case compressed = "Compressed"
        case image = "Image"
        case torrent = "Torrent"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .video: return "play.rectangle.fill"
            case .audio: return "music.note"
            case .document: return "doc.fill"
            case .executable: return "desktopcomputer"
            case .compressed: return "archivebox.fill"
            case .image: return "photo.fill"
            case .torrent: return "arrow.down.circle.fill"
            case .other: return "doc.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .video: return Color(red: 1.0, green: 0.2, blue: 0.3)
            case .audio: return Color(red: 1.0, green: 0.4, blue: 0.6)
            case .document: return Color(red: 0.2, green: 0.6, blue: 1.0)
            case .compressed: return Color(red: 1.0, green: 0.7, blue: 0.2)
            case .executable: return Color(red: 0.3, green: 0.8, blue: 0.4)
            case .image: return Color(red: 0.8, green: 0.4, blue: 1.0)
            case .torrent: return Color(red: 0.2, green: 0.8, blue: 0.5)
            case .other: return Color.gray
            }
        }
    }
    

    
    let id: UUID
    @Published var fileName: String
    @Published var url: String
    @Published var fileSize: Int64
    @Published var downloadedSize: Int64
    @Published var progress: Double
    @Published var status: Status
    @Published var fileType: FileType // ✅ إضافة fileType
    @Published var downloadSpeed: String // Main speed (MB/s)
    @Published var instantSpeed: Double // Instant speed (KB/s) - raw bytes/sec
    @Published var remainingTime: String
    @Published var savePath: String
    @Published var chunks: Int
    @Published var cookiesPath: String?
    @Published var isYouTubeVideo: Bool
    @Published var videoQuality: String
    @Published var videoFormat: String
    @Published var actualVideoTitle: String
    @Published var actualFileSize: String // ✅ إضافة actualFileSize
    @Published var isTorrent: Bool
    @Published var peers: String
    @Published var seeds: String
    @Published var uploadSpeed: String
    @Published var wasManuallyPaused: Bool
    @Published var audioOnly: Bool // ✅ إضافة audioOnly
    @Published var maxSpeed: Double // ✅ إضافة maxSpeed
    @Published var lastProgressBeforeDisconnect: Double = 0
    @Published var lastSpeedBeforeDisconnect: Double = 0
    @Published var disconnectTime: Date? // ✅ إضافة وقت انقطاع الإنترنت
    @Published var lastPeersUpdate: Date?
    @Published var lastSeedsUpdate: Date?
    @Published var isResuming: Bool = false // ✅ إضافة علامة للاستئناف
    @Published var customHeaders: [String: String]? // ✅ إضافة headers مخصصة
    @Published var isStreamingVideo: Bool = false // ✅ إضافة علامة للفيديو المباشر
    @Published var pageTitle: String = "" // ✅ إضافة عنوان الصفحة
    @Published var videoType: String = "unknown" // ✅ إضافة نوع الفيديو
    
    // ✅ إضافة الخصائص المفقودة
    @Published var priority: DownloadPriority
    @Published var retryCount: Int
    @Published var errorMessage: String?
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var currentSpeed: Int64

    // Transient properties (not Codable)
    // Transient properties (not Codable)
var processTask: Process? = nil
var lastSpeedUpdate: Date = Date()
var speedHistory: [Double] = []


    private enum CodingKeys: String, CodingKey {
    case id, fileName, url, fileSize, downloadedSize, progress, status, fileType
    case downloadSpeed, instantSpeed, remainingTime, savePath, chunks, cookiesPath
    case isYouTubeVideo, videoQuality, videoFormat, actualVideoTitle, actualFileSize
    case isTorrent, peers, seeds, uploadSpeed, wasManuallyPaused, audioOnly, maxSpeed
    case lastProgressBeforeDisconnect, lastSpeedBeforeDisconnect, disconnectTime, customHeaders
    case isStreamingVideo, pageTitle, videoType
    case priority, retryCount, errorMessage, startTime, endTime, currentSpeed
}
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.url = try container.decode(String.self, forKey: .url)
        self.fileSize = try container.decode(Int64.self, forKey: .fileSize)
        self.downloadedSize = try container.decode(Int64.self, forKey: .downloadedSize)
        self.progress = try container.decode(Double.self, forKey: .progress)
        self.status = try container.decode(Status.self, forKey: .status)
        self.fileType = try container.decodeIfPresent(FileType.self, forKey: .fileType) ?? .other
        self.downloadSpeed = try container.decode(String.self, forKey: .downloadSpeed)
        self.instantSpeed = try container.decode(Double.self, forKey: .instantSpeed)
        self.remainingTime = try container.decode(String.self, forKey: .remainingTime)
        self.savePath = try container.decode(String.self, forKey: .savePath)
        self.chunks = try container.decode(Int.self, forKey: .chunks)
        self.cookiesPath = try container.decodeIfPresent(String.self, forKey: .cookiesPath)
        self.isYouTubeVideo = try container.decode(Bool.self, forKey: .isYouTubeVideo)
        self.videoQuality = try container.decode(String.self, forKey: .videoQuality)
        self.videoFormat = try container.decode(String.self, forKey: .videoFormat)
        self.actualVideoTitle = try container.decode(String.self, forKey: .actualVideoTitle)
        self.actualFileSize = try container.decodeIfPresent(String.self, forKey: .actualFileSize) ?? ""
        self.isTorrent = try container.decode(Bool.self, forKey: .isTorrent)
        self.peers = try container.decode(String.self, forKey: .peers)
        self.seeds = try container.decode(String.self, forKey: .seeds)
        self.uploadSpeed = try container.decode(String.self, forKey: .uploadSpeed)
        self.wasManuallyPaused = try container.decode(Bool.self, forKey: .wasManuallyPaused)
        self.audioOnly = try container.decodeIfPresent(Bool.self, forKey: .audioOnly) ?? false
        self.maxSpeed = try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? 0
        self.lastProgressBeforeDisconnect = try container.decodeIfPresent(Double.self, forKey: .lastProgressBeforeDisconnect) ?? 0
        self.lastSpeedBeforeDisconnect = try container.decodeIfPresent(Double.self, forKey: .lastSpeedBeforeDisconnect) ?? 0
        self.disconnectTime = try container.decodeIfPresent(Date.self, forKey: .disconnectTime)
        self.customHeaders = try container.decodeIfPresent([String: String].self, forKey: .customHeaders)
        self.isStreamingVideo = try container.decodeIfPresent(Bool.self, forKey: .isStreamingVideo) ?? false
        self.pageTitle = try container.decodeIfPresent(String.self, forKey: .pageTitle) ?? ""
        self.videoType = try container.decodeIfPresent(String.self, forKey: .videoType) ?? "unknown"
        
        // Decode Advanced Download Manager properties
        self.priority = try container.decodeIfPresent(DownloadPriority.self, forKey: .priority) ?? .normal
        self.retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        self.startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        self.endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        self.currentSpeed = try container.decodeIfPresent(Int64.self, forKey: .currentSpeed) ?? 0

    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(url, forKey: .url)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(downloadedSize, forKey: .downloadedSize)
        try container.encode(progress, forKey: .progress)
        try container.encode(status, forKey: .status)
        try container.encode(fileType, forKey: .fileType)
        try container.encode(downloadSpeed, forKey: .downloadSpeed)
        try container.encode(instantSpeed, forKey: .instantSpeed)
        try container.encode(remainingTime, forKey: .remainingTime)
        try container.encode(savePath, forKey: .savePath)
        try container.encode(chunks, forKey: .chunks)
        try container.encode(cookiesPath, forKey: .cookiesPath)
        try container.encode(isYouTubeVideo, forKey: .isYouTubeVideo)
        try container.encode(videoQuality, forKey: .videoQuality)
        try container.encode(videoFormat, forKey: .videoFormat)
        try container.encode(actualVideoTitle, forKey: .actualVideoTitle)
        try container.encode(actualFileSize, forKey: .actualFileSize)
        try container.encode(isTorrent, forKey: .isTorrent)
        try container.encode(peers, forKey: .peers)
        try container.encode(seeds, forKey: .seeds)
        try container.encode(uploadSpeed, forKey: .uploadSpeed)
        try container.encode(wasManuallyPaused, forKey: .wasManuallyPaused)
        try container.encode(audioOnly, forKey: .audioOnly)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encode(lastProgressBeforeDisconnect, forKey: .lastProgressBeforeDisconnect)
        try container.encode(lastSpeedBeforeDisconnect, forKey: .lastSpeedBeforeDisconnect)
        try container.encode(disconnectTime, forKey: .disconnectTime)
        try container.encode(customHeaders, forKey: .customHeaders)
        try container.encode(isStreamingVideo, forKey: .isStreamingVideo)
        try container.encode(pageTitle, forKey: .pageTitle)
        try container.encode(videoType, forKey: .videoType)
        
        // Encode Advanced Download Manager properties
        try container.encode(priority, forKey: .priority)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encode(errorMessage, forKey: .errorMessage)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(currentSpeed, forKey: .currentSpeed)
    }
    
    // ✅ إضافة الـ Constructor المطلوب
    init(fileName: String, url: String, fileSize: Int64, fileType: FileType) {
        self.id = UUID()
        self.fileName = fileName
        self.url = url
        self.fileSize = fileSize
        self.fileType = fileType
        self.downloadedSize = 0
        self.progress = 0.0
        self.status = .waiting
        self.downloadSpeed = "0 KB/s"
        self.instantSpeed = 0.0
        self.remainingTime = "--:--"
        self.savePath = "~/Downloads"
        self.chunks = 16
        self.cookiesPath = nil
        self.isYouTubeVideo = false
        self.videoQuality = ""
        self.videoFormat = ""
        self.actualVideoTitle = ""
        self.actualFileSize = ""
        self.isTorrent = false
        self.peers = ""
        self.seeds = ""
        self.uploadSpeed = "0 KB/s"
        self.wasManuallyPaused = false
        self.audioOnly = false
        self.maxSpeed = 0
        self.lastProgressBeforeDisconnect = 0
        self.lastSpeedBeforeDisconnect = 0
        self.disconnectTime = nil
        self.isResuming = false
        self.customHeaders = nil
        self.isStreamingVideo = false
        self.pageTitle = ""
        self.videoType = "unknown"
        
        // Initialize Advanced Download Manager properties
        self.priority = .normal
        self.retryCount = 0
        self.errorMessage = nil
        self.startTime = nil
        self.endTime = nil
        self.currentSpeed = 0

    }
    
    func updateInstantSpeed(_ newSpeed: Double) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        // استخدم formatSpeedString من ViewModel
        self.downloadSpeed = self.formatSpeedMB(newSpeed)
        self.instantSpeed = newSpeed
        
        if newSpeed > self.maxSpeed {
            self.maxSpeed = newSpeed
        }
        
        // إجبار تحديث UI
        self.objectWillChange.send()
    }
}

// أضف هذه الدالة المساعدة بعد updateInstantSpeed
private func formatSpeedMB(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond <= 0 {
        return "0 KB/s"
    }
    
    let kbPerSecond = bytesPerSecond / 1024
    let mbPerSecond = kbPerSecond / 1024
    
    if mbPerSecond >= 1 {
        return String(format: "%.2f MB/s", mbPerSecond)
    } else {
        return String(format: "%.0f KB/s", kbPerSecond)
    }
}
    
    func getAverageSpeed() -> Double {
        return RealTimeSpeedTracker.shared.getAverageSpeed(for: self.id)
    }
    
    func updateProgress(_ newProgress: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.progress != newProgress {
                self.progress = newProgress
                
                // إجبار تحديث UI
                self.objectWillChange.send()
                
                // إرسال إشعارات تحديث
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: nil,
                    userInfo: ["downloadId": self.id]
                )
            }
        }
    }
    
    func updateSpeed(_ newSpeed: Double, displaySpeed: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // ✅ تحسين: تحديث السرعة دائماً لضمان تحديث UI
            let shouldUpdate = self.instantSpeed != newSpeed || 
                              self.downloadSpeed != displaySpeed || 
                              self.instantSpeed == 0 ||
                              self.downloadSpeed.contains("Connecting") ||
                              self.downloadSpeed.contains("Waiting") ||
                              self.downloadSpeed.contains("Starting")
            
            if shouldUpdate {
                self.instantSpeed = newSpeed
                self.downloadSpeed = displaySpeed
                
                if newSpeed > self.maxSpeed {
                    self.maxSpeed = newSpeed
                }
                
                // إجبار تحديث UI
                self.objectWillChange.send()
                
                // إرسال إشعارات تحديث
                NotificationCenter.default.post(
                    name: .downloadSpeedUpdated,
                    object: nil,
                    userInfo: ["downloadId": self.id]
                )
                
                print("🔄 Speed updated: \(displaySpeed) (instant: \(newSpeed))")
            }
        }
    }
}

extension DownloadItem {
    func getPreciseRemainingTime() -> String {
        let speedData = RealTimeSpeedTracker.shared.updateSpeed(
            for: self.id,
            currentBytes: self.downloadedSize,
            totalBytes: self.fileSize
        )
        return speedData.remainingTime
    }
    
    var preciseETA: String {
        getPreciseRemainingTime()
    }

}
