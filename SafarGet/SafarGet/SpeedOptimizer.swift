import Foundation

// MARK: - Speed Optimizer for Maximum Download Performance
class SpeedOptimizer {
    static let shared = SpeedOptimizer()
    
    // MARK: - Torrent Speed Settings
    struct TorrentSpeedSettings {
        static let maxPeers = 1000                   // زيادة عدد الـ peers للسرعة القصوى
        static let maxConnections = 16               // الحد الأقصى المسموح لـ aria2c
        static let maxSplits = 128                   // زيادة عدد القطع للسرعة القصوى
        static let minSplitSize = "1M"              // الحد الأدنى المسموح لـ aria2c
        static let pieceLength = "8M"                // زيادة حجم القطعة للكفاءة
        static let diskCache = "512M"                // زيادة ذاكرة التخزين المؤقت
        static let uploadLimit = "500K"              // زيادة حد الرفع
        static let trackerTimeout = 2                // تقليل وقت الانتظار
        static let trackerInterval = 60              // تقليل الفاصل الزمني
        static let dhtPorts = "6881-6999,7000-7999,8000-8999"  // توسيع نطاق المنافذ
        static let prioritizeHead = "256M"           // زيادة الأولوية للبداية
        static let prioritizeTail = "256M"           // زيادة الأولوية للنهاية
        static let maxConcurrentDownloads = 20       // زيادة التحميلات المتزامنة
        static let retryWait = 1                     // تقليل وقت الانتظار بين المحاولات
        static let timeout = 5                       // تقليل timeout
        static let connectTimeout = 5                // تقليل وقت الاتصال
    }
    
    // MARK: - HTTP Speed Settings
    struct HTTPSpeedSettings {
        static let maxConnections = 16               // الحد الأقصى المسموح لـ aria2c
        static let maxSplits = 64                    // زيادة القطع
        static let minSplitSize = "1M"              // الحد الأدنى المسموح لـ aria2c
        static let diskCache = "256M"                // زيادة ذاكرة التخزين المؤقت
        static let timeout = 10                      // تقليل timeout
        static let connectTimeout = 10               // تقليل وقت الاتصال
        static let retryWait = 2                     // تقليل وقت الانتظار
        static let maxTries = 0
        static let maxConcurrentDownloads = 20       // زيادة التحميلات المتزامنة
        static let uploadLimit = "200K"              // زيادة حد الرفع
    }
    
    // MARK: - Video Speed Settings
    struct VideoSpeedSettings {
        static let concurrentFragments = 64          // زيادة القطع المتزامنة
        static let bufferSize = "256K"               // زيادة حجم الـ buffer
        static let httpChunkSize = "167772160"       // 160MB - زيادة حجم القطعة
        static let retries = 3                       // تقليل المحاولات للسرعة
        static let fragmentRetries = 3               // تقليل محاولات القطع
        static let aria2Connections = 16             // الحد الأقصى المسموح لـ aria2c
        static let aria2Splits = 64                  // زيادة قطع aria2
        static let aria2MinSplit = "1M"              // الحد الأدنى المسموح لـ aria2c
        static let aria2DiskCache = "256M"           // زيادة ذاكرة التخزين المؤقت
    }
    
