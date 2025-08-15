import Foundation
import SwiftUI
import Darwin
import ObjectiveC

// MARK: - Smart User-Agents Collection
struct SmartUserAgents {
    // قائمة ضخمة من User-Agents لمحاكاة كل الأجهزة الممكنة
    static let userAgents = [
        // macOS
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0 Safari/537.36",
        
        // Windows
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:117.0) Gecko/20100101 Firefox/117.0",
        "Mozilla/5.0 (Windows NT 11.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/117.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0 Safari/537.36",
        
        // Linux
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36",
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:117.0) Gecko/20100101 Firefox/117.0",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0 Safari/537.36",
        
        // Android
        "Mozilla/5.0 (Linux; Android 15; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 14; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 12; Pixel 6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0 Mobile Safari/537.36",
        
        // iOS
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        
        // TV
        "Mozilla/5.0 (Linux; Android 10; TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0 Safari/537.36",
        "Mozilla/5.0 (SmartTV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/15.0 TV Safari/537.36",
        "Mozilla/5.0 (Linux; Android 11; BRAVIA 4K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0 Safari/537.36",
        "Mozilla/5.0 (Linux; Android 9; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0 Safari/537.36"
    ]
    
    // الحصول على User-Agent عشوائي
    static func getRandomUserAgent() -> String {
        return userAgents.randomElement() ?? userAgents[0]
    }
    
    // الحصول على User-Agent محدد حسب النظام
    static func getUserAgentForSystem() -> String {
        #if os(macOS)
        return userAgents.filter { $0.contains("Macintosh") }.randomElement() ?? userAgents[0]
        #elseif os(iOS)
        return userAgents.filter { $0.contains("iPhone") || $0.contains("iPad") }.randomElement() ?? userAgents[0]
        #else
        return getRandomUserAgent()
        #endif
    }
}

// MARK: - Smart Format Selection
struct SmartFormatSelector {
    // دالة ذكية لاختيار الصيغة المناسبة
    static func selectOptimalFormat(for quality: String, audioOnly: Bool = false) -> String {
        let qualityLower = quality.lowercased()
        
        if audioOnly {
            // للصوت فقط، نفضل m4a ثم mp3
            return "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio"
        }
        
        // للفيديو، نستخدم نفس المنطق المحسن مع تفضيل mp4
        func fmt(_ h: Int) -> String {
            return "bestvideo[height<=\(h)][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]"
        }
        
        switch qualityLower {
        case "4k", "2160p", "uhd":
            return fmt(2160)
        case "1440p", "2k":
            return fmt(1440)
        case "1080p", "full hd", "fhd":
            return fmt(1080)
        case "720p", "hd":
            return fmt(720)
        case "480p":
            return fmt(480)
        case "360p":
            return fmt(360)
        case "240p":
            return fmt(240)
        case "144p":
            return fmt(144)
        case "best", "أفضل جودة", "meilleure qualité":
            return "bestvideo+bestaudio/best"
        case "worst", "أسوأ جودة", "pire qualité":
            return "worst"
        default:
            // إذا كانت الجودة مسبقاً بصيغة yt-dlp، أعدها كما هي
            return quality
        }
    }
    
    // دالة ذكية لاختيار الصيغة مع fallback
    static func selectFormatWithFallback(for quality: String, audioOnly: Bool = false) -> [String] {
        let primaryFormat = selectOptimalFormat(for: quality, audioOnly: audioOnly)
        
        if audioOnly {
            return [
                primaryFormat,
                "bestaudio[ext=mp3]/bestaudio",
                "bestaudio"
            ]
        } else {
            return [
                primaryFormat,
                "bestvideo+bestaudio/best",
                "best[ext=mp4]/best"
            ]
        }
    }
}

// MARK: - YouTube Error Types
enum YouTubeError: Error, LocalizedError {
    case ytDlpNotFound
    case aria2cNotFound
    case ffmpegNotFound
    case noURLsFound
    case invalidOutput
    case fileNotFound
    case noFilesToMerge
    case mergeFailed
    case ytDlpError(String)
    case aria2cError(String)
    case ffmpegError(String)
    case urlExpired
    case downloadCancelled
    
