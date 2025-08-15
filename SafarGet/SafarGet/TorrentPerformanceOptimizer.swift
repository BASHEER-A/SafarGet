import Foundation

// MARK: - Torrent Performance Optimizer
class TorrentPerformanceOptimizer {
    static let shared = TorrentPerformanceOptimizer()
    
    // MARK: - Performance Settings
    struct PerformanceSettings {
        // إعدادات الـ peers
        static let maxPeers = 1000
        static let maxPeersPerTracker = 100
        static let minPeersForFastStart = 5
        
        // إعدادات الاتصال
        static let maxConnections = 16  // الحد الأقصى المسموح لـ aria2c
        static let connectionTimeout = 2
        static let trackerTimeout = 3
        
        // إعدادات القطع
        static let pieceLength = "8M"
        static let minSplitSize = "1M"
        static let maxSplits = 128  // زيادة للسرعة القصوى
        
        // إعدادات الذاكرة
        static let diskCache = "512M"
        static let memoryCache = "256M"
        
        // إعدادات الأولوية
        static let prioritizeHead = "256M"
        static let prioritizeTail = "256M"
        static let prioritizeRarest = true
        
        // إعدادات الشبكة
        static let enableDHT = true
        static let enableLPD = true
        static let enablePEX = true
        static let dhtPorts = "6881-6999,7000-7999,8000-8999"
        
        // إعدادات التشفير
        static let requireCrypto = false
        static let minCryptoLevel = "plain"
        static let forceEncryption = false
    }
    
    // MARK: - Get Optimized Arguments
    static func getOptimizedArguments(downloadPath: String, expandedPath: String) -> [String] {
        return [
            // === إعدادات الـ peers المحسنة ===
            "--bt-max-peers=\(PerformanceSettings.maxPeers)",
            "--bt-request-peer-speed-limit=200K",
            "--bt-max-open-files=200",
            "--bt-detach-seed-only=true",
            
            // === إعدادات الاتصال المحسنة ===
            "--max-connection-per-server=\(PerformanceSettings.maxConnections)",
            "--split=\(PerformanceSettings.maxSplits)",
            "--min-split-size=\(PerformanceSettings.minSplitSize)",
            "--max-concurrent-downloads=12",
            "--timeout=\(PerformanceSettings.connectionTimeout)",
            "--connect-timeout=\(PerformanceSettings.connectionTimeout)",
            "--bt-tracker-connect-timeout=\(PerformanceSettings.trackerTimeout)",
            "--bt-tracker-timeout=\(PerformanceSettings.trackerTimeout * 4)",
            "--bt-tracker-interval=120",
            
            // === إعدادات الشبكة المحسنة ===
            "--dht-listen-port=\(PerformanceSettings.dhtPorts)",
            "--enable-dht=\(PerformanceSettings.enableDHT)",
            "--bt-enable-lpd=\(PerformanceSettings.enableLPD)",
            "--enable-peer-exchange=\(PerformanceSettings.enablePEX)",
            "--dht-file-path=\(expandedPath)/dht.dat",
            
            // === نقاط دخول DHT إضافية ===
            "--dht-entry-point=router.bittorrent.com:6881",
            "--dht-entry-point=dht.transmissionbt.com:6881",
            "--dht-entry-point=router.utorrent.com:6881",
            "--dht-entry-point=dht.aelitis.com:6881",
            "--dht-entry-point=dht.libtorrent.org:25401",
            "--dht-entry-point=router.bitcomet.com:6881",
            "--dht-entry-point=dht.anime.moe:6881",
            "--dht-entry-point=dht.archlinux.org:6881",
            
            // === إعدادات التشفير المحسنة ===
            "--bt-require-crypto=\(PerformanceSettings.requireCrypto)",
            "--bt-min-crypto-level=\(PerformanceSettings.minCryptoLevel)",
            "--bt-force-encryption=\(PerformanceSettings.forceEncryption)",
            
            // === إعدادات القطع المحسنة ===
            "--piece-length=\(PerformanceSettings.pieceLength)",
            "--bt-prioritize-piece=head=\(PerformanceSettings.prioritizeHead),tail=\(PerformanceSettings.prioritizeTail)",
            
            // === إعدادات الذاكرة المحسنة ===
            "--disk-cache=\(PerformanceSettings.diskCache)",
            "--file-allocation=falloc",
            "--no-file-allocation-limit=2M",
            
            // === إعدادات السرعة القصوى ===
            "--max-overall-download-limit=0",
            "--max-download-limit=0",
            "--max-overall-upload-limit=200K",
            "--max-upload-limit=200K",
            
            // === إعدادات البذور المحسنة ===
            "--seed-ratio=0.0",
            "--seed-time=0",
            "--bt-seed-unverified=false",
            "--bt-save-metadata=true",
            "--bt-load-saved-metadata=true",
            "--bt-metadata-only=false",
            
            // === إعدادات الفحص المحسنة ===
            "--check-integrity=false",
            "--bt-hash-check-seed=false",
            "--bt-remove-unselected-file=true",
            
            // === إعدادات الاستئناف المحسنة ===
            "--max-tries=0",
            "--retry-wait=2",
            "--always-resume=true",
            "--max-resume-failure-tries=15",
            "--save-session-interval=1",
            "--force-save=true",
            "--auto-save-interval=1",
            "-c",
            
            // === إعدادات أخرى محسنة ===
            "--auto-file-renaming=false",
            "--console-log-level=info",
            "--summary-interval=1",
            "--human-readable=true",
            "--show-console-readout=true",
            "--allow-overwrite=true",
            "--check-certificate=false",
            "--show-files=false",
            "--enable-color=false",
            "-d", downloadPath
        ]
    }
    