    // MARK: - Get Optimized Torrent Arguments
    static func getOptimizedTorrentArguments(downloadPath: String, expandedPath: String) -> [String] {
        return [
            // === إعدادات التورنت المحسنة للسرعة القصوى ===
            "--bt-tracker-connect-timeout=\(TorrentSpeedSettings.trackerTimeout)",
            "--bt-tracker-timeout=\(TorrentSpeedSettings.trackerTimeout * 4)",
            "--bt-tracker-interval=\(TorrentSpeedSettings.trackerInterval)",
            "--dht-listen-port=\(TorrentSpeedSettings.dhtPorts)",
            "--enable-dht=true",
            "--bt-enable-lpd=true",
            "--enable-peer-exchange=true",
            "--dht-file-path=\(expandedPath)/dht.dat",
            
            // === إضافة المزيد من نقاط الدخول لـ DHT ===
            "--dht-entry-point=router.bittorrent.com:6881",
            "--dht-entry-point=dht.transmissionbt.com:6881",
            "--dht-entry-point=router.utorrent.com:6881",
            "--dht-entry-point=dht.aelitis.com:6881",
            "--dht-entry-point=dht.libtorrent.org:25401",
            "--dht-entry-point=router.bitcomet.com:6881",
            
            // === إعدادات التشفير المحسنة ===
            "--bt-require-crypto=false",
            "--bt-min-crypto-level=plain",
            "--bt-force-encryption=false",
            
            // === إعدادات الـ peers المحسنة ===
            "--bt-max-peers=\(TorrentSpeedSettings.maxPeers)",
            "--bt-request-peer-speed-limit=\(TorrentSpeedSettings.uploadLimit)",
            "--bt-max-open-files=200",
            "--bt-detach-seed-only=true",
            "--bt-lpd-interface=default",
            
            // === إعدادات الاتصال المتوازنة المحسنة ===
            "--max-connection-per-server=\(TorrentSpeedSettings.maxConnections)",
            "--split=\(TorrentSpeedSettings.maxSplits)",
            "--min-split-size=\(TorrentSpeedSettings.minSplitSize)",
            "--max-concurrent-downloads=\(TorrentSpeedSettings.maxConcurrentDownloads)",
            
            // === إعدادات السرعة القصوى ===
            "--max-overall-download-limit=0",
            "--max-download-limit=0",
            "--max-overall-upload-limit=\(TorrentSpeedSettings.uploadLimit)",
            "--max-upload-limit=\(TorrentSpeedSettings.uploadLimit)",
            
            // === إعدادات البذور المحسنة ===
            "--seed-ratio=0.0",
            "--seed-time=0",
            "--bt-seed-unverified=false",
            "--bt-save-metadata=true",
            "--bt-load-saved-metadata=true",
            
            // === إعدادات الذاكرة والقرص المحسنة ===
            "--disk-cache=\(TorrentSpeedSettings.diskCache)",
            "--file-allocation=falloc",
            "--no-file-allocation-limit=2M",
            "--enable-mmap=true",
            "--optimize-concurrent-downloads=true",
            "--conditional-get=true",
            "--remote-time=true",
            
            // === إعدادات الفحص المحسنة ===
            "--check-integrity=false",
            "--bt-hash-check-seed=false",
            "--bt-remove-unselected-file=true",
            "--bt-metadata-only=false",
            
            // === إعدادات الأولوية المحسنة ===
            "--bt-prioritize-piece=head=\(TorrentSpeedSettings.prioritizeHead),tail=\(TorrentSpeedSettings.prioritizeTail)",
            "--piece-length=\(TorrentSpeedSettings.pieceLength)",
            
            // === إعدادات الاستئناف المحسنة ===
            "--max-tries=0",
            "--retry-wait=\(TorrentSpeedSettings.retryWait)",
            "--timeout=\(TorrentSpeedSettings.timeout)",
            "--connect-timeout=\(TorrentSpeedSettings.connectTimeout)",
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
            "--realtime-chunk-checksum=true",
            "--show-files=false",
            "--enable-color=false",
            "-d", downloadPath
        ]
    }
    