    var errorDescription: String? {
        switch self {
        case .ytDlpNotFound:
            return "yt-dlp not found"
        case .aria2cNotFound:
            return "aria2c not found"
        case .ffmpegNotFound:
            return "ffmpeg not found"
        case .noURLsFound:
            return "No URLs found"
        case .invalidOutput:
            return "Invalid output from yt-dlp"
        case .fileNotFound:
            return "Downloaded file not found"
        case .noFilesToMerge:
            return "No files to merge"
        case .mergeFailed:
            return "File merge failed"
        case .ytDlpError(let message):
            return "yt-dlp error: \(message)"
        case .aria2cError(let message):
            return "aria2c error: \(message)"
        case .ffmpegError(let message):
            return "ffmpeg error: \(message)"
        case .urlExpired:
            return "URL expired, need to get new URLs"
        case .downloadCancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - YouTube Data Structures
struct YouTubeURLs {
    let videoURL: String
    let audioURL: String
}

struct YouTubeFilePaths {
    let video: String
    let audio: String
}



// MARK: - YouTube Downloader Extension (Enhanced)
extension DownloadManagerViewModel {
    
    // MARK: - Quality Translation Function (Enhanced)
    private func translateQualityToYtDlpFormat(_ quality: String) -> String {
        return SmartFormatSelector.selectOptimalFormat(for: quality, audioOnly: false)
    }
    
    // استخراج دقة مستهدفة من نص (مثل "720p" أو "height=720"). يعيد nil إذا لم توجد
    private func extractTargetHeight(from text: String?) -> Int? {
        guard let text = text, !text.isEmpty else { return nil }
        // ابحث عن 3-4 أرقام متبوعة بحرف p
        if let match = text.range(of: "(\\d{3,4})p", options: .regularExpression) {
            let numStr = String(text[match]).replacingOccurrences(of: "p", with: "")
            if let val = Int(numStr) { return val }
        }
        // ابحث عن height=NUM
        if let range = text.range(of: "height=\\d+", options: .regularExpression) {
            let part = String(text[range]).replacingOccurrences(of: "height=", with: "")
            if let val = Int(part) { return val }
        }
        return nil
    }
    
    // MARK: - Smart YouTube Download with Multiple User-Agents
    func startSmartYouTubeDownload(for item: DownloadItem) {
        print("🚀 Starting SMART YouTube download for: \(item.fileName)")
        
        // تحديث الحالة فوراً
        DispatchQueue.main.async {
            item.status = .downloading
            item.downloadSpeed = "Starting smart download..."
            self.objectWillChange.send()
        }
        
        // بدء التحميل فوراً
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            
            // البحث السريع عن yt-dlp
            let ytDlpPath = self.findYtDlpPathOptimized()
            
            // التحقق من yt-dlp فوراً
            guard FileManager.default.fileExists(atPath: ytDlpPath) else {
                print("❌ yt-dlp not found at: \(ytDlpPath)")
                DispatchQueue.main.async {
                    item.status = .failed
                    item.downloadSpeed = "yt-dlp not found"
                    self.objectWillChange.send()
                }
                return
            }
            
            // تحديث الحالة إلى "Connecting"
            DispatchQueue.main.async {
                item.downloadSpeed = "Connecting with smart detection..."
                self.objectWillChange.send()
            }
            
            // إنشاء المجلد بشكل متوازي
            let expandedPath = self.expandTildePath(item.savePath)
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("⚠️ Failed to create directory: \(error) - continuing anyway")
                }
            }
            
            // إعداد اسم الملف
            let fileNameWithoutExt = (item.fileName as NSString).deletingPathExtension
            let fileExtension = item.audioOnly ? "mp3" : "mp4"
            let finalFileName = "\(fileNameWithoutExt).\(fileExtension)"
            
            // إنشاء مجلد مؤقت للتحميل
            let tempDir = NSTemporaryDirectory()
            let tempDownloadDir = "\(tempDir)SafarGet_Smart_Downloads"
            
            do {
                try FileManager.default.createDirectory(atPath: tempDownloadDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("⚠️ Failed to create temp directory: \(error)")
            }
            
            // مسار التحميل المؤقت
            let tempOutputPath = "\(tempDownloadDir)/\(finalFileName)"
            
            // مسار الملف النهائي
            let finalOutputPath = "\(expandedPath)/\(finalFileName)"
            
            // الحصول على صيغ التحميل الذكية
            let formats = SmartFormatSelector.selectFormatWithFallback(for: item.videoFormat.isEmpty ? "best" : item.videoFormat, audioOnly: item.audioOnly)
            
            // محاولة التحميل مع كل User-Agent وكل صيغة
            self.tryDownloadWithMultipleUserAgents(
                ytDlpPath: ytDlpPath,
                formats: formats,
                tempOutputPath: tempOutputPath,
                finalOutputPath: finalOutputPath,
                item: item
            )
        }
    }
    
    // MARK: - Try Download with Multiple User-Agents
    private func tryDownloadWithMultipleUserAgents(
        ytDlpPath: String,
        formats: [String],
        tempOutputPath: String,
        finalOutputPath: String,
        item: DownloadItem
    ) {
        let userAgents = SmartUserAgents.userAgents
        
        // محاولة كل صيغة مع كل User-Agent
        for (formatIndex, format) in formats.enumerated() {
            print("🎬 Trying format \(formatIndex + 1)/\(formats.count): \(format)")
            
            for (uaIndex, userAgent) in userAgents.enumerated() {
                print("🌐 Trying User-Agent \(uaIndex + 1)/\(userAgents.count): \(userAgent.prefix(60))...")
                
                // تحديث الحالة
                DispatchQueue.main.async {
                    item.downloadSpeed = "Trying format \(formatIndex + 1)/\(formats.count) with UA \(uaIndex + 1)/\(userAgents.count)..."
                    self.objectWillChange.send()
                }
                
                // إعداد arguments للتحميل الذكي
                var arguments = self.buildSmartDownloadArguments(
                    format: format,
                    userAgent: userAgent,
                    tempOutputPath: tempOutputPath,
                    item: item
                )
                
                arguments.append(item.url)
                
                print("🚀 Smart download command:")
                print("🚀 yt-dlp \(arguments.joined(separator: " "))")
                
                // إنشاء العملية
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ytDlpPath)
                process.arguments = arguments
                
                // إعداد pipes
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // قراءة التقدم
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8) {
                        self?.parseYouTubeProgressLineEnhanced(output, for: item)
                    }
                }
                
                // قراءة الأخطاء
                errorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("❌ yt-dlp error output: \(errorOutput)")
                    }
                }
                
                do {
                    try process.run()
                    
                    DispatchQueue.main.async {
                        item.processTask = process
                        item.status = .downloading
                        self.objectWillChange.send()
                    }
                    
                    process.waitUntilExit()
                    
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            // نجح التحميل!
                            print("✅ Smart download succeeded with format: \(format) and UA: \(userAgent.prefix(60))...")
                            self.moveCompletedFile(from: tempOutputPath, to: finalOutputPath, for: item)
                            
                            // تنظيف تلقائي بعد نجاح التحميل
                            DispatchQueue.global(qos: .background).async {
                                ProcessCleanupManager.shared.performYouTubeDownloadCleanup()
                            }
                            return
                        } else if process.terminationStatus == 15 || process.terminationStatus == 9 {
                            // SIGTERM (15) أو SIGKILL (9) - تم إيقاف التحميل مؤقتاً
                            if item.status == .paused {
                                print("⏸️ Smart download paused: \(item.fileName)")
                            } else {
                                item.status = .failed
                                item.downloadSpeed = "Failed (exit code: \(process.terminationStatus))"
                                print("❌ Smart download failed: \(item.fileName) (exit code: \(process.terminationStatus))")
                                self.cleanupPartialFiles(for: item)
                                
                                // تنظيف تلقائي بعد فشل التحميل
                                DispatchQueue.global(qos: .background).async {
                                    ProcessCleanupManager.shared.performYouTubeDownloadCleanup()
                                }
                            }
                            return
                        } else {
                            // فشل هذا المحاولة، جرب التالية
                            print("❌ Failed with format: \(format) and UA: \(userAgent.prefix(60))... (exit code: \(process.terminationStatus))")
                        }
                    }
                    
                    // إذا نجح التحميل، اخرج من الحلقة
                    if process.terminationStatus == 0 {
                        return
                    }
                } catch {
                    print("❌ Failed to start smart download: \(error)")
                }
            }
        }
        
        // إذا وصلنا هنا، فشلت جميع المحاولات
        DispatchQueue.main.async {
            item.status = .failed
            item.downloadSpeed = "All download methods failed"
            print("❌ All smart download methods failed for: \(item.fileName)")
            self.cleanupPartialFiles(for: item)
            self.saveDownloads()
        }
    }
    
    // MARK: - Build Smart Download Arguments
    private func buildSmartDownloadArguments(
        format: String,
        userAgent: String,
        tempOutputPath: String,
        item: DownloadItem
    ) -> [String] {
        var arguments: [String] = []
        
        // إضافة User-Agent
        arguments.append(contentsOf: ["--user-agent", userAgent])
        
        // إضافة cookies من Chrome browser
        arguments.append(contentsOf: ["--cookies-from-browser", "chrome"])
        
        // إضافة headers مخصصة إذا كانت موجودة
        if let headers = item.customHeaders {
            let importantHeaders = ["User-Agent", "Referer", "Origin"]
            for (key, value) in headers {
                if importantHeaders.contains(key) {
                    arguments.append("--add-header")
                    arguments.append("\(key):\(value)")
                }
            }
        }
        
        // إعدادات التحميل الذكية
        if item.audioOnly {
            // تحميل الصوت فقط
            arguments.append(contentsOf: [
                "-f", format,
                "--no-warnings",
                "--no-check-certificate",
                "--ignore-errors",
                "--no-playlist",
                "--quiet",
                "--no-colors",
                "--newline",
                "--progress",
                "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
                "--no-mtime",
                "--no-continue",
                "--no-part",
                "--sleep-interval", "0",
                "--max-sleep-interval", "0",
                "--retries", "1",
                "--fragment-retries", "1",
                "--concurrent-fragments", "64",
                "--buffer-size", "128K",
                "--no-cache-dir"
            ])
        } else {
            // تحميل الفيديو مع الصوت
            arguments.append(contentsOf: [
                "-f", format,
                "--merge-output-format", "mp4",
                "--no-warnings",
                "--no-check-certificate",
                "--ignore-errors",
                "--no-playlist",
                "--quiet",
                "--no-colors",
                "--newline",
                "--progress",
                "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
                "--no-mtime",
                "--no-continue",
                "--no-part",
                "--sleep-interval", "0",
                "--max-sleep-interval", "0",
                "--retries", "1",
                "--fragment-retries", "1",
                "--concurrent-fragments", "64",
                "--buffer-size", "128K",
                "--no-cache-dir"
            ])
        }
        
        // إضافة ffmpeg path للدمج
        if let ffmpegPath = self.findFfmpegPath() {
            arguments.append(contentsOf: ["--ffmpeg-location", ffmpegPath])
        }
        
        // إضافة ملفات الكوكيز إذا كانت موجودة
        if let cookiesPath = item.cookiesPath, !cookiesPath.isEmpty {
            arguments.append(contentsOf: ["--cookies", cookiesPath])
        }
        
        // إضافة selector للدقة المطلوبة
        if let target = self.extractTargetHeight(from: item.videoQuality.isEmpty ? item.fileName : item.videoQuality) {
            arguments.append(contentsOf: ["-S", "res:\(target),ext:mp4"])
        }
        
        // إضافة مسار الإخراج
        arguments.append(contentsOf: ["-o", tempOutputPath])
        
        return arguments
    }
    
    // MARK: - Smart Format Listing
    func listSmartFormats(for url: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔍 Listing smart formats for: \(url)")
        
        let ytDlpPath = self.findYtDlpPathOptimized()
        guard FileManager.default.fileExists(atPath: ytDlpPath) else {
            completion(.failure(YouTubeError.ytDlpNotFound))
            return
        }
        
        // محاولة مع كل User-Agent
        for (index, userAgent) in SmartUserAgents.userAgents.enumerated() {
            print("🌐 Trying User-Agent \(index + 1)/\(SmartUserAgents.userAgents.count): \(userAgent.prefix(60))...")
            
            let arguments = [
                "-F",
                "--user-agent", userAgent,
                "--cookies-from-browser", "chrome",
                "--no-warnings",
                "--no-check-certificate",
                "--ignore-errors",
                "--quiet",
                "--no-colors",
                url
            ]
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: outputData, encoding: .utf8) {
                        print("✅ Format listing succeeded with UA: \(userAgent.prefix(60))...")
                        completion(.success(output))
                        return
                    }
                }
            } catch {
                print("❌ Failed to list formats with UA: \(userAgent.prefix(60))...")
                continue
            }
        }
        
        // إذا فشلت جميع المحاولات
        completion(.failure(YouTubeError.ytDlpError("All User-Agents failed to list formats")))
    }
    
    // MARK: - YouTube Download with Headers
    func startYouTubeDownloadWithHeaders(for item: DownloadItem) {
        print("🚀 Starting ultra-fast YouTube download with headers: \(item.fileName)")
        
        // تحديث الحالة فوراً
        DispatchQueue.main.async {
            item.status = .downloading
            item.downloadSpeed = "Starting..."
            self.objectWillChange.send()
        }
        
        // بدء التحميل فوراً مع أولوية عالية
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            
            // وضع حارس نشاط لمنع Cleanup أثناء التنزيل
            ProcessCleanupManager.shared.beginYouTubeOperation()
            defer { ProcessCleanupManager.shared.endYouTubeOperation() }

            // التحضير السريع - التحقق من yt-dlp أولاً (الأهم)
            let ytDlpPath = self.findYtDlpPathOptimized()
            
            // التحقق من yt-dlp فوراً (الأهم)
            guard FileManager.default.fileExists(atPath: ytDlpPath) else {
                print("❌ yt-dlp not found at: \(ytDlpPath)")
                DispatchQueue.main.async {
                    item.status = .failed
                    item.downloadSpeed = "yt-dlp not found"
                    self.objectWillChange.send()
                }
                return
            }
            
            // تحديث الحالة إلى "Connecting" قبل بدء العملية
            DispatchQueue.main.async {
                item.downloadSpeed = "Connecting..."
                self.objectWillChange.send()
            }
            
            // بناء arguments بشكل محسن للسرعة
            var arguments = [String]()
            
            // إضافة headers مخصصة بشكل محسن - الأهم أولاً
            if let headers = item.customHeaders {
                // إضافة cookies من Chrome browser أولاً (الأهم)
                arguments.append(contentsOf: ["--cookies-from-browser", "chrome"])
                
                // إضافة headers المهمة فقط لتسريع العملية
                let importantHeaders = ["User-Agent", "Referer", "Origin"]
                for (key, value) in headers {
                    if importantHeaders.contains(key) {
                        arguments.append("--add-header")
                        arguments.append("\(key):\(value)")
                    }
                }
            }
            
            // إعدادات YouTube محسنة للسرعة - تقليل التأخير
            print("🔍 Debug: item.videoFormat = '\(item.videoFormat)'")
            print("🔍 Debug: item.videoQuality = '\(item.videoQuality)'")
            let selectedQuality = item.videoFormat.isEmpty ? "best[ext=mp4]/best" : SmartFormatSelector.selectOptimalFormat(for: item.videoFormat, audioOnly: item.audioOnly)
            print("🎬 Using selected quality with headers: \(selectedQuality)")
            
            arguments.append(contentsOf: [
                "-f", selectedQuality,
                "--merge-output-format", "mp4",
                "--no-warnings",
                "--no-check-certificate",
                "--ignore-errors",
                "--no-playlist",
                "--no-mtime",
                "--no-continue",
                "--no-part",
                "--sleep-interval", "0",
                "--max-sleep-interval", "0",
                "--retries", "1",
                "--fragment-retries", "1",
                "--concurrent-fragments", "64", // زيادة من 8 إلى 64 للسرعة القصوى
                "--buffer-size", "128K", // زيادة من 64K إلى 128K
                "--newline",
                "--progress",
                "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
                "--no-cache-dir", // إضافة: عدم استخدام cache
                "--quiet" // إضافة: quiet mode
            ])
            
            // إضافة ffmpeg path للدمج من bundle (إذا كان متوفراً)
            if let ffmpegPath = self.findFfmpegPath() {
                arguments.append(contentsOf: ["--ffmpeg-location", ffmpegPath])
                print("✅ Using bundled ffmpeg for merging: \(ffmpegPath)")
            } else {
                print("⚠️ ffmpeg not found in bundle, using system ffmpeg if available")
            }
            
            // استخدام اسم الملف المحدد
            let fileNameWithoutExt = (item.fileName as NSString).deletingPathExtension
            let fileExtension = item.audioOnly ? "mp3" : "mp4"
            let finalFileName = "\(fileNameWithoutExt).\(fileExtension)"
            
            // إنشاء مجلد مؤقت للتحميل
            let tempDir = NSTemporaryDirectory()
            let tempDownloadDir = "\(tempDir)SafarGet_Downloads"
            
            // إنشاء المجلد المؤقت
            do {
                try FileManager.default.createDirectory(atPath: tempDownloadDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("⚠️ Failed to create temp directory: \(error)")
            }
            
            // مسار التحميل المؤقت
            let tempOutputPath = "\(tempDownloadDir)/\(finalFileName)"
            
            // مسار الملف النهائي في المجلد المختار
            let expandedPath = self.expandTildePath(item.savePath)
            let finalOutputPath = "\(expandedPath)/\(finalFileName)"
            
            // التحقق من وجود الملف النهائي وحذفه إذا كان موجوداً عند الاستئناف
            if item.wasManuallyPaused && FileManager.default.fileExists(atPath: finalOutputPath) {
                do {
                    try FileManager.default.removeItem(atPath: finalOutputPath)
                    print("🗑️ Removed existing file for resume: \(finalOutputPath)")
                } catch {
                    print("⚠️ Failed to remove existing file: \(error)")
                }
            }
            
            // إنشاء المجلد النهائي بشكل متوازي
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("⚠️ Failed to create final directory: \(error) - continuing anyway")
                }
            }
            
            arguments.append("-o")
            arguments.append(tempOutputPath)

            // في حال صيغة المستخدم مثل "136+140/298+140/22/..." غير متاحة، فعّل تفضيل الدقة المطلوبة عبر -S res:VAL
            if let target = self.extractTargetHeight(from: item.videoQuality.isEmpty ? item.fileName : item.videoQuality) {
                arguments.append(contentsOf: ["-S", "res:\(target),ext:mp4"])
                print("🛟 Applied selector: -S res:\(target),ext:mp4")
            }
            
            // إضافة URL
            arguments.append(item.url)
            
            // إنشاء العملية مع التشغيل الصحيح
            let process = createYtDlpProcess(ytDlpPath: ytDlpPath, arguments: arguments)
            
            print("🎬 Starting YouTube download: \(item.fileName)")
            
            // معالجة output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            var stderrBuffer = Data()
            
            // قراءة التقدم
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    self?.parseYouTubeProgressLineEnhanced(output, for: item)
                }
            }
            
            // قراءة الأخطاء
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("❌ yt-dlp error output: \(errorOutput)")
                }
                if !data.isEmpty { stderrBuffer.append(data) }
            }
            
            do {
                try process.run()
                
                DispatchQueue.main.async {
                    item.processTask = process
                    item.status = .downloading
                    self.objectWillChange.send()
                }
                
                process.waitUntilExit()
                
                // تأكد من تحرير معالجات القراءة لمنع أي حلقات CPU بعد انتهاء العملية
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        // نقل الملف من المجلد المؤقت إلى المجلد النهائي
                        self.moveCompletedFile(from: tempOutputPath, to: finalOutputPath, for: item)
                        
                        // تنظيف تلقائي بعد نجاح التحميل (على طابور خلفي)
                        DispatchQueue.global(qos: .utility).async {
                            ProcessCleanupManager.shared.performYouTubeDownloadCleanup()
                        }
                    } else if process.terminationStatus == 15 || process.terminationStatus == 9 {
                        // SIGTERM (15) أو SIGKILL (9) - تم إيقاف التحميل مؤقتاً
                        if item.status == .paused {
                            print("⏸️ YouTube download paused: \(item.fileName) (exit code: \(process.terminationStatus))")
                            // لا نحذف الملفات الجزئية عند الإيقاف المؤقت
                        } else {
                            item.status = .failed
                            item.downloadSpeed = "Failed (exit code: \(process.terminationStatus))"
                            print("❌ YouTube download with headers failed: \(item.fileName) (exit code: \(process.terminationStatus))")
                            // تنظيف الملفات الجزئية عند الفشل
                            self.cleanupPartialFiles(for: item)
                            
                            // تنظيف تلقائي بعد فشل التحميل (على طابور خلفي)
                            DispatchQueue.global(qos: .utility).async {
                                ProcessCleanupManager.shared.performYouTubeDownloadCleanup()
                            }
                        }
                    } else {
                        // محاولة fallback ذكية عند عدم توفر الصيغة المطلوبة
                        let errStr = String(data: stderrBuffer, encoding: .utf8) ?? ""
                        if errStr.contains("Requested format is not available") {
                            print("🛟 Retrying with generic bestvideo+bestaudio and resolution selector...")
                            DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
                                guard let self = self, let item = item else { return }
                                var args2 = [String]()
                                // احتفظ بالهيدرز المهمة
                                if let headers = item.customHeaders {
                                    args2.append(contentsOf: ["--cookies-from-browser", "chrome"])
                                    let importantHeaders = ["User-Agent", "Referer", "Origin"]
                                    for (key, value) in headers where importantHeaders.contains(key) {
                                        args2.append("--add-header"); args2.append("\(key):\(value)")
                                    }
                                }
                                // صيغة عامة مع دمج
                                args2.append(contentsOf: [
                                    "-f", "bestvideo+bestaudio/best",
                                    "--merge-output-format", item.audioOnly ? "mp3" : "mp4",
                                    "--no-warnings", "--no-check-certificate", "--ignore-errors", "--no-playlist",
                                    "--no-mtime", "--no-continue", "--no-part",
                                    "--sleep-interval", "0", "--max-sleep-interval", "0",
                                    "--retries", "1", "--fragment-retries", "1",
                                    "--concurrent-fragments", "64", "--buffer-size", "128K",
                                    "--newline", "--progress",
                                    "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
                                    "--no-cache-dir", "--quiet"
                                ])
                                if let ffmpegPath = self.findFfmpegPath() { args2.append(contentsOf: ["--ffmpeg-location", ffmpegPath]) }
                                if let target = self.extractTargetHeight(from: item.fileName) ?? self.extractTargetHeight(from: item.videoQuality) {
                                    args2.append(contentsOf: ["-S", "res:\(target),ext:mp4"]) }
                                args2.append(contentsOf: ["-o", tempOutputPath, item.url])
                                let p2 = self.createYtDlpProcess(ytDlpPath: ytDlpPath, arguments: args2)
                                let out2 = Pipe(); let err2 = Pipe(); var err2Buf = Data()
                                p2.standardOutput = out2; p2.standardError = err2
                                out2.fileHandleForReading.readabilityHandler = { [weak self] h in
                                    if let s = String(data: h.availableData, encoding: .utf8) { self?.parseYouTubeProgressLineEnhanced(s, for: item) }
                                }
                                err2.fileHandleForReading.readabilityHandler = { h in
                                    let d = h.availableData; if !d.isEmpty { err2Buf.append(d) }
                                    if let s = String(data: d, encoding: .utf8), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { print("❌ yt-dlp error output (retry): \(s)") }
                                }
                                do {
                                    try p2.run(); p2.waitUntilExit()
                                    out2.fileHandleForReading.readabilityHandler = nil
                                    err2.fileHandleForReading.readabilityHandler = nil
                                    DispatchQueue.main.async {
                                        if p2.terminationStatus == 0 {
                                            self.moveCompletedFile(from: tempOutputPath, to: finalOutputPath, for: item)
                                            DispatchQueue.global(qos: .utility).async { ProcessCleanupManager.shared.performYouTubeDownloadCleanup() }
                                        } else {
                                            item.status = .failed
                                            item.downloadSpeed = "Failed (exit code: \(p2.terminationStatus))"
                                            self.cleanupPartialFiles(for: item)
                                            DispatchQueue.global(qos: .utility).async { ProcessCleanupManager.shared.performYouTubeDownloadCleanup() }
                                        }
                                        self.saveDownloads()
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        item.status = .failed
                                        item.downloadSpeed = "Failed (retry error)"
                                        self.cleanupPartialFiles(for: item)
                                        DispatchQueue.global(qos: .utility).async { ProcessCleanupManager.shared.performYouTubeDownloadCleanup() }
                                        self.saveDownloads()
                                    }
                                }
                            }
                        } else {
                            item.status = .failed
                            item.downloadSpeed = "Failed (exit code: \(process.terminationStatus))"
                            print("❌ YouTube download with headers failed: \(item.fileName) (exit code: \(process.terminationStatus))")
                            self.cleanupPartialFiles(for: item)
                            DispatchQueue.global(qos: .utility).async { ProcessCleanupManager.shared.performYouTubeDownloadCleanup() }
                        }
                    }
                    self.saveDownloads()
                }
            } catch {
                print("❌ Failed to start YouTube download with headers: \(error)")
                DispatchQueue.main.async {
                    item.status = .failed
                    self.saveDownloads()
                }
            }
        }
    }
    
    // MARK: - Diagnosis Functions
    
    private func diagnoseYouTubeDownloadDelay(for item: DownloadItem) {
        print("🔍 Diagnosing YouTube download delay...")
        
        // التحقق من yt-dlp_macos (المكتبة الجديدة)
        let ytDlpPath = findYtDlpPathOptimized()
        print("📁 yt-dlp path: \(ytDlpPath)")
        
        if FileManager.default.fileExists(atPath: ytDlpPath) {
            print("✅ yt-dlp exists")
            
            // التحقق من صلاحيات التنفيذ
            if let attributes = try? FileManager.default.attributesOfItem(atPath: ytDlpPath),
               let permissions = attributes[.posixPermissions] as? NSNumber {
                let isExecutable = (permissions.intValue & 0o111) != 0
                print("🔐 yt-dlp executable: \(isExecutable)")
            }
            
            // التحقق من حجم الملف
            if let attributes = try? FileManager.default.attributesOfItem(atPath: ytDlpPath),
               let fileSize = attributes[.size] as? NSNumber {
                print("📊 yt-dlp size: \(fileSize.intValue) bytes")
            }
        } else {
            print("❌ yt-dlp not found")
        }
        
        // التحقق من مجلد _internal
        if let internalPath = Bundle.main.path(forResource: "_internal", ofType: nil, inDirectory: "Resources") {
            print("✅ _internal folder found: \(internalPath)")
            
            // التحقق من وجود المكتبات المهمة
            let importantLibs = ["libcrypto.3.dylib", "libssl.3.dylib", "Python"]
            for lib in importantLibs {
                let libPath = "\(internalPath)/\(lib)"
                if FileManager.default.fileExists(atPath: libPath) {
                    print("✅ Found \(lib)")
                } else {
                    print("⚠️ Missing \(lib)")
                }
            }
        } else {
            print("⚠️ _internal folder not found")
        }
        
        // التحقق من ملف yt-dlp.py script
        if let scriptPath = Bundle.main.path(forResource: "yt-dlp", ofType: "py") {
            print("✅ yt-dlp.py script found: \(scriptPath)")
            
            // التحقق من حجم الملف
            if let attributes = try? FileManager.default.attributesOfItem(atPath: scriptPath),
               let fileSize = attributes[.size] as? NSNumber {
                let sizeInKB = fileSize.doubleValue / 1024
                print("📊 yt-dlp.py script size: \(String(format: "%.1f", sizeInKB)) KB")
            }
        } else {
            print("⚠️ yt-dlp.py script not found")
        }
        
        // التحقق من ملف yt-dlp binary
        if let binaryPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            print("✅ yt-dlp binary found: \(binaryPath)")
            
            // التحقق من حجم الملف
            if let attributes = try? FileManager.default.attributesOfItem(atPath: binaryPath),
               let fileSize = attributes[.size] as? NSNumber {
                let sizeInMB = fileSize.doubleValue / (1024 * 1024)
                print("📊 yt-dlp binary size: \(String(format: "%.1f", sizeInMB)) MB")
            }
        } else {
            print("⚠️ yt-dlp binary not found")
        }
        
        // التحقق من متغيرات البيئة
        print("🌍 DYLD_LIBRARY_PATH: \(ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"] ?? "not set")")
        print("🌍 DYLD_FALLBACK_LIBRARY_PATH: \(ProcessInfo.processInfo.environment["DYLD_FALLBACK_LIBRARY_PATH"] ?? "not set")")
        
        // اختبار تشغيل yt-dlp
        print("🧪 Testing yt-dlp execution...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = ["--version"]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("✅ yt-dlp test successful")
            } else {
                print("❌ yt-dlp test failed with status: \(process.terminationStatus)")
            }
        } catch {
            print("❌ yt-dlp test error: \(error)")
        }
    }
    

    
    // MARK: - Helper Functions
    
    // MARK: - Bundled yt-dlp Path Finder (Optimized)
    private func findYtDlpPathOptimized() -> String {
        // البحث السريع عن yt-dlp.py في bundle التطبيق (الأولوية)
        if let scriptPath = Bundle.main.path(forResource: "yt-dlp", ofType: "py") {
            if FileManager.default.fileExists(atPath: scriptPath) {
                print("✅ Using bundled yt-dlp.py script: \(scriptPath)")
                return scriptPath
            }
        }
        
        // البحث عن yt-dlp binary في bundle التطبيق (للتوافق)
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        print("✅ Using bundled yt-dlp binary: \(bundledPath)")
                        return bundledPath
                    }
                }
            }
        }
        
        // البحث في Scripts داخل Resources (للتوافق)
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil, inDirectory: "Scripts") {
            if FileManager.default.fileExists(atPath: bundledPath) {
                print("✅ Using bundled yt-dlp from Scripts: \(bundledPath)")
                return bundledPath
            }
        }
        
        // إذا لم يوجد في bundle، استخدم المسار الافتراضي في Resources
        let defaultPath = Bundle.main.path(forResource: "yt-dlp_macos", ofType: nil) ?? ""
        print("❌ yt-dlp not found in bundle. Expected path: \(defaultPath)")
        return defaultPath
    }
    
    // MARK: - Optimize yt-dlp Startup
    private func optimizeYtDlpStartup() {
        // إعداد متغيرات البيئة لتسريع بدء yt-dlp
        setenv("PYTHONOPTIMIZE", "1", 1)
        setenv("PYTHONUNBUFFERED", "1", 1)
        setenv("LC_ALL", "C", 1)
        setenv("PYTHONWARNINGS", "ignore:Unverified HTTPS request", 1)
        setenv("REQUESTS_CA_BUNDLE", "", 1)
        setenv("SSL_CERT_FILE", "", 1)
        setenv("CURL_CA_BUNDLE", "", 1)
        setenv("PYTHONDONTWRITEBYTECODE", "1", 1)
        setenv("PYTHONHASHSEED", "0", 1)
        setenv("PYTHONFAULTHANDLER", "0", 1)
        setenv("PYTHONTRACEMALLOC", "0", 1)
        setenv("PYTHONPROFILEIMPORTTIME", "0", 1)
        
        print("🚀 yt-dlp startup optimized for speed")
    }
    
    // MARK: - Optimize yt-dlp Arguments for Fast Start
    private func optimizeYtDlpArguments(_ arguments: [String]) -> [String] {
        var optimizedArgs = arguments
        
        // إضافة إعدادات لتسريع بدء التحميل
        let fastStartSettings = [
            "--no-check-certificate",
            "--ignore-errors",
            "--no-warnings",
            "--quiet",
            "--no-colors",
            "--newline",
            "--sleep-interval", "0",
            "--max-sleep-interval", "0"
        ]
        
        // إضافة الإعدادات المحسنة إذا لم تكن موجودة
        for setting in fastStartSettings {
            if !optimizedArgs.contains(setting) {
                optimizedArgs.append(setting)
            }
        }
        
        return optimizedArgs
    }
    
    // MARK: - Create Process with Correct Executable
    private func createYtDlpProcess(ytDlpPath: String, arguments: [String]) -> Process {
        let process = Process()
        
        // تحسين arguments لتسريع بدء التحميل
        let optimizedArguments = optimizeYtDlpArguments(arguments)
        
        // التحقق من نوع الملف
        if ytDlpPath.hasSuffix(".py") {
            // إذا كان ملف Python script، استخدم Python interpreter
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            var pythonArgs = [ytDlpPath]
            pythonArgs.append(contentsOf: optimizedArguments)
            process.arguments = pythonArgs
            print("🐍 Running yt-dlp.py with Python interpreter (optimized)")
        } else {
            // إذا كان binary، شغله مباشرة
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = optimizedArguments
            print("⚡ Running yt-dlp binary directly (optimized)")
        }
        
        // إعداد متغيرات البيئة للعملية لتسريع بدء التحميل
        var env = ProcessInfo.processInfo.environment
        env["PYTHONOPTIMIZE"] = "1"
        env["PYTHONUNBUFFERED"] = "1"
        env["LC_ALL"] = "C"
        env["PYTHONWARNINGS"] = "ignore:Unverified HTTPS request"
        env["REQUESTS_CA_BUNDLE"] = ""
        env["SSL_CERT_FILE"] = ""
        env["CURL_CA_BUNDLE"] = ""
        process.environment = env
        
        return process
    }
    
    // MARK: - Setup Environment Once (Optimized)
    private func setupBundledEnvironmentOnce() {
        // تجنب إعداد البيئة مرات متعددة
        guard !environmentSetup else { return }
        
        // إعداد بيئة محسنة للسرعة
        setenv("PYTHONPATH", "", 1)
        setenv("PYTHONHOME", "", 1)
        setenv("PYTHONUNBUFFERED", "1", 1)
        setenv("LC_ALL", "C", 1)
        setenv("PYTHONWARNINGS", "ignore:Unverified HTTPS request", 1)
        
        // إعداد متغيرات إضافية للسرعة
        setenv("PYTHONDONTWRITEBYTECODE", "1", 1)
        setenv("PYTHONHASHSEED", "0", 1)
        
        // إعداد متغيرات إضافية لتسريع بدء التحميل
        setenv("PYTHONOPTIMIZE", "1", 1)
        setenv("PYTHONFAULTHANDLER", "0", 1)
        setenv("PYTHONTRACEMALLOC", "0", 1)
        setenv("PYTHONPROFILEIMPORTTIME", "0", 1)
        
        // إعداد متغيرات الشبكة لتسريع الاتصال
        setenv("REQUESTS_CA_BUNDLE", "", 1)
        setenv("SSL_CERT_FILE", "", 1)
        setenv("CURL_CA_BUNDLE", "", 1)
        
        environmentSetup = true
        print("🔧 Environment setup completed (enhanced for speed)")
    }
    
    private func findYtDlpPath() -> String {
        // البحث عن yt-dlp في bundle التطبيق أولاً
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let writablePath = copyToWritableLocation(bundledPath, name: "yt-dlp") {
                    // تعيين متغيرات البيئة للمكتبات المدمجة
                    setupBundledEnvironment()
                    return writablePath
                }
            }
        }
        
        // البحث في Scripts داخل Resources (للتوافق مع الإعداد السابق)
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil, inDirectory: "Scripts") {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let writablePath = copyToWritableLocation(bundledPath, name: "yt-dlp") {
                    // تعيين متغيرات البيئة للمكتبات المدمجة
                    setupBundledEnvironment()
                    return writablePath
                }
            }
        }
        
        // إذا لم يوجد في bundle، استخدم المسارات الأخرى
        let paths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                // تأكد من صلاحيات التنفيذ
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
                return path
            }
        }
        
        return "/opt/homebrew/bin/yt-dlp"
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
    
    // MARK: - Resume Support
    private func cleanupPartialFiles(for item: DownloadItem) {
        let expandedPath = self.expandTildePath(item.savePath)
        let fileName = item.fileName.isEmpty ? "video" : item.fileName
        let partialPath = "\(expandedPath)/\(fileName).part"
        
        // حذف الملفات الجزئية عند إلغاء التحميل
        if FileManager.default.fileExists(atPath: partialPath) {
            do {
                try FileManager.default.removeItem(atPath: partialPath)
                print("🗑️ Cleaned up partial file: \(partialPath)")
            } catch {
                print("⚠️ Failed to clean up partial file: \(error)")
            }
        }
    }
    
    private func findFfmpegPath() -> String? {
        // البحث عن ffmpeg في bundle التطبيق أولاً
        if let bundledPath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        print("✅ Using bundled ffmpeg: \(bundledPath)")
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let writablePath = copyToWritableLocation(bundledPath, name: "ffmpeg") {
                    print("✅ Using copied ffmpeg: \(writablePath)")
                    return writablePath
                }
            }
        }
        
        // البحث في النظام إذا لم يوجد في bundle
        let systemPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
            "/bin/ffmpeg"
        ]
        
        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        print("✅ Using system ffmpeg: \(path)")
                        return path
                    }
                }
            }
        }
        
        print("❌ ffmpeg not found in bundle or system")
        return nil
    }
    
    private func checkFileExists(for item: DownloadItem, at path: String) -> Bool {
        // التحقق من الملف باستخدام اسم الملف المحدد في item
        let filePath = "\(path)/\(item.fileName)"
        if FileManager.default.fileExists(atPath: filePath) {
            print("✅ Found file at: \(filePath)")
            return true
        }
        
        // إذا لم يوجد، جرب بدون الامتداد وأضف mp4 أو mp3
        let fileNameWithoutExt = (item.fileName as NSString).deletingPathExtension
        let mp4Path = "\(path)/\(fileNameWithoutExt).mp4"
        let mp3Path = "\(path)/\(fileNameWithoutExt).mp3"
        
        if FileManager.default.fileExists(atPath: mp4Path) {
            print("✅ Found MP4 file at: \(mp4Path)")
            return true
        }
        
        if FileManager.default.fileExists(atPath: mp3Path) {
            print("✅ Found MP3 file at: \(mp3Path)")
            return true
        }
        
        return false
    }
    
    // MARK: - Progress Parsing Functions (Unchanged)
    
    private func parseYouTubeProgressLine(_ line: String, for item: DownloadItem) {
        let lines = line.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("/") && line.contains("%") {
                let components = line.components(separatedBy: " ").filter { !$0.isEmpty }
                if components.count >= 5 {
                    if let sizeComponents = components.first?.components(separatedBy: "/"),
                       sizeComponents.count == 2,
                       let downloaded = Int64(sizeComponents[0]),
                       let total = Int64(sizeComponents[1]) {
                        
                        DispatchQueue.main.async {
                            item.downloadedSize = downloaded
                            item.fileSize = total
                            item.progress = total > 0 ? Double(downloaded) / Double(total) : 0
                        }
                    }
                    
                    if components.count > 1 {
                        let speedStr = components[1]
                        let speedBytes = parseSpeedToBytes(speedStr)
                        DispatchQueue.main.async { [self] in
                            item.updateInstantSpeed(speedBytes)
                            item.downloadSpeed = formatSpeedString(speedBytes)
                        }
                    }
                    
                    if components.count > 2 {
                        DispatchQueue.main.async {
                            item.remainingTime = components[2]
                        }
                    }
                }
            }
        }
    }
    
    // دالة محسّنة لتحليل التقدم
    private func parseYouTubeProgressLineEnhanced(_ line: String, for item: DownloadItem) {
        // تنظيف السطر
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // محاولة تحليل التنسيق المخصص أولاً
        if cleanLine.contains("|") {
            let components = cleanLine.components(separatedBy: "|")
            if components.count >= 5 {
                DispatchQueue.main.async { [self] in
                    // النسبة المئوية
                    if let percentStr = components[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first,
                       let percent = Double(percentStr) {
                        item.progress = percent / 100.0
                        
                        // التحقق من اكتمال التنزيل
                        if item.progress >= 1.0 {
                            item.status = .completed
                            item.progress = 1.0
                            item.downloadSpeed = "Completed"
                            item.remainingTime = "00:00"
                            item.instantSpeed = 0
                            item.speedHistory.removeAll()
                        }
                    }
                    
                    // معالجة السرعة والبيانات الأخرى فقط إذا لم يكتمل التنزيل
                    if item.status != .completed {
                        // السرعة
                        let speedStr = components[1].trimmingCharacters(in: .whitespaces)
                        if speedStr != "N/A" && !speedStr.isEmpty {
                            let speedBytes = parseSpeedToBytes(speedStr)
                            item.updateInstantSpeed(speedBytes)
                            item.downloadSpeed = speedStr
                        }
                        
                        // الوقت المتبقي
                        let etaStr = components[2].trimmingCharacters(in: .whitespaces)
                        if etaStr != "N/A" && !etaStr.isEmpty {
                            item.remainingTime = etaStr
                        }
                    }
                    
                    // البايتات المحملة
                    if components.count > 3 {
                        let downloadedStr = components[3].replacingOccurrences(of: "B", with: "").trimmingCharacters(in: .whitespaces)
                        if let downloaded = Int64(downloadedStr) {
                            item.downloadedSize = downloaded
                        }
                    }
                    
                    // الحجم الكلي
                    if components.count > 4 {
                        let totalStr = components[4].replacingOccurrences(of: "B", with: "").trimmingCharacters(in: .whitespaces)
                        if let total = Int64(totalStr), total > 0 {
                            item.fileSize = total
                        }
                    }
                }
                return
            }
        }
        
        // محاولة التحليل بالطريقة القديمة كخطة احتياطية
        parseYouTubeProgressLineLegacy(cleanLine, for: item)
    }
    
    // دالة التحليل القديمة كخطة احتياطية
    private func parseYouTubeProgressLineLegacy(_ line: String, for item: DownloadItem) {
        // البحث عن نمط التقدم العادي
        let patterns = [
            // النمط 1: [download]  50.2% of 123.45MiB at 2.34MiB/s ETA 00:30
            #"\[download\]\s+(\d+\.?\d*)%\s+of\s+(\S+)\s+at\s+(\S+)\s+ETA\s+(\S+)"#,
            // النمط 2: [download]  50.2% of 123.45MiB at 2.34MiB/s
            #"\[download\]\s+(\d+\.?\d*)%\s+of\s+(\S+)\s+at\s+(\S+)"#,
            // النمط 3: 50.2% 123.45MiB/246.78MiB 2.34MiB/s 00:30
            #"(\d+\.?\d*)%\s+(\S+)/(\S+)\s+(\S+)\s+(\S+)"#,
            // النمط 4: Downloading... 50.2% 2.34MiB/s
            #"Downloading.*?\s+(\d+\.?\d*)%\s+(\S+/s)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    DispatchQueue.main.async { [weak self] in
                        // استخراج النسبة المئوية
                        if match.numberOfRanges > 1,
                           let percentRange = Range(match.range(at: 1), in: line),
                           let percent = Double(String(line[percentRange])) {
                            item.progress = percent / 100.0
                            
                            // التحقق من اكتمال التنزيل
                            if item.progress >= 1.0 {
                                item.status = .completed
                                item.progress = 1.0
                                item.downloadSpeed = "Completed"
                                item.remainingTime = "00:00"
                                item.instantSpeed = 0
                                item.speedHistory.removeAll()
                            }
                        }
                        
                        // معالجة البيانات الأخرى فقط إذا لم يكتمل التنزيل
                        if item.status != .completed {
                            // استخراج السرعة
                            if match.numberOfRanges > 3 {
                                let speedIndex = pattern.contains("of") ? 3 : (pattern.contains("/") ? 4 : 2)
                                if speedIndex <= match.numberOfRanges,
                                   let speedRange = Range(match.range(at: speedIndex), in: line) {
                                    let speedStr = String(line[speedRange])
                                    let speedBytes = self?.parseSpeedToBytes(speedStr) ?? 0
                                    item.updateInstantSpeed(speedBytes)
                                    item.downloadSpeed = speedStr
                                }
                            }
                            
                            // استخراج الوقت المتبقي
                            if match.numberOfRanges > 4,
                               let etaRange = Range(match.range(at: match.numberOfRanges - 1), in: line) {
                                let etaStr = String(line[etaRange])
                                if etaStr.contains(":") {
                                    item.remainingTime = etaStr
                                }
                            }
                        }
                        
                        // استخراج الحجم
                        if match.numberOfRanges > 2 {
                            if let sizeRange = Range(match.range(at: 2), in: line) {
                                let sizeStr = String(line[sizeRange])
                                if sizeStr.contains("/") {
                                    let sizes = sizeStr.components(separatedBy: "/")
                                    if sizes.count == 2 {
                                        item.downloadedSize = self?.parseSizeToBytes(sizes[0]) ?? 0
                                        item.fileSize = self?.parseSizeToBytes(sizes[1]) ?? 0
                                    }
                                } else {
                                    item.fileSize = self?.parseSizeToBytes(sizeStr) ?? 0
                                    item.downloadedSize = Int64(Double(item.fileSize) * item.progress)
                                }
                            }
                        }
                    }
                    return
                }
            }
        }
        
        // إذا لم ينجح أي نمط، حاول استخراج المعلومات الأساسية
        if line.contains("%") {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for component in components {
                if component.contains("%") {
                    if let percentStr = component.replacingOccurrences(of: "%", with: "").components(separatedBy: CharacterSet.letters).first,
                       let percent = Double(percentStr) {
                        DispatchQueue.main.async {
                            item.progress = percent / 100.0
                            
                            // التحقق من اكتمال التنزيل
                            if item.progress >= 1.0 {
                                item.status = .completed
                                item.progress = 1.0
                                item.downloadSpeed = "Completed"
                                item.remainingTime = "00:00"
                                item.instantSpeed = 0
                                item.speedHistory.removeAll()
                            }
                        }
                    }
                } else if component.contains("/s") && item.status != .completed {
                    DispatchQueue.main.async { [self] in
                        let speedBytes = parseSpeedToBytes(component)
                        item.updateInstantSpeed(speedBytes)
                        item.downloadSpeed = component
                    }
                }
            }
        }
    }
    
    private func parseSpeedToBytes(_ text: String) -> Double {
        let units: [String: Double] = [
            "B/s": 1,
            "KB/s": 1024,
            "MB/s": 1024 * 1024,
            "GB/s": 1024 * 1024 * 1024,
            "KiB/s": 1024,
            "MiB/s": 1024 * 1024,
            "GiB/s": 1024 * 1024 * 1024
        ]
        
        let pattern = #"([\d\.]+)\s*([KMGT]?i?B/s)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let sizeNSRange = match.range(at: 1)
            let unitNSRange = match.range(at: 2)
            
            if sizeNSRange.location != NSNotFound && unitNSRange.location != NSNotFound,
               let sizeRange = Range(sizeNSRange, in: text),
               let unitRange = Range(unitNSRange, in: text) {
                
                let sizeString = String(text[sizeRange])
                let unitString = String(text[unitRange])
                
                if let size = Double(sizeString), let unitMultiplier = units[unitString] {
                    return size * unitMultiplier
                }
            }
        }
        
        // محاولة تحليل بسيط
        for (unit, multiplier) in units {
            if text.contains(unit) {
                let numberString = text.replacingOccurrences(of: unit, with: "").trimmingCharacters(in: .whitespaces)
                if let number = Double(numberString) {
                    return number * multiplier
                }
            }
        }
        
        return 0
    }
    
    // دالة لتحويل حجم الملف إلى بايتات
    private func parseSizeToBytes(_ sizeStr: String) -> Int64 {
        let cleanStr = sizeStr.trimmingCharacters(in: .whitespaces)
        let units: [String: Double] = [
            "B": 1,
            "KB": 1024,
            "MB": 1024 * 1024,
            "GB": 1024 * 1024 * 1024,
            "KiB": 1024,
            "MiB": 1024 * 1024,
            "GiB": 1024 * 1024 * 1024
        ]
        
        for (unit, multiplier) in units {
            if cleanStr.contains(unit) {
                let numberStr = cleanStr.replacingOccurrences(of: unit, with: "").trimmingCharacters(in: .whitespaces)
                if let number = Double(numberStr) {
                    return Int64(number * multiplier)
                }
            }
        }
        
        return 0
    }
    
    func isYouTubeURL(_ string: String) -> Bool {
        let youtubePatterns = [
            "youtube.com/watch",
            "youtu.be/",
            "youtube.com/embed/",
            "youtube.com/v/",
            "m.youtube.com/watch",
            "youtube.com/shorts/"
        ]
        
        return youtubePatterns.contains { string.lowercased().contains($0) }
    }
    
    // MARK: - File Management
    private func moveCompletedFile(from tempPath: String, to finalPath: String, for item: DownloadItem) {
        print("🔄 Moving completed file from temp to final location...")
        
        // التحقق من وجود الملف المؤقت
        guard FileManager.default.fileExists(atPath: tempPath) else {
            print("❌ Temp file not found: \(tempPath)")
            DispatchQueue.main.async {
                item.status = .failed
                item.downloadSpeed = "File not found after download"
                self.saveDownloads()
            }
            return
        }
        
        // حذف الملف النهائي إذا كان موجوداً
        if FileManager.default.fileExists(atPath: finalPath) {
            do {
                try FileManager.default.removeItem(atPath: finalPath)
                print("🗑️ Removed existing file: \(finalPath)")
            } catch {
                print("⚠️ Failed to remove existing file: \(error)")
            }
        }
        
        // نقل الملف من المجلد المؤقت إلى المجلد النهائي
        do {
            try FileManager.default.moveItem(atPath: tempPath, toPath: finalPath)
            print("✅ File moved successfully to: \(finalPath)")
            
            // تحديث حالة التحميل
            DispatchQueue.main.async {
                item.status = .completed
                item.progress = 1.0
                item.downloadSpeed = "Completed"
                item.remainingTime = "00:00"
                item.instantSpeed = 0
                print("✅ YouTube download with headers completed: \(item.fileName)")
                self.notificationManager.sendDownloadCompleteNotification(for: item)
                self.saveDownloads()
                
                // تنظيف إضافي بعد اكتمال التحميل
                DispatchQueue.global(qos: .background).async {
                    ProcessCleanupManager.shared.performYouTubeDownloadCleanup()
                }
            }
            
        } catch {
            print("❌ Failed to move file: \(error)")
            DispatchQueue.main.async {
                item.status = .failed
                item.downloadSpeed = "Failed to move file"
                self.saveDownloads()
            }
        }
    }
    
    // MARK: - Pre-warm Optimization for Current Download
    private func prewarmYtDlpForCurrentDownload() {
        print("🔥 Pre-warming yt-dlp for current download...")
        
        // الحصول على مسار yt-dlp
        let ytDlpPath = findYtDlpPathOptimized()
        
        guard FileManager.default.fileExists(atPath: ytDlpPath) else {
            print("⚠️ yt-dlp not found for pre-warm")
            return
        }
        
        // تشغيل yt-dlp مع أمر سريع لـ pre-warm
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = ["--version"]
        
        // إعداد بيئة العمل
        var environment = ProcessInfo.processInfo.environment
        if let bundlePath = Bundle.main.resourcePath {
            environment["PYTHONPATH"] = bundlePath
        }
        process.environment = environment
        
        // تشغيل في الخلفية بدون انتظار
        do {
            try process.run()
            print("✅ yt-dlp pre-warm initiated for current download")
        } catch {
            print("⚠️ Failed to pre-warm yt-dlp: \(error)")
        }
    }
    
    // MARK: - Optimize yt-dlp for Speed
    private func optimizeYtDlpForSpeed() {
        print("🚀 Optimizing yt-dlp for maximum speed...")
        
        // تشغيل yt-dlp مع أمر سريع لتحسين السرعة
        let ytDlpPath = findYtDlpPathOptimized()
        
        guard FileManager.default.fileExists(atPath: ytDlpPath) else {
            print("⚠️ yt-dlp not found for speed optimization")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = [
            "--version",
            "--no-check-certificate",
            "--ignore-errors",
            "--no-warnings",
            "--quiet",
            "--no-colors",
            "--newline",
            "--sleep-interval", "0",
            "--max-sleep-interval", "0",
            "--retries", "1",
            "--fragment-retries", "1",
            "--concurrent-fragments", "64", // زيادة من 16 إلى 64 للسرعة القصوى
            "--buffer-size", "512K", // زيادة من 256K إلى 512K
            "--no-cache-dir"
        ]
        
        // إعداد بيئة العمل
        var environment = ProcessInfo.processInfo.environment
        if let bundlePath = Bundle.main.resourcePath {
            environment["PYTHONPATH"] = bundlePath
        }
        process.environment = environment
        
        do {
            try process.run()
            print("✅ yt-dlp speed optimization initiated")
        } catch {
            print("⚠️ Failed to optimize yt-dlp for speed: \(error)")
        }
    }
    
    // MARK: - Fast Download Start
    private func startFastDownload(for item: DownloadItem, ytDlpPath: String, arguments: [String]) {
        print("⚡ Starting ultra-fast download with optimized settings...")
        
        // إنشاء العملية مع إعدادات محسنة للسرعة
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = arguments
        
        // إعداد بيئة العمل المحسنة
        var environment = ProcessInfo.processInfo.environment
        if let bundlePath = Bundle.main.resourcePath {
            environment["PYTHONPATH"] = bundlePath
        }
        // إضافة متغيرات بيئة إضافية لتحسين الأداء
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONIOENCODING"] = "utf-8"
        process.environment = environment
        
        // إعداد pipes مع buffer محسن
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // تحسين buffer size للـ pipes
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak item] handle in
            guard let self = self, let item = item else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let output = String(data: data, encoding: .utf8) {
                // معالجة سريعة للـ output
                self.parseYouTubeProgressLineEnhanced(output, for: item)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // تجاهل الأخطاء غير المهمة للسرعة
                if !errorOutput.contains("WARNING") && !errorOutput.contains("INFO") {
                    print("⚠️ yt-dlp error: \(errorOutput)")
                }
            }
        }
        
        do {
            try process.run()
            
            DispatchQueue.main.async {
                item.processTask = process
                item.status = .downloading
                self.objectWillChange.send()
            }
            
            // مراقبة العملية مع timeout محسن
            DispatchQueue.global().async { [weak self, weak item] in
                let startTime = Date()
                let timeout: TimeInterval = 300 // 5 دقائق timeout
                
                while process.isRunning {
                    Thread.sleep(forTimeInterval: 0.1) // تقليل من 0.5 إلى 0.1
                    
                    // التحقق من timeout
                    if Date().timeIntervalSince(startTime) > timeout {
                        print("⏰ Download timeout reached, terminating...")
                        process.terminate()
                        break
                    }
                    
                    guard let self = self, let item = item else { break }
                    
                    // تحديث سريع للحالة
                    if item.progress > 0.99 {
                        DispatchQueue.main.async {
                            item.status = .completed
                            item.progress = 1.0
                            item.downloadSpeed = "Completed"
                            self.objectWillChange.send()
                        }
                        break
                    }
                }
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    print("✅ Fast download completed successfully")
                    // معالجة اكتمال التحميل
                    self.handleYouTubeDownloadCompletion(for: item)
                } else {
                    print("❌ Fast download failed with exit code: \(process.terminationStatus)")
                    item.status = .failed
                    item.downloadSpeed = "Failed"
                    self.objectWillChange.send()
                }
                
                self.saveDownloads()
            }
            
        } catch {
            print("💥 Failed to start fast download: \(error)")
            DispatchQueue.main.async {
                item.status = .failed
                item.downloadSpeed = "Failed to start"
                self.objectWillChange.send()
                self.saveDownloads()
            }
        }
    }
    
    // MARK: - Handle Download Completion
    private func handleYouTubeDownloadCompletion(for item: DownloadItem) {
        // نقل الملف من المجلد المؤقت إلى المجلد النهائي
        let tempDir = NSTemporaryDirectory()
        let tempDownloadDir = "\(tempDir)SafarGet_Downloads"
        let fileNameWithoutExt = (item.fileName as NSString).deletingPathExtension
        let fileExtension = item.audioOnly ? "mp3" : "mp4"
        let finalFileName = "\(fileNameWithoutExt).\(fileExtension)"
        let tempOutputPath = "\(tempDownloadDir)/\(finalFileName)"
        let expandedPath = self.expandTildePath(item.savePath)
        let finalOutputPath = "\(expandedPath)/\(finalFileName)"
        
        self.moveCompletedFile(from: tempOutputPath, to: finalOutputPath, for: item)
    }
    
    // MARK: - New YouTube Download Method (Separate Video/Audio)
    func startYouTubeDownloadSeparate(for item: DownloadItem) {
        print("🚀 Starting YouTube download with separate method for: \(item.fileName)")
        
        // تحديث الحالة فوراً
        DispatchQueue.main.async {
            item.status = .downloading
            item.downloadSpeed = "Extracting URLs..."
            item.instantSpeed = 0
            item.remainingTime = "--:--"
            self.objectWillChange.send()
        }
        
        // بدء العملية في خيط منفصل
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            ProcessCleanupManager.shared.beginYouTubeOperation()
            
            // المرحلة 1: استخراج روابط الفيديو والصوت
            self.extractYouTubeURLs(for: item) { [weak self, weak item] result in
                guard let self = self, let item = item else { return }
                
                // التحقق من حالة التحميل قبل المتابعة
                if item.status == .paused || item.status == .cancelled {
                    print("⏸️ Download paused/cancelled during URL extraction")
                    return
                }
                
                switch result {
                case .success(let urls):
                    // المرحلة 2: تحميل الملفين بشكل متوازي
                    self.downloadYouTubeFilesSeparately(for: item, urls: urls) { [weak self, weak item] result in
                        guard let self = self, let item = item else { return }
                        
                        // التحقق من حالة التحميل قبل المتابعة
                        if item.status == .paused || item.status == .cancelled {
                            print("⏸️ Download paused/cancelled during file download")
                            return
                        }
                        
                        switch result {
                        case .success(let filePaths):
                            // المرحلة 3: دمج الملفين
                            self.mergeYouTubeFiles(for: item, videoPath: filePaths.video, audioPath: filePaths.audio) { [weak self, weak item] result in
                                guard let self = self, let item = item else { return }
                                
                                // التحقق من حالة التحميل قبل المتابعة
                                if item.status == .paused || item.status == .cancelled {
                                    print("⏸️ Download paused/cancelled during merge")
                                    return
                                }
                                
                                switch result {
                                case .success(_):
                                    // المرحلة 4: تنظيف الملفات المؤقتة
                                    self.cleanupYouTubeTempFiles(videoPath: filePaths.video, audioPath: filePaths.audio)
                                    
                                    DispatchQueue.main.async {
                                        item.status = .completed
                                        item.progress = 1.0
                                        item.downloadSpeed = "Completed"
                                        item.remainingTime = "00:00"
                                        ProcessCleanupManager.shared.endYouTubeOperation()
                                    }
                                    
                                case .failure(let error):
                                    print("❌ Merge failed: \(error)")
                                    DispatchQueue.main.async {
                                        item.status = .failed
                                        item.downloadSpeed = "Merge failed"
                                        ProcessCleanupManager.shared.endYouTubeOperation()
                                    }
                                }
                            }
                            
                        case .failure(let error):
                            print("❌ Download failed: \(error)")
                            DispatchQueue.main.async {
                                item.status = .failed
                                item.downloadSpeed = "Download failed"
                                ProcessCleanupManager.shared.endYouTubeOperation()
                            }
                        }
                    }
                    
                case .failure(let error):
                    print("❌ URL extraction failed: \(error)")
                    DispatchQueue.main.async {
                        item.status = .failed
                        item.downloadSpeed = "URL extraction failed"
                        ProcessCleanupManager.shared.endYouTubeOperation()
                    }
                }
            }
        }
    }
    
    // MARK: - Phase 1: Extract YouTube URLs
    private func extractYouTubeURLs(for item: DownloadItem, completion: @escaping (Result<YouTubeURLs, Error>) -> Void) {
        print("🔍 Phase 1: Extracting YouTube URLs...")
        
        let ytDlpPath = self.findYtDlpPathOptimized()
        guard FileManager.default.fileExists(atPath: ytDlpPath) else {
            completion(.failure(YouTubeError.ytDlpNotFound))
            return
        }
        
        // تحديث الحالة
        DispatchQueue.main.async {
            item.downloadSpeed = "Extracting URLs..."
        }
        
        // إعداد arguments لاستخراج الروابط فقط
        var arguments = [
            "--get-url",
            "--no-warnings",
            "--no-check-certificate",
            "--ignore-errors",
            "--no-playlist",
            "--quiet",
            "--no-colors"
        ]
        
        // إضافة format selection
        if item.audioOnly {
            arguments.append(contentsOf: ["-f", "bestaudio[ext=m4a]/bestaudio"])
        } else {
            let selectedQuality = item.videoFormat.isEmpty ? "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" : SmartFormatSelector.selectOptimalFormat(for: item.videoFormat, audioOnly: item.audioOnly)
            arguments.append(contentsOf: ["-f", selectedQuality])
        }
        
        // إضافة URL
        arguments.append(item.url)
        
        print("🔍 yt-dlp URL extraction command:")
        print("🔍 yt-dlp \(arguments.joined(separator: " "))")
        
        // إنشاء العملية
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = arguments
        
        // حفظ العملية للتحكم فيها
        DispatchQueue.main.async {
            item.processTask = process
        }
        
        // إعداد pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        var outputData = Data()
        var errorData = Data()
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // إغلاق pipes
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            // التحقق من حالة التحميل
            if item.status == .paused || item.status == .cancelled {
                print("⏸️ Download paused/cancelled during URL extraction")
                completion(.failure(YouTubeError.downloadCancelled))
                return
            }
            
            if process.terminationStatus == 0 {
                // تحليل النتائج
                if let output = String(data: outputData, encoding: .utf8) {
                    let urls = self.parseYouTubeURLs(output, audioOnly: item.audioOnly)
                    if !urls.videoURL.isEmpty || !urls.audioURL.isEmpty {
                        print("✅ URLs extracted successfully")
                        print("   Video URL: \(urls.videoURL)")
                        print("   Audio URL: \(urls.audioURL)")
                        completion(.success(urls))
                    } else {
                        completion(.failure(YouTubeError.noURLsFound))
                    }
                } else {
                    completion(.failure(YouTubeError.invalidOutput))
                }
            } else {
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("❌ yt-dlp URL extraction failed: \(errorOutput)")

                // 🛟 Fallback: أعد المحاولة بصيغة عامة إذا كانت الصيغة المطلوبة غير متاحة
                if errorOutput.contains("Requested format is not available") {
                    var fallbackArgs = [
                        "--get-url",
                        "--no-warnings", "--no-check-certificate", "--ignore-errors",
                        "--no-playlist", "--quiet", "--no-colors",
                        "-f", item.audioOnly ? "bestaudio/best" : "bestvideo+bestaudio/best"
                    ]
                    if let target = self.extractTargetHeight(from: item.videoQuality.isEmpty ? item.fileName : item.videoQuality) {
                        fallbackArgs.append(contentsOf: ["-S", "res:\(target)"]) // لا نقيّد بالامتداد لتفادي الهبوط
                        print("🛟 Fallback URL extraction with selector: -S res:\(target)")
                    }
                    fallbackArgs.append(item.url)

                    let p2 = Process()
                    p2.executableURL = URL(fileURLWithPath: ytDlpPath)
                    p2.arguments = fallbackArgs
                    let out2 = Pipe(); let err2 = Pipe()
                    p2.standardOutput = out2; p2.standardError = err2
                    var outBuf2 = Data(); var errBuf2 = Data()
                    out2.fileHandleForReading.readabilityHandler = { h in let d = h.availableData; if !d.isEmpty { outBuf2.append(d) } }
                    err2.fileHandleForReading.readabilityHandler = { h in let d = h.availableData; if !d.isEmpty { errBuf2.append(d) } }
                    do {
                        try p2.run(); p2.waitUntilExit()
                        out2.fileHandleForReading.readabilityHandler = nil
                        err2.fileHandleForReading.readabilityHandler = nil
                        if p2.terminationStatus == 0, let outStr = String(data: outBuf2, encoding: .utf8) {
                            let urls = self.parseYouTubeURLs(outStr, audioOnly: item.audioOnly)
                            if !urls.videoURL.isEmpty || !urls.audioURL.isEmpty {
                                print("✅ URLs extracted successfully (fallback)")
                                print("   Video URL: \(urls.videoURL)")
                                print("   Audio URL: \(urls.audioURL)")
                                completion(.success(urls))
                                return
                            }
                        }
                        let errStr2 = String(data: errBuf2, encoding: .utf8) ?? ""
                        print("❌ Fallback URL extraction failed: \(errStr2)")
                        completion(.failure(YouTubeError.ytDlpError(errStr2.isEmpty ? errorOutput : errStr2)))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.failure(YouTubeError.ytDlpError(errorOutput)))
                }
            }
            
        } catch {
            print("❌ Failed to run yt-dlp for URL extraction: \(error)")
            completion(.failure(error))
        }
    }
    
    // MARK: - Parse YouTube URLs
    private func parseYouTubeURLs(_ output: String, audioOnly: Bool) -> YouTubeURLs {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        if audioOnly {
            // للصوت فقط، نأخذ أول رابط
            return YouTubeURLs(videoURL: "", audioURL: lines.first ?? "")
        } else {
            // للفيديو، نحتاج رابطين منفصلين
            if lines.count >= 2 {
                // عادةً يكون الفيديو أولاً ثم الصوت
                return YouTubeURLs(videoURL: lines[0], audioURL: lines[1])
            } else if lines.count == 1 {
                // رابط واحد فقط (فيديو مدمج)
                return YouTubeURLs(videoURL: lines[0], audioURL: "")
            } else {
                return YouTubeURLs(videoURL: "", audioURL: "")
            }
        }
    }
    
    // MARK: - Phase 2: Download Files Separately
    private func downloadYouTubeFilesSeparately(for item: DownloadItem, urls: YouTubeURLs, completion: @escaping (Result<YouTubeFilePaths, Error>) -> Void) {
        print("📥 Phase 2: Downloading files separately...")
        
        let aria2cPath = findAria2cPath()
        guard let aria2cPath = aria2cPath, FileManager.default.fileExists(atPath: aria2cPath) else {
            completion(.failure(YouTubeError.aria2cNotFound))
            return
        }
        
        // إنشاء مجلد مؤقت للتحميل
        let tempDir = NSTemporaryDirectory()
        let tempDownloadDir = "\(tempDir)SafarGet_YouTube_Separate"
        
        do {
            try FileManager.default.createDirectory(atPath: tempDownloadDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("⚠️ Failed to create temp directory: \(error)")
        }
        
        // تحديث الحالة
        DispatchQueue.main.async {
            item.downloadSpeed = "Downloading..."
            item.instantSpeed = 0
            item.remainingTime = "--:--"
            self.objectWillChange.send()
        }
        
        // إعداد مسارات الملفات المؤقتة
        let videoTempPath = "\(tempDownloadDir)/video_temp.mp4"
        let audioTempPath = "\(tempDownloadDir)/audio_temp.m4a"
        
        // إنشاء مجموعة للتحميلات المتوازية
        let downloadGroup = DispatchGroup()
        var videoDownloadResult: Result<String, Error>?
        var audioDownloadResult: Result<String, Error>?
        
        // تحميل الفيديو (إذا كان مطلوباً)
        if !urls.videoURL.isEmpty && !item.audioOnly {
            downloadGroup.enter()
            downloadWithAria2c(url: urls.videoURL, outputPath: videoTempPath, aria2cPath: aria2cPath, item: item) { result in
                videoDownloadResult = result
                downloadGroup.leave()
            }
        }
        
        // تحميل الصوت
        if !urls.audioURL.isEmpty {
            downloadGroup.enter()
            let audioOutputPath = item.audioOnly ? audioTempPath : audioTempPath
            downloadWithAria2c(url: urls.audioURL, outputPath: audioOutputPath, aria2cPath: aria2cPath, item: item) { result in
                audioDownloadResult = result
                downloadGroup.leave()
            }
        }
        
        // انتظار اكتمال جميع التحميلات
        downloadGroup.notify(queue: .global()) {
            // التحقق من النتائج
            if let videoResult = videoDownloadResult, case .failure(let videoError) = videoResult, !item.audioOnly {
                // التحقق من انتهاء صلاحية الرابط
                if case YouTubeError.urlExpired = videoError {
                    print("🔄 Video URL expired, getting new URLs...")
                    self.handleURLExpiration(for: item, completion: completion)
                    return
                }
                completion(.failure(videoError))
                return
            }
            
            if let audioResult = audioDownloadResult, case .failure(let audioError) = audioResult {
                // التحقق من انتهاء صلاحية الرابط
                if case YouTubeError.urlExpired = audioError {
                    print("🔄 Audio URL expired, getting new URLs...")
                    self.handleURLExpiration(for: item, completion: completion)
                    return
                }
                completion(.failure(audioError))
                return
            }
            
            // نجح التحميل
            let videoPath: String
            if let videoResult = videoDownloadResult, case .success(let path) = videoResult {
                videoPath = path
            } else {
                videoPath = ""
            }
            
            let audioPath: String
            if let audioResult = audioDownloadResult, case .success(let path) = audioResult {
                audioPath = path
            } else {
                audioPath = ""
            }
            
            let filePaths = YouTubeFilePaths(
                video: videoPath,
                audio: audioPath
            )
            
            print("✅ Files downloaded successfully")
            print("   Video: \(videoPath)")
            print("   Audio: \(audioPath)")
            
            completion(.success(filePaths))
        }
    }
    
    // MARK: - Handle URL Expiration
    private func handleURLExpiration(for item: DownloadItem, completion: @escaping (Result<YouTubeFilePaths, Error>) -> Void) {
        print("🔄 Handling URL expiration for: \(item.fileName)")
        
        // تحديث الحالة
        DispatchQueue.main.async {
            item.downloadSpeed = "Getting new URLs..."
        }
        
        // إعادة استخراج الروابط
        extractYouTubeURLs(for: item) { [weak self, weak item] result in
            guard let self = self, let item = item else { return }
            
            switch result {
            case .success(let newURLs):
                print("✅ Got new URLs, resuming download...")
                // إعادة محاولة التحميل مع الروابط الجديدة
                self.downloadYouTubeFilesSeparately(for: item, urls: newURLs, completion: completion)
                
            case .failure(let error):
                print("❌ Failed to get new URLs: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Download with aria2c
    private func downloadWithAria2c(url: String, outputPath: String, aria2cPath: String, item: DownloadItem, completion: @escaping (Result<String, Error>) -> Void) {
        print("📥 Downloading with aria2c: \(url)")
        
        // التحقق من وجود ملف جزئي للاستئناف
        let partialPath = outputPath + ".aria2"
        let hasPartialFile = FileManager.default.fileExists(atPath: partialPath)
        let hasMainFile = FileManager.default.fileExists(atPath: outputPath)
        
        if hasPartialFile {
            print("🔄 Found partial file, resuming download: \(partialPath)")
            
            // تحديث الحالة للاستئناف
            DispatchQueue.main.async {
                item.downloadSpeed = "Resuming..."
                item.isResuming = true
                self.objectWillChange.send()
            }
        }
        
        if hasMainFile {
            print("✅ File already exists, skipping download: \(outputPath)")
            completion(.success(outputPath))
            return
        }
        
        // إعداد arguments لـ aria2c
        var arguments = [
            "-x", "16",  // 16 connections per server
            "-s", "16",  // 16 splits
            "-k", "1M",  // 1MB minimum split size
            "--max-connection-per-server=16",
            "--min-split-size=1M",
            "--split=16",
            "--max-concurrent-downloads=8",
            "--max-overall-download-limit=0",
            "--max-download-limit=0",
            "--file-allocation=falloc",
            "--no-file-allocation-limit=1M",
            "--allow-overwrite=true",
            "--check-certificate=false",
            "--console-log-level=info",
            "--summary-interval=1",
            "--show-console-readout=true",
            "--human-readable=true",
            "--download-result=full",
            "--show-files=false",
            "--enable-color=false",
            "--check-integrity=true",
            "--realtime-chunk-checksum=true",
            "--timeout=30",
            "--connect-timeout=30",
            "--max-tries=3",
            "--retry-wait=2",
            "--always-resume=true",
            "--max-resume-failure-tries=3",
            "--save-session-interval=1",
            "--force-save=true",
            "--disk-cache=32M",
            "--enable-mmap=true",
            "--optimize-concurrent-downloads=true",
            "-o", (outputPath as NSString).lastPathComponent,
            "-d", (outputPath as NSString).deletingLastPathComponent,
            url
        ]
        
        // إضافة خيارات الاستئناف إذا كان هناك ملف جزئي
        if hasPartialFile {
            arguments.append(contentsOf: [
                "--continue=true",
                "--max-resume-failure-tries=5"
            ])
        }
        
        print("📥 aria2c command:")
        print("📥 aria2c \(arguments.joined(separator: " "))")
        
        // إنشاء العملية
        let process = Process()
        process.executableURL = URL(fileURLWithPath: aria2cPath)
        process.arguments = arguments
        
        // حفظ العملية للتحكم فيها
        DispatchQueue.main.async {
            item.processTask = process
        }
        
        // إعداد pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // قراءة التقدم
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                self?.parseAria2cProgress(output, for: item)
            }
        }
        
        // قراءة الأخطاء
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("⚠️ aria2c error: \(errorOutput)")
            }
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // إغلاق pipes
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            // التحقق من حالة التحميل
            if item.status == .paused || item.status == .cancelled {
                print("⏸️ Download paused/cancelled during aria2c execution")
                completion(.failure(YouTubeError.downloadCancelled))
                return
            }
            
            if process.terminationStatus == 0 {
                // التحقق من وجود الملف
                if FileManager.default.fileExists(atPath: outputPath) {
                    completion(.success(outputPath))
                } else {
                    completion(.failure(YouTubeError.fileNotFound))
                }
            } else {
                // التحقق من نوع الخطأ
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                // التحقق من انتهاء صلاحية الرابط
                if errorOutput.contains("HTTP 403") || errorOutput.contains("HTTP 410") || errorOutput.contains("expired") {
                    print("⚠️ URL expired, need to get new URLs")
                    completion(.failure(YouTubeError.urlExpired))
                } else {
                    completion(.failure(YouTubeError.aria2cError("Exit code: \(process.terminationStatus)")))
                }
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Parse aria2c Progress
    private func parseAria2cProgress(_ output: String, for item: DownloadItem) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // البحث عن نمط التقدم في aria2c
            // مثال: [#1 SIZE:123.45MiB/456.78MiB CN:16 SPD:2.34MiB/s ETA:00:30]
            let pattern = #"\[#\d+\s+SIZE:([^/]+)/([^\]]+)\s+CN:\d+\s+SPD:([^\s]+)\s+ETA:([^\]]+)\]"#
            
            // البحث عن أنماط إضافية للتقدم
            let alternativePattern = #"\[#\d+\s+CN:\d+\s+SPD:([^\s]+)\s+ETA:([^\]]+)\]"#
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // استخراج النسبة المئوية
                        if match.numberOfRanges > 2,
                           let downloadedRange = Range(match.range(at: 1), in: line),
                           let totalRange = Range(match.range(at: 2), in: line) {
                            
                            let downloadedStr = String(line[downloadedRange])
                            let totalStr = String(line[totalRange])
                            
                            let downloaded = self.parseSizeToBytes(downloadedStr)
                            let total = self.parseSizeToBytes(totalStr)
                            
                            if total > 0 {
                                item.downloadedSize = downloaded
                                item.fileSize = total
                                item.progress = Double(downloaded) / Double(total)
                            }
                        }
                        
                        // استخراج السرعة
                        if match.numberOfRanges > 3,
                           let speedRange = Range(match.range(at: 3), in: line) {
                            let speedStr = String(line[speedRange])
                            let speedBytes = self.parseSpeedToBytes(speedStr)
                            
                            item.updateInstantSpeed(speedBytes)
                            item.downloadSpeed = speedStr
                            
                            // إزالة علامة الاستئناف إذا ظهرت سرعة
                            if item.isResuming && speedBytes > 0 {
                                item.isResuming = false
                                print("🔄 [RESUME] Removed resuming flag due to speed detection in aria2c")
                            }
                        }
                        
                        // استخراج الوقت المتبقي
                        if match.numberOfRanges > 4,
                           let etaRange = Range(match.range(at: 4), in: line) {
                            let etaStr = String(line[etaRange])
                            item.remainingTime = etaStr
                        }
                        
                        self.objectWillChange.send()
                    }
                    return
                }
            }
            
            // معالجة النمط البديل (بدون معلومات الحجم)
            if let regex = try? NSRegularExpression(pattern: alternativePattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        // استخراج السرعة فقط
                        if match.numberOfRanges > 1,
                           let speedRange = Range(match.range(at: 1), in: line) {
                            let speedStr = String(line[speedRange])
                            let speedBytes = self.parseSpeedToBytes(speedStr)
                            
                            item.updateInstantSpeed(speedBytes)
                            item.downloadSpeed = speedStr
                            
                            // إزالة علامة الاستئناف إذا ظهرت سرعة
                            if item.isResuming && speedBytes > 0 {
                                item.isResuming = false
                                print("🔄 [RESUME] Removed resuming flag due to speed detection in aria2c (alternative pattern)")
                            }
                        }
                        
                        // استخراج الوقت المتبقي
                        if match.numberOfRanges > 2,
                           let etaRange = Range(match.range(at: 2), in: line) {
                            let etaStr = String(line[etaRange])
                            item.remainingTime = etaStr
                        }
                        
                        self.objectWillChange.send()
                    }
                    return
                }
            }
        }
    }
    
    // MARK: - Phase 3: Merge Files
    private func mergeYouTubeFiles(for item: DownloadItem, videoPath: String, audioPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🔧 Phase 3: Merging files...")
        
        let ffmpegPath = findFfmpegPath()
        guard let ffmpegPath = ffmpegPath, FileManager.default.fileExists(atPath: ffmpegPath) else {
            completion(.failure(YouTubeError.ffmpegNotFound))
            return
        }
        
        // تحديث الحالة
        DispatchQueue.main.async {
            item.downloadSpeed = "Merging..."
        }
        
        // إعداد مسار الملف النهائي
        let expandedPath = self.expandTildePath(item.savePath)
        let fileNameWithoutExt = (item.fileName as NSString).deletingPathExtension
        let fileExtension = item.audioOnly ? "mp3" : "mp4"
        let finalFileName = "\(fileNameWithoutExt).\(fileExtension)"
        let finalOutputPath = "\(expandedPath)/\(finalFileName)"
        
        // إنشاء المجلد النهائي
        do {
            try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("⚠️ Failed to create final directory: \(error)")
        }
        
        // إعداد arguments لـ ffmpeg
        var arguments: [String] = []
        
        if item.audioOnly {
            // للصوت فقط، نحول m4a إلى mp3
            arguments = [
                "-i", audioPath,
                "-c:a", "copy",
                "-y",  // overwrite output file
                finalOutputPath
            ]
        } else {
            // للفيديو، ندمج الفيديو والصوت
            if !videoPath.isEmpty && !audioPath.isEmpty {
                // دمج الفيديو والصوت بدون إعادة ترميز
                arguments = [
                    "-i", videoPath,
                    "-i", audioPath,
                    "-c:v", "copy",
                    "-c:a", "copy",
                    "-y",  // overwrite output file
                    finalOutputPath
                ]
            } else if !videoPath.isEmpty {
                // فيديو فقط (مدمج بالفعل)
                arguments = [
                    "-i", videoPath,
                    "-c", "copy",
                    "-y",  // overwrite output file
                    finalOutputPath
                ]
            } else {
                completion(.failure(YouTubeError.noFilesToMerge))
                return
            }
        }
        
        print("🔧 ffmpeg merge command:")
        print("🔧 ffmpeg \(arguments.joined(separator: " "))")
        
        // إنشاء العملية
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments
        
        // إعداد pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // التحقق من حالة التحميل
            if item.status == .paused || item.status == .cancelled {
                print("⏸️ Download paused/cancelled during ffmpeg merge")
                completion(.failure(YouTubeError.downloadCancelled))
                return
            }
            
            if process.terminationStatus == 0 {
                // التحقق من وجود الملف النهائي
                if FileManager.default.fileExists(atPath: finalOutputPath) {
                    print("✅ Files merged successfully: \(finalOutputPath)")
                    completion(.success(finalOutputPath))
                } else {
                    completion(.failure(YouTubeError.mergeFailed))
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("❌ ffmpeg merge failed: \(errorOutput)")
                completion(.failure(YouTubeError.ffmpegError(errorOutput)))
            }
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Phase 4: Cleanup Temp Files
    private func cleanupYouTubeTempFiles(videoPath: String, audioPath: String) {
        print("🧹 Phase 4: Cleaning up temp files...")
        
        let filesToDelete = [videoPath, audioPath].filter { !$0.isEmpty }
        
        for filePath in filesToDelete {
            if FileManager.default.fileExists(atPath: filePath) {
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                    print("🗑️ Deleted temp file: \(filePath)")
                } catch {
                    print("⚠️ Failed to delete temp file \(filePath): \(error)")
                }
            }
            
            // حذف ملفات aria2c الجزئية أيضاً
            let aria2File = filePath + ".aria2"
            if FileManager.default.fileExists(atPath: aria2File) {
                do {
                    try FileManager.default.removeItem(atPath: aria2File)
                    print("🗑️ Deleted aria2 temp file: \(aria2File)")
                } catch {
                    print("⚠️ Failed to delete aria2 temp file \(aria2File): \(error)")
                }
            }
        }
    }
    
    // MARK: - Cleanup YouTube Temp Directory
    private func cleanupYouTubeTempDirectory() {
        let tempDir = NSTemporaryDirectory()
        let tempDownloadDir = "\(tempDir)SafarGet_YouTube_Separate"
        
        if FileManager.default.fileExists(atPath: tempDownloadDir) {
            do {
                try FileManager.default.removeItem(atPath: tempDownloadDir)
                print("🗑️ Deleted temp directory: \(tempDownloadDir)")
            } catch {
                print("⚠️ Failed to delete temp directory \(tempDownloadDir): \(error)")
            }
        }
    }
    
    // MARK: - Resume Support for Separate Method
    func resumeYouTubeDownloadSeparate(for item: DownloadItem) {
        print("🔄 Resuming YouTube download with separate method...")
        
        // ✅ إعداد نظام تتبع السرعة للاستئناف
        RealTimeSpeedTracker.shared.reset(for: item.id)
        RealTimeSpeedTracker.shared.markAsResuming(for: item.id)
        
        // التحقق من وجود ملفات جزئية
        let tempDir = NSTemporaryDirectory()
        let tempDownloadDir = "\(tempDir)SafarGet_YouTube_Separate"
        let videoTempPath = "\(tempDownloadDir)/video_temp.mp4"
        let audioTempPath = "\(tempDownloadDir)/audio_temp.m4a"
        
        // التحقق من وجود ملفات جزئية
        let hasVideoPartial = FileManager.default.fileExists(atPath: videoTempPath + ".aria2")
        let hasAudioPartial = FileManager.default.fileExists(atPath: audioTempPath + ".aria2")
        let hasVideoComplete = FileManager.default.fileExists(atPath: videoTempPath)
        let hasAudioComplete = FileManager.default.fileExists(atPath: audioTempPath)
        
        if hasVideoPartial || hasAudioPartial || hasVideoComplete || hasAudioComplete {
            print("🔄 Found partial/complete files, attempting resume...")
            
            // تحديث الحالة مع تتبع السرعة
            DispatchQueue.main.async {
                item.downloadSpeed = "Resuming..."
                item.isResuming = true
                item.instantSpeed = 0
                item.remainingTime = "--:--"
                self.objectWillChange.send()
            }
            
            // إعادة استخراج الروابط والاستئناف
            startYouTubeDownloadSeparate(for: item)
        } else {
            // لا توجد ملفات جزئية، ابدأ من جديد
            print("🆕 No partial files found, starting fresh...")
            startYouTubeDownloadSeparate(for: item)
        }
    }
    
    // MARK: - Cancel YouTube Download
    func cancelYouTubeDownload(for item: DownloadItem) {
        print("❌ Cancelling YouTube download: \(item.fileName)")
        
        // إيقاف العملية الحالية
        if let process = item.processTask, process.isRunning {
            process.terminate()
            
            // انتظار قصير ثم إرسال SIGKILL إذا لزم الأمر
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if process.isRunning {
                    print("⚠️ Process still running, sending SIGKILL")
                    kill(process.processIdentifier, SIGKILL)
                }
            }
        }
        
        // تحديث الحالة
        item.status = .cancelled
        item.downloadSpeed = "Cancelled"
        item.remainingTime = "--:--"
        
        // تنظيف الملفات المؤقتة
        let tempDir = NSTemporaryDirectory()
        let tempDownloadDir = "\(tempDir)SafarGet_YouTube_Separate"
        let videoTempPath = "\(tempDownloadDir)/video_temp.mp4"
        let audioTempPath = "\(tempDownloadDir)/audio_temp.m4a"
        
        self.cleanupYouTubeTempFiles(videoPath: videoTempPath, audioPath: audioTempPath)
        
        DispatchQueue.main.async {
            // تحديث الحالة فقط
            item.status = .cancelled
            item.downloadSpeed = "Cancelled"
            item.remainingTime = "--:--"
        }
    }
}