    // MARK: - Get Compatible Torrent Arguments
    static func getCompatibleTorrentArguments(downloadPath: String, expandedPath: String) -> [String] {
        return [
            // === إعدادات الـ peers الأساسية ===
            "--bt-max-peers=200",  // تقليل للتوافق
            "--bt-request-peer-speed-limit=100K",
            "--bt-max-open-files=100",
            "--bt-detach-seed-only=true",
            
            // === إعدادات الاتصال الأساسية ===
            "--max-connection-per-server=\(PerformanceSettings.maxConnections)",
            "--split=\(PerformanceSettings.maxSplits)",
            "--min-split-size=\(PerformanceSettings.minSplitSize)",
            "--max-concurrent-downloads=8",
            "--timeout=\(PerformanceSettings.connectionTimeout)",
            "--connect-timeout=\(PerformanceSettings.connectionTimeout)",
            "--bt-tracker-connect-timeout=\(PerformanceSettings.trackerTimeout)",
            "--bt-tracker-timeout=\(PerformanceSettings.trackerTimeout * 4)",
            "--bt-tracker-interval=120",
            
            // === إعدادات الشبكة الأساسية ===
            "--dht-listen-port=6881-6999",
            "--enable-dht=true",
            "--bt-enable-lpd=true",
            "--enable-peer-exchange=true",
            "--dht-file-path=\(expandedPath)/dht.dat",
            
            // === نقاط دخول DHT أساسية ===
            "--dht-entry-point=router.bittorrent.com:6881",
            "--dht-entry-point=dht.transmissionbt.com:6881",
            "--dht-entry-point=router.utorrent.com:6881",
            "--dht-entry-point=dht.aelitis.com:6881",
            
            // === إعدادات التشفير الأساسية ===
            "--bt-require-crypto=false",
            "--bt-min-crypto-level=plain",
            "--bt-force-encryption=false",
            
            // === إعدادات القطع الأساسية ===
            "--piece-length=2M",
            "--bt-prioritize-piece=head=64M,tail=64M",
            
            // === إعدادات الذاكرة الأساسية ===
            "--disk-cache=128M",  // تقليل للتوافق
            "--file-allocation=falloc",
            "--no-file-allocation-limit=1M",
            
            // === إعدادات السرعة الأساسية ===
            "--max-overall-download-limit=0",
            "--max-download-limit=0",
            "--max-overall-upload-limit=100K",
            "--max-upload-limit=100K",
            
            // === إعدادات البذور الأساسية ===
            "--seed-ratio=0.0",
            "--seed-time=0",
            "--bt-seed-unverified=false",
            "--bt-save-metadata=true",
            "--bt-load-saved-metadata=true",
            "--bt-metadata-only=false",
            
            // === إعدادات الفحص الأساسية ===
            "--check-integrity=false",
            "--bt-hash-check-seed=false",
            "--bt-remove-unselected-file=true",
            
            // === إعدادات الاستئناف الأساسية ===
            "--max-tries=0",
            "--retry-wait=2",
            "--always-resume=true",
            "--max-resume-failure-tries=15",
            "--save-session-interval=1",
            "--force-save=true",
            "--auto-save-interval=1",
            "-c",
            
            // === إعدادات أخرى أساسية ===
            "--auto-file-renaming=false",
            "--console-log-level=info",
            "--summary-interval=1",
            "--human-readable=true",
            "--show-console-readout=true",
            "--allow-overwrite=true",
            "--check-certificate=false",
            "--show-files=false",
            "--enable-color=false",
            "-d", downloadPath
        ]
    }
    