    // MARK: - Get Optimized HTTP Arguments
    static func getOptimizedHTTPArguments(tempDownloadPath: String, tempFileName: String, resume: Bool) -> [String] {
        var arguments: [String] = [
            "-c",
            "--auto-file-renaming=false",
            "-x", "\(HTTPSpeedSettings.maxConnections)",
            "-s", "\(HTTPSpeedSettings.maxSplits)",
            "-k", HTTPSpeedSettings.minSplitSize,
            
            // مهم: استخدام مجلد مؤقت
            "-d", tempDownloadPath,
            "-o", tempFileName,
            
            // إعدادات التخصيص السريع
            "--file-allocation=falloc",
            "--no-file-allocation-limit=1M",
            "--allow-overwrite=true",
            "--check-certificate=false",
            "--console-log-level=info",
            "--summary-interval=1",
            "--show-console-readout=true",
            "--human-readable=true",
            "--download-result=full",
            
            // عدم إظهار الملفات
            "--show-files=false",
            "--enable-color=false",
            
            // فحص القطع المحسن
            "--check-integrity=false",
            "--realtime-chunk-checksum=true",
            
            // إعدادات الاتصال المتوازنة المحسنة
            "--timeout=\(HTTPSpeedSettings.timeout)",
            "--connect-timeout=\(HTTPSpeedSettings.connectTimeout)",
            "--max-tries=\(HTTPSpeedSettings.maxTries)",
            "--retry-wait=\(HTTPSpeedSettings.retryWait)",
            "--max-connection-per-server=\(HTTPSpeedSettings.maxConnections)",
            "--min-split-size=\(HTTPSpeedSettings.minSplitSize)",
            "--split=\(HTTPSpeedSettings.maxSplits)",
            
            // الاستئناف المحسن
            "--always-resume=true",
            "--max-resume-failure-tries=5",
            "--save-session-interval=1",
            "--force-save=true",
            
            // إعدادات الذاكرة والقرص المحسنة
            "--disk-cache=\(HTTPSpeedSettings.diskCache)",
            "--enable-mmap=true",
            "--optimize-concurrent-downloads=true",
            
            // إعدادات السرعة القصوى
            "--max-concurrent-downloads=\(HTTPSpeedSettings.maxConcurrentDownloads)",
            "--max-overall-download-limit=0",
            "--max-download-limit=0",
            "--max-overall-upload-limit=\(HTTPSpeedSettings.uploadLimit)",
            "--max-upload-limit=\(HTTPSpeedSettings.uploadLimit)",
            
            // إعدادات إضافية للسرعة
            "--conditional-get=true",
            "--remote-time=true"
        ]
        
        // إضافة معاملات خاصة بالاستئناف
        if resume {
            arguments.append(contentsOf: [
                "--continue=true",
                "--allow-piece-length-change=true",
                "--always-resume=true",
                "--max-resume-failure-tries=5",
                "--save-session-interval=1"
            ])
        }
        
        return arguments
    }
    
    // MARK: - Get Optimized Video Arguments
    static func getOptimizedVideoArguments(expandedPath: String, fileName: String) -> [String] {
        return [
            "-o", "\(expandedPath)/\(fileName)",
            "--no-warnings",
            "--no-check-certificate",
            "--concurrent-fragments", "\(VideoSpeedSettings.concurrentFragments)",
            "--retries", "\(VideoSpeedSettings.retries)",
            "--fragment-retries", "\(VideoSpeedSettings.fragmentRetries)",
            "--buffer-size", VideoSpeedSettings.bufferSize,
            "--http-chunk-size", VideoSpeedSettings.httpChunkSize,
            "--newline",
            "--progress",
            "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
            "--no-part",
            "--no-mtime",
            "--external-downloader", "aria2c",
            "--external-downloader-args", "aria2c:-x \(VideoSpeedSettings.aria2Connections) -s \(VideoSpeedSettings.aria2Splits) -k \(VideoSpeedSettings.aria2MinSplit) --max-connection-per-server=\(VideoSpeedSettings.aria2Connections) --min-split-size=\(VideoSpeedSettings.aria2MinSplit) --split=\(VideoSpeedSettings.aria2Splits) --max-concurrent-downloads=\(HTTPSpeedSettings.maxConcurrentDownloads) --max-overall-download-limit=0 --max-download-limit=0 --file-allocation=falloc --no-file-allocation-limit=1M --allow-overwrite=true --check-certificate=false --console-log-level=info --summary-interval=1 --show-console-readout=true --human-readable=true --download-result=full --show-files=false --enable-color=false --check-integrity=false --realtime-chunk-checksum=true --timeout=\(HTTPSpeedSettings.timeout) --connect-timeout=\(HTTPSpeedSettings.connectTimeout) --max-tries=\(HTTPSpeedSettings.maxTries) --retry-wait=\(HTTPSpeedSettings.retryWait) --always-resume=true --max-resume-failure-tries=5 --save-session-interval=1 --force-save=true --disk-cache=\(VideoSpeedSettings.aria2DiskCache) --enable-mmap=true --optimize-concurrent-downloads=true --conditional-get=true --remote-time=true"
        ]
    }
    
