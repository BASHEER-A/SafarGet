import Foundation
import SwiftUI


extension DownloadManagerViewModel {
    
    // MARK: - Torrent Utilities
    
    /// Validates if a file is a valid torrent file
    func validateTorrentFile(at url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "torrent" else { return false }
        
        do {
            let data = try Data(contentsOf: url)
            // Basic validation: torrent files start with 'd' (dictionary)
            return data.first == 0x64 // ASCII 'd'
        } catch {
            print("❌ Failed to read torrent file: \(error)")
            return false
        }
    }
    
    /// Extracts basic torrent information without full parsing
    func extractBasicTorrentInfo(from url: URL) -> (name: String, size: String)? {
        guard validateTorrentFile(at: url) else { return nil }
        
        let fileName = url.deletingPathExtension().lastPathComponent
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return (name: fileName, size: formatFileSize(fileSize))
        } catch {
            return (name: fileName, size: "Unknown")
        }
    }
    
    /// Checks if aria2c supports torrent downloads
    func checkTorrentSupport() -> Bool {
        let process = Process()
        // استخدام aria2c من bundle أولاً
        if let bundledAria2Path = Bundle.main.path(forResource: "aria2c", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledAria2Path) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledAria2Path),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        process.executableURL = URL(fileURLWithPath: bundledAria2Path)
                    } else {
                        // نسخ إلى موقع قابل للكتابة
                        if let writablePath = copyToWritableLocation(bundledAria2Path, name: "aria2c") {
                            // تعيين متغيرات البيئة للمكتبات المدمجة
                            setupBundledEnvironment()
                            process.executableURL = URL(fileURLWithPath: writablePath)
                        } else {
                            process.executableURL = URL(fileURLWithPath: settings.aria2Path)
                        }
                    }
                } else {
                    // تعيين متغيرات البيئة للمكتبات المدمجة
                    setupBundledEnvironment()
                    process.executableURL = URL(fileURLWithPath: bundledAria2Path)
                }
            } else {
                process.executableURL = URL(fileURLWithPath: settings.aria2Path)
            }
        } else if let bundledAria2Path = Bundle.main.path(forResource: "aria2c", ofType: nil, inDirectory: "Scripts") {
            // البحث في Scripts داخل Resources (للتوافق مع الإعداد السابق)
            if FileManager.default.fileExists(atPath: bundledAria2Path) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledAria2Path),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        process.executableURL = URL(fileURLWithPath: bundledAria2Path)
                    } else {
                        // نسخ إلى موقع قابل للكتابة
                        if let writablePath = copyToWritableLocation(bundledAria2Path, name: "aria2c") {
                            // تعيين متغيرات البيئة للمكتبات المدمجة
                            setupBundledEnvironment()
                            process.executableURL = URL(fileURLWithPath: writablePath)
                        } else {
                            process.executableURL = URL(fileURLWithPath: settings.aria2Path)
                        }
                    }
                } else {
                    // تعيين متغيرات البيئة للمكتبات المدمجة
                    setupBundledEnvironment()
                    process.executableURL = URL(fileURLWithPath: bundledAria2Path)
                }
            } else {
                process.executableURL = URL(fileURLWithPath: settings.aria2Path)
            }
        } else {
            process.executableURL = URL(fileURLWithPath: settings.aria2Path)
        }
        process.arguments = ["--help"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("--bt-") || output.contains("torrent")
            }
        } catch {
            print("❌ Failed to check torrent support: \(error)")
        }
        
        return false
    }
    
    /// Gets optimal torrent download settings
    func getOptimalTorrentSettings() -> [String: String] {
        return [
            "bt-max-peers": "\(SpeedOptimizer.TorrentSpeedSettings.maxPeers)",
            "bt-request-peer-speed-limit": SpeedOptimizer.TorrentSpeedSettings.uploadLimit,
            "max-overall-upload-limit": SpeedOptimizer.TorrentSpeedSettings.uploadLimit,
            "seed-ratio": "0.0",
            "seed-time": "0",
            "bt-tracker-connect-timeout": "\(SpeedOptimizer.TorrentSpeedSettings.trackerTimeout)",
            "bt-tracker-timeout": "\(SpeedOptimizer.TorrentSpeedSettings.trackerTimeout * 4)",
            "enable-dht": "true",
            "bt-enable-lpd": "true",
            "enable-peer-exchange": "true",
            "max-connection-per-server": "\(SpeedOptimizer.TorrentSpeedSettings.maxConnections)",
            "split": "\(SpeedOptimizer.TorrentSpeedSettings.maxSplits)",
            "min-split-size": SpeedOptimizer.TorrentSpeedSettings.minSplitSize,
            "disk-cache": SpeedOptimizer.TorrentSpeedSettings.diskCache,
            "piece-length": SpeedOptimizer.TorrentSpeedSettings.pieceLength,
            "bt-prioritize-piece": "head=\(SpeedOptimizer.TorrentSpeedSettings.prioritizeHead),tail=\(SpeedOptimizer.TorrentSpeedSettings.prioritizeTail)",
            "max-concurrent-downloads": "\(SpeedOptimizer.TorrentSpeedSettings.maxConcurrentDownloads)",
            "retry-wait": "\(SpeedOptimizer.TorrentSpeedSettings.retryWait)",
            "timeout": "\(SpeedOptimizer.TorrentSpeedSettings.timeout)",
            "connect-timeout": "\(SpeedOptimizer.TorrentSpeedSettings.connectTimeout)"
        ]
    }
    
    /// Formats torrent-specific display information
    func formatTorrentInfo(peers: String?, seeds: String?, uploadSpeed: String?) -> String {
        var info: [String] = []
        
        if let peers = peers, !peers.isEmpty {
            info.append("Peers: \(peers)")
        }
        
        if let seeds = seeds, !seeds.isEmpty {
            info.append("Seeds: \(seeds)")
        }
        
        if let uploadSpeed = uploadSpeed, !uploadSpeed.isEmpty && uploadSpeed != "0 KB/s" {
            info.append("↑ \(uploadSpeed)")
        }
        
        return info.joined(separator: " • ")
    }
    
    /// Copies an executable to a writable location and sets permissions
    private func copyToWritableLocation(_ sourcePath: String, name: String) -> String? {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "SafarGet"
        let appSupportDir = appSupportURL?.appendingPathComponent(appName)
        
        if let supportDir = appSupportDir?.path {
            // إنشاء المجلد إذا لم يكن موجوداً
            if !fileManager.fileExists(atPath: supportDir) {
                do {
                    try fileManager.createDirectory(atPath: supportDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("❌ Failed to create support directory: \(error)")
                    return nil
                }
            }
            
            let writablePath = (supportDir as NSString).appendingPathComponent(name)
            
            // نسخ الملف إذا لم يكن موجوداً
            if !fileManager.fileExists(atPath: writablePath) {
                do {
                                    try fileManager.copyItem(atPath: sourcePath, toPath: writablePath)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                print("✅ Copied \(name) to writable location: \(writablePath)")
                // تعيين متغيرات البيئة للمكتبات المدمجة
                setupBundledEnvironment()
                return writablePath
                } catch {
                    print("❌ Failed to copy \(name) to writable location: \(error)")
                    return nil
                }
            } else {
                // الملف موجود بالفعل، تأكد من صلاحياته
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                // تعيين متغيرات البيئة للمكتبات المدمجة
                setupBundledEnvironment()
                return writablePath
            }
        }
        
        return nil
    }
    
    /// تعيين متغيرات البيئة للمكتبات المدمجة
    private func setupBundledEnvironment() {
        // تعيين DYLD_LIBRARY_PATH للمكتبات المدمجة
        if let libPath = Bundle.main.path(forResource: "lib", ofType: nil, inDirectory: "Resources") {
            let currentPath = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] ?? ""
            let newPath = currentPath.isEmpty ? libPath : "\(currentPath):\(libPath)"
            setenv("DYLD_LIBRARY_PATH", newPath, 1)
            print("🔧 Set DYLD_LIBRARY_PATH to: \(newPath)")
        }
        
        // تعيين DYLD_FALLBACK_LIBRARY_PATH للمكتبات المدمجة
        if let libPath = Bundle.main.path(forResource: "lib", ofType: nil, inDirectory: "Resources") {
            let currentPath = ProcessInfo.processInfo.environment["DYLD_FALLBACK_LIBRARY_PATH"] ?? ""
            let newPath = currentPath.isEmpty ? libPath : "\(currentPath):\(libPath)"
            setenv("DYLD_FALLBACK_LIBRARY_PATH", newPath, 1)
            print("🔧 Set DYLD_FALLBACK_LIBRARY_PATH to: \(newPath)")
        }
        
        // تعيين DYLD_FRAMEWORK_PATH للمكتبات المدمجة أيضاً
        if let libPath = Bundle.main.path(forResource: "lib", ofType: nil, inDirectory: "Resources") {
            let currentPath = ProcessInfo.processInfo.environment["DYLD_FRAMEWORK_PATH"] ?? ""
            let newPath = currentPath.isEmpty ? libPath : "\(currentPath):\(libPath)"
            setenv("DYLD_FRAMEWORK_PATH", newPath, 1)
            print("🔧 Set DYLD_FRAMEWORK_PATH to: \(newPath)")
        }
    }
    
    /// Calculates torrent health score based on peers and seeds
    func calculateTorrentHealth(peers: String?, seeds: String?) -> TorrentHealth {
        guard let peersStr = peers, let seedsStr = seeds else {
            return .unknown
        }
        
        // Extract numbers from strings like "5/10" or "5"
        let peerCount = extractFirstNumber(from: peersStr) ?? 0
        let seedCount = extractFirstNumber(from: seedsStr) ?? 0
        
        let totalSources = peerCount + seedCount
        
        if totalSources >= 50 {
            return .excellent
        } else if totalSources >= 20 {
            return .good
        } else if totalSources >= 5 {
            return .fair
        } else if totalSources > 0 {
            return .poor
        } else {
            return .dead
        }
    }
    
    enum TorrentHealth {
        case excellent, good, fair, poor, dead, unknown
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .dead: return .gray
            case .unknown: return .secondary
            }
        }
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .dead: return "Dead"
            case .unknown: return "Unknown"
            }
        }
    }
    
    /// Extracts the first number from a string
    private func extractFirstNumber(from string: String) -> Int? {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range, in: string) else {
            return nil
        }
        
        return Int(String(string[range]))
    }
    
    /// Validates torrent download path and creates necessary directories
    func prepareTorrentDownloadPath(for item: DownloadItem) -> Bool {
        let expandedPath = expandTildePath(item.savePath)
        
        // Create main download directory
        do {
            try FileManager.default.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("❌ Failed to create torrent download directory: \(error)")
            return false
        }
        
        // Create subdirectory for multi-file torrents if needed
        if item.fileName.contains("_") {
            let subPath = URL(fileURLWithPath: expandedPath).appendingPathComponent(item.fileName).path
            do {
                try FileManager.default.createDirectory(
                    atPath: subPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("❌ Failed to create torrent subdirectory: \(error)")
                return false
            }
        }
        
        return true
    }
    
    /// Cleans up torrent-specific temporary files
    func cleanupTorrentFiles(for item: DownloadItem) {
        let expandedPath = expandTildePath(item.savePath)
        let tempFiles = [
            "dht.dat",
            "\(item.fileName).torrent",
            "\(item.fileName).fastresume"
        ]
        
        for tempFile in tempFiles {
            let tempFilePath = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
            try? FileManager.default.removeItem(at: tempFilePath)
        }
    }
    
    struct TorrentStatistics {
        let downloadSpeed: Double
        let uploadSpeed: Double
        let peers: String
        let seeds: String
        let ratio: Double
        let health: TorrentHealth
    }
    
    /// Gets torrent statistics for a download item
    func getTorrentStatistics(for item: DownloadItem) -> TorrentStatistics {
        // Parse download speed
        let downloadSpeed = parseSpeedString(item.downloadSpeed) ?? 0.0
        
        // Parse upload speed
        let uploadSpeed = parseUploadSpeed(item.uploadSpeed)
        
        // Extract peers and seeds from item (you might need to add these properties to DownloadItem)
        // For now, we'll use placeholder values or try to extract from existing data
        let peers = extractPeersFromItem(item)
        let seeds = extractSeedsFromItem(item)
        
        // Calculate health
        let health = calculateTorrentHealth(peers: peers, seeds: seeds)
        
        // Calculate ratio (placeholder - you'll need actual downloaded/uploaded bytes)
        // Using fileSize instead of totalSize
        let downloadedBytes = Int64(item.fileSize)
        let ratio = calculateSeedRatio(downloaded: downloadedBytes, uploaded: Int64(uploadSpeed * 100)) // Rough estimate
        
        return TorrentStatistics(
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            peers: peers ?? "0",
            seeds: seeds ?? "0",
            ratio: ratio,
            health: health
        )
    }
    
    /// Extracts peers information from download item
    private func extractPeersFromItem(_ item: DownloadItem) -> String? {
        // This is a placeholder implementation
        // You might need to add peers property to DownloadItem or extract from status
        // Since additionalInfo doesn't exist, we'll return a default value
        // You can modify this to extract from other available properties
        return "0"
    }
    
    /// Extracts seeds information from download item
    private func extractSeedsFromItem(_ item: DownloadItem) -> String? {
        // This is a placeholder implementation
        // You might need to add seeds property to DownloadItem or extract from status
        // Since additionalInfo doesn't exist, we'll return a default value
        // You can modify this to extract from other available properties
        return "0"
    }
    
    /// Parses speed string to bytes per second
    private func parseSpeedString(_ speedString: String?) -> Double? {
        guard let speedString = speedString else { return nil }
        
        let pattern = #"(\d+(?:\.\d+)?)\s*([KMG]?B)/s"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: speedString, range: NSRange(speedString.startIndex..., in: speedString)),
              match.numberOfRanges >= 3 else {
            return nil
        }
        
        let valueRange = Range(match.range(at: 1), in: speedString)!
        let unitRange = Range(match.range(at: 2), in: speedString)!
        
        guard let value = Double(speedString[valueRange]) else { return nil }
        
        let unit = String(speedString[unitRange])
        return calculateBytesPerSecond(value, unit: unit)
    }
    
    /// Parses upload speed string to bytes per second
    private func parseUploadSpeed(_ speedString: String?) -> Double {
        guard let speedString = speedString else { return 0 }
        
        let pattern = #"(\d+(?:\.\d+)?)\s*([KMG]?B)/s"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: speedString, range: NSRange(speedString.startIndex..., in: speedString)),
              match.numberOfRanges >= 3 else {
            return 0
        }
        
        let valueRange = Range(match.range(at: 1), in: speedString)!
        let unitRange = Range(match.range(at: 2), in: speedString)!
        
        guard let value = Double(speedString[valueRange]) else { return 0 }
        
        let unit = String(speedString[unitRange])
        return calculateBytesPerSecond(value, unit: unit)
    }

    /// Converts a speed value + unit into bytes per second
    func calculateBytesPerSecond(_ value: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "b/s", "bps":
            return value
        case "kb/s", "kbps":
            return value * 1_000
        case "mb/s", "mbps":
            return value * 1_000_000
        case "gb/s", "gbps":
            return value * 1_000_000_000
        default:
            print("Unknown unit: \(unit), returning raw value")
            return value
        }
    }
    
    /// Calculates seed ratio
    private func calculateSeedRatio(downloaded: Int64, uploaded: Int64) -> Double {
        guard downloaded > 0 else { return 0 }
        return Double(uploaded) / Double(downloaded)
    }
    

    
    /// Formats torrent statistics for display
    func formatTorrentStatistics(for item: DownloadItem) -> String {
        let stats = getTorrentStatistics(for: item)
        
        var components: [String] = []
        
        if stats.downloadSpeed > 0 {
            components.append("↓ \(formatSpeedString(stats.downloadSpeed))")
        }
        
        if stats.uploadSpeed > 0 {
            components.append("↑ \(formatSpeedString(stats.uploadSpeed))")
        }
        
        if !stats.peers.isEmpty && stats.peers != "0" {
            components.append("P: \(stats.peers)")
        }
        
        if !stats.seeds.isEmpty && stats.seeds != "0" {
            components.append("S: \(stats.seeds)")
        }
        
        components.append("Health: \(stats.health.description)")
        
        return components.joined(separator: " • ")
    }
    
    /// Handles torrent-specific completion tasks
    func handleTorrentCompletion(for item: DownloadItem) {
        DispatchQueue.main.async {
            item.status = .completed
            item.progress = 1.0
            item.downloadSpeed = "Completed"
            item.uploadSpeed = "0 KB/s"
            item.remainingTime = "00:00"
            
            // Clean up torrent-specific files
            self.cleanupTorrentFiles(for: item)
            
            // Send notification
            self.notificationManager.sendDownloadCompleteNotification(for: item)
            
            // Save state
            self.saveDownloads()
            
            print("✅ Torrent download completed: \(item.fileName)")
        }
    }
    
    /// Handles torrent-specific failure tasks
    func handleTorrentFailure(for item: DownloadItem, error: Error? = nil) {
        DispatchQueue.main.async {
            item.status = .failed
            item.uploadSpeed = "0 KB/s"
            
            let errorMessage = error?.localizedDescription ?? "Torrent download failed"
            print("❌ Torrent download failed: \(item.fileName) - \(errorMessage)")
            
            // Send notification
            self.notificationManager.sendDownloadFailedNotification(
                for: item,
                reason: errorMessage
            )
            
            // Save state
            self.saveDownloads()
        }
    }
}