    // MARK: - Performance Monitoring
    func monitorTorrentPerformance(for item: DownloadItem) -> TorrentPerformanceMetrics {
        let currentSpeed = parseSpeedString(item.downloadSpeed) ?? 0.0
        let peers = extractPeersFromItem(item) ?? "0"
        let seeds = extractSeedsFromItem(item) ?? "0"
        
        let peerCount = extractFirstNumber(from: peers) ?? 0
        let seedCount = extractFirstNumber(from: seeds) ?? 0
        
        let health = calculateHealth(peers: peerCount, seeds: seedCount)
        let efficiency = calculateEfficiency(speed: currentSpeed, peers: peerCount, seeds: seedCount)
        
        return TorrentPerformanceMetrics(
            downloadSpeed: currentSpeed,
            peers: peerCount,
            seeds: seedCount,
            health: health,
            efficiency: efficiency,
            recommendations: generateRecommendations(metrics: TorrentPerformanceMetrics(
                downloadSpeed: currentSpeed,
                peers: peerCount,
                seeds: seedCount,
                health: health,
                efficiency: efficiency,
                recommendations: []
            ))
        )
    }
    
    // MARK: - Performance Metrics
    struct TorrentPerformanceMetrics {
        let downloadSpeed: Double
        let peers: Int
        let seeds: Int
        let health: TorrentHealth
        let efficiency: Double
        let recommendations: [String]
    }
    
    enum TorrentHealth {
        case excellent, good, fair, poor, dead
        
        var description: String {
            switch self {
            case .excellent: return "ممتاز"
            case .good: return "جيد"
            case .fair: return "متوسط"
            case .poor: return "ضعيف"
            case .dead: return "ميت"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            case .dead: return "gray"
            }
        }
    }
    
    // MARK: - Helper Functions
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
    
    private func calculateBytesPerSecond(_ value: Double, unit: String) -> Double {
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
            return value
        }
    }
    
    private func extractPeersFromItem(_ item: DownloadItem) -> String? {
        // Placeholder implementation
        return "0"
    }
    
    private func extractSeedsFromItem(_ item: DownloadItem) -> String? {
        // Placeholder implementation
        return "0"
    }
    
    private func extractFirstNumber(from string: String) -> Int? {
        let pattern = #"\d+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range, in: string) else {
            return nil
        }
        
        return Int(String(string[range]))
    }
    
    private func calculateHealth(peers: Int, seeds: Int) -> TorrentHealth {
        let totalSources = peers + seeds
        
        if totalSources >= 100 {
            return .excellent
        } else if totalSources >= 50 {
            return .good
        } else if totalSources >= 20 {
            return .fair
        } else if totalSources >= 5 {
            return .poor
        } else {
            return .dead
        }
    }
    
    private func calculateEfficiency(speed: Double, peers: Int, seeds: Int) -> Double {
        let totalSources = peers + seeds
        guard totalSources > 0 else { return 0.0 }
        
        // Calculate efficiency based on speed and available sources
        let speedEfficiency = min(speed / (1024 * 1024), 10.0) / 10.0 // Normalize to 0-1
        let sourceEfficiency = min(Double(totalSources) / 100.0, 1.0)
        
        return (speedEfficiency + sourceEfficiency) / 2.0
    }
    
    private func generateRecommendations(metrics: TorrentPerformanceMetrics) -> [String] {
        var recommendations: [String] = []
        
        if metrics.health == .dead {
            recommendations.append("🔴 التورنت ميت - جرب تورنت آخر")
        } else if metrics.health == .poor {
            recommendations.append("🟠 عدد المصادر قليل - انتظر المزيد من البذور")
        }
        
        if metrics.downloadSpeed < 1024 * 1024 { // < 1MB/s
            recommendations.append("🐌 السرعة بطيئة - تحقق من إعدادات الشبكة")
        }
        
        if metrics.peers < 10 {
            recommendations.append("👥 عدد الـ peers قليل - انتظر المزيد من الاتصالات")
        }
        
        if metrics.seeds < 5 {
            recommendations.append("🌱 عدد البذور قليل - قد تكون السرعة محدودة")
        }
        
        if recommendations.isEmpty {
            recommendations.append("✅ الأداء جيد - استمر في التحميل")
        }
        
        return recommendations
    }
} 