    // MARK: - Get Optimized Aria2 Arguments for External Downloader
    static func getOptimizedAria2Arguments() -> String {
        return "aria2c:-x \(HTTPSpeedSettings.maxConnections) -s \(HTTPSpeedSettings.maxSplits) -k \(HTTPSpeedSettings.minSplitSize) -c -m 0 --max-connection-per-server=\(HTTPSpeedSettings.maxConnections) --min-split-size=\(HTTPSpeedSettings.minSplitSize) --split=\(HTTPSpeedSettings.maxSplits) --max-concurrent-downloads=\(HTTPSpeedSettings.maxConcurrentDownloads) --continue=true --max-download-limit=0 --max-upload-limit=0 --file-allocation=falloc --no-file-allocation-limit=1M --allow-overwrite=true --check-certificate=false --timeout=\(HTTPSpeedSettings.timeout) --connect-timeout=\(HTTPSpeedSettings.connectTimeout) --max-tries=\(HTTPSpeedSettings.maxTries) --retry-wait=\(HTTPSpeedSettings.retryWait) --always-resume=true --max-resume-failure-tries=5 --save-session-interval=1 --force-save=true --disk-cache=\(HTTPSpeedSettings.diskCache) --enable-mmap=true --optimize-concurrent-downloads=true --conditional-get=true --remote-time=true"
    }
    
    // MARK: - Performance Monitoring
    static func getPerformanceMetrics() -> [String: Any] {
        return [
            "maxPeers": TorrentSpeedSettings.maxPeers,
            "maxConnections": HTTPSpeedSettings.maxConnections,
            "maxSplits": HTTPSpeedSettings.maxSplits,
            "diskCache": HTTPSpeedSettings.diskCache,
            "timeout": HTTPSpeedSettings.timeout,
            "concurrentDownloads": HTTPSpeedSettings.maxConcurrentDownloads,
            "concurrentFragments": VideoSpeedSettings.concurrentFragments,
            "bufferSize": VideoSpeedSettings.bufferSize,
            "httpChunkSize": VideoSpeedSettings.httpChunkSize
        ]
    }
    
    // MARK: - Speed Optimization Tips
    static func getOptimizationTips() -> [String] {
        return [
            "✅ زيادة عدد الاتصالات المتوازنة إلى 64",
            "✅ زيادة عدد القطع إلى 64 للسرعة القصوى",
            "✅ تعيين حجم القطعة الأدنى إلى 1M (متطلب aria2c)",
            "✅ زيادة ذاكرة التخزين المؤقت إلى 256MB",
            "✅ إلغاء فحص التكامل للسرعة القصوى",
            "✅ تقليل أوقات الانتظار والـ timeout إلى 3-10 ثوانٍ",
            "✅ تفعيل memory mapping للقرص",
            "✅ تحسين التحميلات المتزامنة إلى 12",
            "✅ استخدام GET الشرطي ووقت الخادم",
            "✅ زيادة عدد الأجزاء للفيديوهات إلى 32",
            "✅ زيادة حجم البفر للفيديوهات إلى 128K",
            "✅ زيادة حجم الـ chunks للفيديوهات إلى 80MB",
            "✅ زيادة عدد الـ peers للتورنت إلى 500",
            "✅ تحسين إعدادات DHT للتورنت",
            "✅ زيادة حجم القطع للتورنت إلى 4MB",
            "✅ تحسين إدارة الذاكرة للتحميلات السريعة"
        ]
    }
} 