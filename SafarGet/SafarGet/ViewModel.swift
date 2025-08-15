//
//  ViewModel.swift
//  SafarGet
//
//  Created by Kimi on 27/07/2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models
struct AppSettings: Codable {
    var launchAtStartup: Bool = false
    var language: String = "English"
    var showInMenuBar: Bool = true
    var ytDlpPath: String
    var aria2Path: String
    var cookiesPath: String? = nil
    
    init() {
        #if arch(arm64)
        ytDlpPath = "/opt/homebrew/bin/yt-dlp"
        aria2Path = "/opt/homebrew/bin/aria2c"
        #else
        ytDlpPath = "/usr/local/bin/yt-dlp"
        aria2Path = "/usr/local/bin/aria2c"
        #endif
    }
}

struct Category: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    
    static let all = [
        Category(id: "all", title: NSLocalizedString("All Downloads", comment: "All downloads category"), icon: "square.stack.3d.up.fill", color: Color.orange),
        Category(id: "downloading", title: NSLocalizedString("Downloading", comment: "Downloading category"), icon: "arrow.down.circle.fill", color: Color.green),
        Category(id: "completed", title: NSLocalizedString("Completed", comment: "Completed category"), icon: "checkmark.circle.fill", color: Color.blue),
        Category(id: "video", title: NSLocalizedString("Video", comment: "Video category"), icon: "play.rectangle.fill", color: Color.red),
        Category(id: "document", title: NSLocalizedString("Document", comment: "Document category"), icon: "doc.fill", color: Color.orange),
        Category(id: "music", title: NSLocalizedString("Music", comment: "Music category"), icon: "music.note", color: Color.purple),
        Category(id: "program", title: NSLocalizedString("Program", comment: "Program category"), icon: "desktopcomputer", color: Color.teal),
        Category(id: "torrent", title: NSLocalizedString("Torrent", comment: "Torrent category"), icon: "arrow.down.circle.fill", color: Color.yellow)
    ]
}

// MARK: - Safari Extension Manager
class SafariExtensionManager {
    static let shared = SafariExtensionManager()
    
    func openSafariExtensionPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preferences.extensions?id=com.SafarGet.extension")!)
    }
}

// MARK: - Safari Extension Communicator
class SafariExtensionCommunicator {
    static let shared = SafariExtensionCommunicator()
    private weak var viewModel: DownloadManagerViewModel?
    
    func setViewModel(_ viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
    }
    
    func sendDownloadRequest(url: String, fileName: String) {
        viewModel?.addDownload(
            url: url,
            fileName: fileName,
            fileType: .other,
            savePath: "~/Downloads",
            chunks: 16,
            cookiesPath: nil
        )
    }
}

// MARK: - Storage Manager
class StorageManager {
    static let shared = StorageManager()
    private let downloadsKey = "downloadItems"
    private let settingsKey = "appSettings"
    
    func saveDownloads(_ items: [DownloadItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: downloadsKey)
        }
    }
    
    func loadDownloads() -> [DownloadItem] {
        if let data = UserDefaults.standard.data(forKey: downloadsKey) {
            let decoder = JSONDecoder()
            if let items = try? decoder.decode([DownloadItem].self, from: data) {
                return items
            }
        }
        return []
    }
    
    func saveSettings(_ settings: AppSettings) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func loadSettings() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: settingsKey) {
            let decoder = JSONDecoder()
            if let settings = try? decoder.decode(AppSettings.self, from: data) {
                return settings
            }
        }
        return AppSettings()
    }
}

// MARK: - Main View Model
class DownloadManagerViewModel: NSObject, ObservableObject {
    @Published var downloads: [DownloadItem] = []
    @Published var showAddDownload = false
    @Published var showYouTubeDownload = false
    @Published var showSettings = false
    @Published var selectedDownload: DownloadItem?
    @Published var searchText = ""
    @Published var currentTorrentInfo: TorrentInfo?
    @Published var selectedCategory = "all"
    @Published var downloadSpeed: Double = 0
    @Published var settings = AppSettings()
    @Published var showTorrentFiles = false
    @Published var currentTorrentFiles: [TorrentFile] = []
    @Published var pendingTorrentURL: String = ""
    @Published var showDiskAccessAlert = false
    @Published var hasFullDiskAccess = true
    @Published var firstLaunch = true
    @Published var selectedDownloadIDs: Set<UUID> = []
    @Published var showSafariExtensionWindow = false
    
    // New properties for WebSocket integration
    @Published var pendingURL: String = ""
    @Published var pendingFileName: String = ""
    private var webSocketServer: SafarGetWebSocketServer?
    
    // Speed manager
    private var downloadSpeedTrackers: [UUID: (lastSize: Int64, lastTime: Date, speedSamples: [Double])] = [:]
    
    // Notification manager
    let notificationManager = NotificationManager.shared
    
    private let storageManager = StorageManager.shared
    private var speedUpdateTimer: Timer?
    
    var environmentSetup = false
    
    // MARK: - Torrent Models
    struct TorrentInfo: Codable, Identifiable {
        var id = UUID()
        let name: String
        var peersCount: Int
        var seedsCount: Int
        let totalSize: Int64
        let filesCount: Int
        var dhtNodes: Int = 0
        var announceList: [String] = []
        var comment: String = ""
        var creationDate: Date?
        
        init(name: String, peersCount: Int, seedsCount: Int, totalSize: Int64, filesCount: Int) {
            self.name = name
            self.peersCount = peersCount
            self.seedsCount = seedsCount
            self.totalSize = totalSize
            self.filesCount = filesCount
        }
        
        private enum CodingKeys: String, CodingKey {
            case name, peersCount, seedsCount, totalSize, filesCount
            case dhtNodes, announceList, comment, creationDate
        }
    }
    
    struct TorrentFile: Codable, Identifiable {
        var id = UUID()
        let index: Int
        let name: String
        let size: Int64
        var isSelected: Bool
        let path: String
        var downloadProgress: Double = 0.0
        var priority: TorrentFilePriority = .normal
        
        enum TorrentFilePriority: String, Codable, CaseIterable {
            case skip = "skip"
            case low = "low"
            case normal = "normal"
            case high = "high"
            
            var displayName: String {
                switch self {
                case .skip: return "Skip"
                case .low: return "Low"
                case .normal: return "Normal"
                case .high: return "High"
                }
            }
            
            var aria2Value: String {
                switch self {
                case .skip: return "0"
                case .low: return "1"
                case .normal: return "16"
                case .high: return "32"
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case index, name, size, isSelected, path
            case downloadProgress, priority
        }
    }
    
    var filteredDownloads: [DownloadItem] {
        var filtered = downloads
        
        // فلترة حسب الفئة
        switch selectedCategory {
        case "downloading":
            filtered = filtered.filter { $0.status == .downloading || $0.status == .paused }
        case "completed":
            filtered = filtered.filter { $0.status == .completed }
        case "failed":
            filtered = filtered.filter { $0.status == .failed }
        case "video":
            filtered = filtered.filter { $0.fileType == .video }
        case "document":
            filtered = filtered.filter { $0.fileType == .document }
        case "music":
            filtered = filtered.filter { $0.fileType == .audio }
        case "program":
            filtered = filtered.filter { $0.fileType == .executable }
        case "torrent":
            filtered = filtered.filter { $0.fileType == .torrent }
        default:
            break
        }
        
        // فلترة حسب البحث
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // ترتيب: الملفات النشطة أولاً، ثم حسب التاريخ
        filtered.sort { item1, item2 in
            // الملفات قيد التحميل أولاً
            if item1.status == .downloading && item2.status != .downloading {
                return true
            } else if item1.status != .downloading && item2.status == .downloading {
                return false
            }
            // ثم الملفات المتوقفة مؤقتاً
            else if item1.status == .paused && item2.status != .paused && item2.status != .downloading {
                return true
            } else if item1.status != .paused && item2.status == .paused && item1.status != .downloading {
                return false
            }
            // باقي الملفات حسب الترتيب الأصلي
            else {
                return false
            }
        }
        
        return filtered
    }
    
    // MARK: - Helper function for bundled executables
    private func getBundledExecutablePath(name: String) -> String? {
        // البحث في Resources مباشرة أولاً (Xcode يضع الملفات هنا)
        if let path = Bundle.main.path(forResource: name, ofType: nil) {
            if FileManager.default.fileExists(atPath: path) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        return path
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let supportDir = getSupportDirectory() {
                    let writablePath = (supportDir as NSString).appendingPathComponent(name)
                    
                    if !FileManager.default.fileExists(atPath: writablePath) {
                        do {
                            try FileManager.default.copyItem(atPath: path, toPath: writablePath)
                            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                            print("✅ Copied \(name) to writable location: \(writablePath)")
                            return writablePath
                        } catch {
                            print("❌ Failed to copy \(name) to writable location: \(error)")
                        }
                    } else {
                        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                        return writablePath
                    }
                }
            }
        }
        
        // البحث في Scripts داخل Resources (للتوافق مع الإعداد السابق)
        if let path = Bundle.main.path(forResource: name, ofType: nil, inDirectory: "Scripts") {
            if FileManager.default.fileExists(atPath: path) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        return path
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let supportDir = getSupportDirectory() {
                    let writablePath = (supportDir as NSString).appendingPathComponent(name)
                    
                    if !FileManager.default.fileExists(atPath: writablePath) {
                        do {
                            try FileManager.default.copyItem(atPath: path, toPath: writablePath)
                            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                            print("✅ Copied \(name) to writable location: \(writablePath)")
                            return writablePath
                        } catch {
                            print("❌ Failed to copy \(name) to writable location: \(error)")
                        }
                    } else {
                        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                        return writablePath
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkFullDiskAccess()
        startSpeedUpdateTimer()
        loadDownloads()
        loadSettings()
        checkRequirements()
        setupTerminationObserver()
        setupExtensionCommunication()
        setupNotificationObservers()
        setupNetworkObservers()
        optimizeSystemForDownloads()
        
            // Start WebSocket server for Chrome extension
    webSocketServer = SafarGetWebSocketServer(viewModel: self)
    webSocketServer?.start()
    
    // Setup Safari Extension communicator
    SafariExtensionCommunicator.shared.setViewModel(self)
    
    // Start XPC Service for Native Messaging
    // SafarGetXPCServiceManager.shared.startService(viewModel: self)
    
    // Start Native Messaging Host
    SafarGetNativeMessagingHostManager.shared.startHost(viewModel: self)
        
        // Start stuck download checker
        startStuckDownloadChecker()
        
        // Setup menu bar status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let self = self {
                MenuBarStatus.shared.setup(with: self)
            }
        }
        
        // Check for stuck downloads after loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkStuckDownloads()
        }
    }
    
    deinit {
        speedUpdateTimer?.invalidate()
        terminateAllProcesses()
        webSocketServer?.stop()
        // SafarGetXPCServiceManager.shared.stopService()
        SafarGetNativeMessagingHostManager.shared.stopHost()
    }
    
    private func checkRequirements() {
        // التحقق من aria2c في bundle التطبيق فقط
        if let bundledAria2Path = getBundledExecutablePath(name: "aria2c") {
            settings.aria2Path = bundledAria2Path
            print("✅ aria2c found in bundle at: \(bundledAria2Path)")
            
            // اختبار aria2c المدمج
            verifyBundledAria2c()
        } else {
            print("❌ aria2c not found in bundle")
        }
        
        // التحقق من yt-dlp في bundle التطبيق فقط
        if let bundledYtDlpPath = getBundledExecutablePath(name: "yt-dlp") {
            settings.ytDlpPath = bundledYtDlpPath
            print("✅ yt-dlp found in bundle at: \(bundledYtDlpPath)")
        } else {
            print("❌ yt-dlp not found in bundle - YouTube downloads will not work")
        }
    }
    
    private func optimizeSystemForDownloads() {
        // زيادة حد الاتصالات المتزامنة
        URLSession.shared.configuration.httpMaximumConnectionsPerHost = 100
        
        // إعطاء التطبيق أولوية عالية
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
            reason: "Maximum performance downloads"
        )
        
        // تعيين QoS عالي للعمليات
        DispatchQueue.global(qos: .userInteractive).async {
            Thread.current.qualityOfService = .userInteractive
        }
        
        // الاحتفاظ بالنشاط
        DispatchQueue.main.async {
            _ = activity
        }
    }
    
    // MARK: - Selection Management
    func toggleSelection(_ id: UUID) {
        if selectedDownloadIDs.contains(id) {
            selectedDownloadIDs.remove(id)
        } else {
            selectedDownloadIDs.insert(id)
        }
        print("Toggled selection for \(id). Current selection: \(selectedDownloadIDs)")
    }
    
    func selectAll() {
        selectedDownloadIDs = Set(filteredDownloads.map { $0.id })
        print("Selected all downloads: \(selectedDownloadIDs)")
    }
    
    func deselectAll() {
        selectedDownloadIDs.removeAll()
        print("Deselected all downloads")
    }
    
    // MARK: - Setup Notification Observers
    private func setupNotificationObservers() {
        // مراقبة طلبات التحميل الجديدة
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewDownloadNotification(_:)),
            name: .newDownload,
            object: nil
        )
        
        // مراقبة طلبات تحميل YouTube
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleYouTubeDownloadNotification(_:)),
            name: .youtubeDownloadRequest,
            object: nil
        )
        
        // مراقبة طلبات App Groups من Safari Extension
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPendingDownloads()
        }
    }
    
    // MARK: - Network Connection Handlers
    private func setupNetworkObservers() {
        // مراقبة انقطاع الإنترنت
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInternetDisconnected(_:)),
            name: .internetDisconnected,
            object: nil
        )
        
        // مراقبة عودة الإنترنت
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInternetReconnected(_:)),
            name: .internetReconnected,
            object: nil
        )
    }
    
    @objc private func handleInternetDisconnected(_ notification: Notification) {
        print("📵 Internet disconnected - handling active downloads...")
        
        for download in downloads where download.status == .downloading {
            // حفظ التحميلات النشطة
            NetworkMonitor.shared.storePausedDownload(download.id)
            
            // حفظ آخر سرعة وتقدم قبل الانقطاع
            download.lastSpeedBeforeDisconnect = download.instantSpeed
            download.lastProgressBeforeDisconnect = download.progress
            download.disconnectTime = Date()
            
            // تحديث الحالة مع الاحتفاظ بالعملية
            DispatchQueue.main.async {
                // إيقاف السرعة فوراً
                download.instantSpeed = 0
                download.downloadSpeed = "No Connection - Auto-resume when back"
                download.remainingTime = "--:--"
                
                // الاحتفاظ بحالة التحميل كـ downloading
                // aria2 سيستمر في المحاولة تلقائياً بسبب --max-tries=0
                
                self.objectWillChange.send()
            }
            
            // للتورنت: aria2 سيستمر في المحاولة تلقائياً
            if download.isTorrent {
                print("🔗 Torrent download will auto-resume when connection returns: \(download.fileName)")
            }
        }
    }
    
    @objc private func handleInternetReconnected(_ notification: Notification) {
        print("📶 Internet reconnected!")
        
        // انتظار قليلاً للتأكد من استقرار الاتصال
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            print("🔄 Checking downloads to resume...")
            
            // استئناف التحميلات التي كانت نشطة
            if let pausedDownloads = notification.userInfo?["resumeDownloads"] as? Set<UUID> {
                for downloadId in pausedDownloads {
                    if let download = self.downloads.first(where: { $0.id == downloadId }) {
                        // التحقق من أن التحميل كان نشطاً ولم يتم إيقافه يدوياً
                        if download.status == .downloading && !download.wasManuallyPaused {
                            print("✅ Auto-resuming: \(download.fileName)")
                            
                            // وضع علامة الاستئناف لتجنب قراءات السرعة الخاطئة
                            RealTimeSpeedTracker.shared.markAsResuming(for: download.id)
                            
                            // تحديث الحالة
                            download.downloadSpeed = "Reconnecting..."
                            download.instantSpeed = 0
                            
                            // للتورنت: aria2 سيستأنف تلقائياً
                            if download.isTorrent {
                                print("🔗 Torrent auto-resuming: \(download.fileName)")
                                download.downloadSpeed = "Torrent reconnecting..."
                            }
                            
                            self.objectWillChange.send()
                        }
                    }
                }
            }
            
            // تحديث جميع التحميلات النشطة
            for download in self.downloads where download.status == .downloading {
                if !download.wasManuallyPaused {
                    RealTimeSpeedTracker.shared.markAsResuming(for: download.id)
                    
                    // للتورنت: aria2 سيستأنف تلقائياً
                    if download.isTorrent {
                        download.downloadSpeed = "Torrent reconnecting..."
                        print("🔗 Torrent will auto-resume: \(download.fileName)")
                    } else {
                        download.downloadSpeed = "Reconnecting..."
                    }
                    download.instantSpeed = 0
                }
            }
            
            self.objectWillChange.send()
            
            // إرسال إشعار للمستخدم
            self.notificationManager.sendCustomNotification(
                title: "Internet Restored",
                body: "Downloads will resume automatically"
            )
        }
    }
    
    @objc private func handleNewDownloadNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? String else { return }
        
        let fileName = userInfo["fileName"] as? String ?? extractFileName(from: url)
        _ = userInfo["source"] as? String ?? "unknown"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // تعيين البيانات المؤقتة
            self.pendingURL = url
            self.pendingFileName = fileName
            
            // فتح نافذة Quick Download دائماً
            QuickDownloadWindowController.shared.show(with: self)
        }
    }
    
    @objc func handleYouTubeDownloadNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? String,
              let title = userInfo["title"] as? String,
              let quality = userInfo["quality"] as? String else {
            return
        }
        
        let headers = userInfo["headers"] as? [String: String] ?? [:]
        
        // تحسين الجودة المختارة
        let optimizedQuality = translateQualityToYtDlpFormat(quality)
        print("🎬 Quality optimization in ViewModel: '\(quality)' -> '\(optimizedQuality)'")
        print("🔍 Debug: Received title = '\(title)'")
        print("🔍 Debug: Received url = '\(url)'")
        
        // طباعة تفصيلية للـ headers المستلمة
        print("📋 Headers received in ViewModel:")
        for (key, value) in headers {
            if key.lowercased() == "cookie" {
                print("  \(key): \(String(value.prefix(50)))...")
            } else {
                print("  \(key): \(value)")
            }
        }
        
        // إضافة تحميل YouTube مع headers
        addYouTubeDownloadWithHeaders(url: url, title: title, quality: optimizedQuality, headers: headers)
    }
    
    // MARK: - Quality Translation Function
    private func translateQualityToYtDlpFormat(_ quality: String) -> String {
        let q = quality.lowercased()
        func fmt(_ h: Int) -> String {
            return "bestvideo[height<=\(h)][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]"
        }
        switch q {
        case "4k", "2160p", "uhd": return fmt(2160)
        case "1440p", "2k": return fmt(1440)
        case "1080p", "full hd", "fhd": return fmt(1080)
        case "720p", "hd": return fmt(720)
        case "480p": return fmt(480)
        case "360p": return fmt(360)
        case "240p": return fmt(240)
        case "144p": return fmt(144)
        case "best", "أفضل جودة", "meilleure qualité":
            return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best"
        case "worst", "أسوأ جودة", "pire qualité":
            return "worst"
        default:
            return quality
        }
    }
    
    // MARK: - YouTube Download with Auto-numbering
    func addYouTubeDownload(url: String, title: String, quality: String) {
        print("📥 Adding YouTube download: \(title) [\(quality)]")
        
        // تحسين الجودة المختارة
        let optimizedQuality = translateQualityToYtDlpFormat(quality)
        print("🎬 Quality optimization: '\(quality)' -> '\(optimizedQuality)'")
        
        // إنشاء اسم الملف مع نظام الترقيم التلقائي
        let fileName = generateUniqueYouTubeFileName(title: title, quality: quality)
        
        let newDownload = DownloadItem(
            fileName: fileName,
            url: url,
            fileSize: 0,
            fileType: .video
        )
        newDownload.savePath = "~/Downloads"
        newDownload.chunks = 1
        newDownload.isYouTubeVideo = true
        newDownload.videoQuality = quality
        newDownload.videoFormat = optimizedQuality
        newDownload.actualVideoTitle = title
        
        print("🔍 Debug: Set videoFormat = '\(optimizedQuality)'")
        print("🔍 Debug: Set videoQuality = '\(quality)'")
        
        downloads.insert(newDownload, at: 0)
        saveDownloads()
        startDownload(for: newDownload)
    }
    
    // MARK: - Generate Unique YouTube Filename
    private func generateUniqueYouTubeFileName(title: String, quality: String) -> String {
        let sanitizedTitle = sanitizeFileName(title)
        let qualityLabel = getQualityLabel(from: quality, isAudio: false)
        let savePath = expandTildePath("~/Downloads")
        
        // إنشاء اسم الملف الأساسي
        let baseFileName = "\(sanitizedTitle)_ [\(qualityLabel)]"
        var fileName = "\(baseFileName).mp4"
        
        // التحقق من وجود ملف بنفس الاسم في النظام
        var counter = 1
        while FileManager.default.fileExists(atPath: "\(savePath)/\(fileName)") {
            fileName = "\(baseFileName)_\(counter).mp4"
            counter += 1
        }
        
        // التحقق من وجود تحميل بنفس الاسم في قائمة التحميلات
        counter = 1
        while downloads.contains(where: { $0.fileName == fileName && $0.savePath == "~/Downloads" }) {
            fileName = "\(baseFileName)_\(counter).mp4"
            counter += 1
        }
        
        print("📝 Generated unique filename: \(fileName)")
        return fileName
    }
    
    private func checkPendingDownloads() {
        // التحقق من App Groups للتحميلات من Safari Extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.safarget.downloads"),
           let pendingDownloads = sharedDefaults.array(forKey: "pendingDownloads") as? [[String: Any]],
           !pendingDownloads.isEmpty {
            
            print("📥 Found \(pendingDownloads.count) pending downloads from Safari Extension")
            
            // معالجة التحميلات المعلقة
            for downloadInfo in pendingDownloads {
                if let isYouTube = downloadInfo["isYouTube"] as? Bool, isYouTube {
                    // معالجة تحميل YouTube
                    if let url = downloadInfo["url"] as? String,
                       let title = downloadInfo["title"] as? String,
                       let quality = downloadInfo["quality"] as? String {
                        
                        print("📥 Processing YouTube download: \(title)")
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let _ = self else { return }
                            
                            // إرسال إشعار لمعالجة تحميل YouTube
                            NotificationCenter.default.post(
                                name: .youtubeDownloadRequest,
                                object: nil,
                                userInfo: [
                                    "url": url,
                                    "title": title,
                                    "quality": quality,
                                    "source": "safari_extension"
                                ]
                            )
                        }
                    }
                } else {
                    // معالجة التحميلات العادية مع النظام الذكي الجديد
                    if let url = downloadInfo["url"] as? String,
                       let fileName = downloadInfo["fileName"] as? String {
                        
                        print("🚀 Processing smart download: \(fileName)")
                        
                        // تحليل المعلومات الذكية
                        let detectionMethod = downloadInfo["detectionMethod"] as? String ?? "unknown"
                        let hasRedirects = downloadInfo["hasRedirects"] as? Bool ?? false
                        let isIntermediatePage = downloadInfo["isIntermediatePage"] as? Bool ?? false
                        
                        print("📊 Smart Analysis:")
                        print("   Detection Method: \(detectionMethod)")
                        print("   Has Redirects: \(hasRedirects)")
                        print("   Is Intermediate Page: \(isIntermediatePage)")
                        
                        // استخدام النظام الذكي للتحميل إذا كان متاحاً
                        if detectionMethod == "smart_analysis" && hasRedirects {
                            print("🧠 Using smart download system for URL with redirects")
                            startSmartDownload(url: url, fileName: fileName, downloadInfo: downloadInfo)
                        } else {
                            // استخدام النظام العادي
                            print("📥 Using standard download system")
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                self.pendingURL = url
                                self.pendingFileName = fileName
                                QuickDownloadWindowController.shared.show(with: self)
                            }
                        }
                    }
                }
                
                // معالجة تحميل واحد فقط في كل مرة
                break
            }
            
            // مسح التحميل الأول من القائمة
            var updatedDownloads = pendingDownloads
            if !updatedDownloads.isEmpty {
                updatedDownloads.removeFirst()
                sharedDefaults.set(updatedDownloads, forKey: "pendingDownloads")
                sharedDefaults.synchronize()
            }
        }
    }
    
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "download" }
        let fileName = url.lastPathComponent
        return fileName.isEmpty ? "download" : fileName
    }
    
    // MARK: - Setup Termination Observer
    private func setupTerminationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        print("🛑 SafarGet will terminate - stopping all processes...")
        webSocketServer?.stop()
        terminateAllProcesses()
        saveDownloads()
        saveSettings()
    }
    
    @objc private func applicationDidResignActive() {}
    
    // MARK: - Terminate All Processes
    func terminateAllProcesses() {
        print("⚠️ Stopping all download processes...")
        
        for download in downloads {
            if let process = download.processTask, process.isRunning {
                print("🛑 Stopping process: \(download.fileName)")
                
                process.interrupt()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if process.isRunning {
                        process.terminate()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if process.isRunning {
                                let pid = process.processIdentifier
                                let killProcess = Process()
                                killProcess.launchPath = "/bin/kill"
                                killProcess.arguments = ["-9", "\(pid)"]
                                try? killProcess.run()
                            }
                        }
                    }
                }
                
                if download.status == .downloading {
                    download.status = .paused
                    download.wasManuallyPaused = false
                }
            }
        }
        
        killOrphanProcesses()
    }
    
    // MARK: - Kill Orphan Processes
    private func killOrphanProcesses() {
        let killAxel = Process()
        killAxel.launchPath = "/usr/bin/killall"
        killAxel.arguments = ["axel"]
        try? killAxel.run()
        
        let killYtDlp = Process()
        killYtDlp.launchPath = "/usr/bin/killall"
        killYtDlp.arguments = ["yt-dlp"]
        try? killYtDlp.run()
        
        print("✅ All orphan processes cleaned")
    }
    
    func saveDownloads() {
        storageManager.saveDownloads(downloads)
        print("💾 Downloads saved")
    }
    
    func loadDownloads() {
        downloads = storageManager.loadDownloads()
        print("💾 Loaded \(downloads.count) downloads")
        
        for download in downloads {
            download.processTask = nil
        }
        
        for download in downloads where download.status == .downloading && !download.wasManuallyPaused {
            download.status = .waiting
            startDownload(for: download, isAutoResume: true)
        }
    }
    
    func saveSettings() {
        storageManager.saveSettings(settings)
        print("💾 Settings saved")
    }
    
    func loadSettings() {
        settings = storageManager.loadSettings()
        print("💾 Settings loaded")
    }
    
    // MARK: - Speed Update Timer
    private func startSpeedUpdateTimer() {
        speedUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let activeDownloads = self.downloads.filter { $0.status == .downloading }
            
            for download in activeDownloads {
                // تحديث السرعة من RealTimeSpeedTracker
                let speedResult = RealTimeSpeedTracker.shared.updateSpeed(
                    for: download.id,
                    currentBytes: download.downloadedSize,
                    totalBytes: download.fileSize
                )
                
                if speedResult.speed > 0 {
                    // تحديث الحالة إلى "Downloading" إذا كانت هناك سرعة
                    if download.downloadSpeed.contains("Starting") || 
                       download.downloadSpeed.contains("Resuming") || 
                       download.downloadSpeed.contains("Connecting") {
                        download.downloadSpeed = "Downloading..."
                    }
                    
                    download.updateSpeed(speedResult.speed, displaySpeed: "Downloading...")
                    download.remainingTime = speedResult.remainingTime
                }
            }
            
            // تحديث UI
            if !activeDownloads.isEmpty {
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
        }
        
        RunLoop.main.add(speedUpdateTimer!, forMode: .common)
    }
    
    // MARK: - Update All Speeds
    private func updateAllSpeeds() {
        let activeDownloads = downloads.filter { $0.status == .downloading }
        guard !activeDownloads.isEmpty else { return }
        
        for download in activeDownloads {
            // تحديث السرعة باستخدام RealTimeSpeedTracker
            let speedResult = RealTimeSpeedTracker.shared.updateSpeed(
                for: download.id,
                currentBytes: download.downloadedSize,
                totalBytes: download.fileSize
            )
            
            DispatchQueue.main.async {
                // تحديث السرعة اللحظية
                if speedResult.speed > 0 {
                    download.instantSpeed = speedResult.speed
                    download.downloadSpeed = speedResult.displaySpeed
                    download.remainingTime = speedResult.remainingTime
                    
                    // تحديث السرعة القصوى
                    if speedResult.speed > download.maxSpeed {
                        download.maxSpeed = speedResult.speed
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    func formatSpeedMB(_ bytesPerSecond: Double) -> String {
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
    
    func formatTime(_ seconds: Double) -> String {
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
    
    func checkFullDiskAccess() {
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
        let fileManager = FileManager.default
        
        if let downloadsPath = downloadsPath {
            do {
                _ = try fileManager.contentsOfDirectory(atPath: downloadsPath)
                hasFullDiskAccess = true
            } catch {
                hasFullDiskAccess = false
                if firstLaunch {
                    showDiskAccessAlert = true
                    firstLaunch = false
                }
            }
        } else {
            hasFullDiskAccess = false
        }
    }
    
    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
    
    func pauseAll() {
        for download in downloads {
            if download.status == .downloading {
                pauseDownload(download)
            }
        }
    }
    
    func resumeAll() {
        for download in downloads {
            if download.status == .paused {
                resumeDownload(download)
            }
        }
    }
    
    // MARK: - Bulk Delete Operations
    func deleteSelectedDownloads() {
        let idsToDelete = selectedDownloadIDs
        
        for id in idsToDelete {
            if let download = downloads.first(where: { $0.id == id }) {
                terminateDownloadProcess(download)
                
                // حذف الملفات المؤقتة والغير مكتملة فقط
                // لا نحذف الملفات المكتملة من الجهاز
                if download.status == .completed {
                    // للملفات المكتملة: نحذف فقط الملفات المؤقتة
                    cleanupTempFilesOnly(for: download)
                } else {
                    // للملفات غير المكتملة: نحذف الملفات المؤقتة والغير مكتملة
                    cleanupIncompleteDownloadFiles(for: download)
                }
            }
        }
        
        downloads.removeAll { idsToDelete.contains($0.id) }
        selectedDownloadIDs.removeAll()
        saveDownloads()
    }
    
    func deleteCompletedDownloads() {
        for download in downloads where download.status == .completed {
            terminateDownloadProcess(download)
            // للملفات المكتملة: نحذف فقط الملفات المؤقتة
            // لا نحذف الملف المكتمل من الجهاز
            cleanupTempFilesOnly(for: download)
        }
        
        downloads.removeAll { $0.status == .completed }
        selectedDownloadIDs.removeAll()
        saveDownloads()
    }
    
    func deleteIncompleteDownloads() {
        for download in downloads where download.status != .completed {
            terminateDownloadProcess(download)
            // حذف الملفات المؤقتة والغير مكتملة
            cleanupIncompleteDownloadFiles(for: download)
        }
        
        downloads.removeAll { $0.status != .completed }
        selectedDownloadIDs.removeAll()
        saveDownloads()
    }
    
    func deleteAllDownloads() {
        for download in downloads {
            terminateDownloadProcess(download)
            
            // حذف الملفات المؤقتة والغير مكتملة فقط
            // لا نحذف الملفات المكتملة من الجهاز
            if download.status == .completed {
                // للملفات المكتملة: نحذف فقط الملفات المؤقتة
                cleanupTempFilesOnly(for: download)
            } else {
                // للملفات غير المكتملة: نحذف الملفات المؤقتة والغير مكتملة
                cleanupIncompleteDownloadFiles(for: download)
            }
        }
        
        downloads.removeAll()
        selectedDownloadIDs.removeAll()
        saveDownloads()
    }
    
    // MARK: - Download File Management
    func createHiddenDownloadFile(for item: DownloadItem) {
        // إنشاء ملف مخفي في مجلد التحميل لإظهار أن التحميل قيد التقدم
        let expandedPath = expandTildePath(item.savePath)
        let hiddenFileName = ".\(item.fileName).downloading"
        let hiddenFilePath = "\(expandedPath)/\(hiddenFileName)"
        
        do {
            // إنشاء ملف مخفي فارغ
            try "".write(toFile: hiddenFilePath, atomically: true, encoding: .utf8)
            print("📝 Created hidden download file: \(hiddenFileName)")
        } catch {
            print("⚠️ Failed to create hidden download file: \(error)")
        }
    }
    
    func removeHiddenDownloadFile(for item: DownloadItem) {
        // حذف الملف المخفي عند اكتمال التحميل أو إلغائه
        let expandedPath = expandTildePath(item.savePath)
        let hiddenFileName = ".\(item.fileName).downloading"
        let hiddenFilePath = "\(expandedPath)/\(hiddenFileName)"
        
        if FileManager.default.fileExists(atPath: hiddenFilePath) {
            do {
                try FileManager.default.removeItem(atPath: hiddenFilePath)
                print("🗑️ Removed hidden download file: \(hiddenFileName)")
            } catch {
                print("⚠️ Failed to remove hidden download file: \(error)")
            }
        }
    }
    
    // MARK: - Delete Completed File from Device
    func deleteCompletedFileFromDevice(for item: DownloadItem) {
        print("🗑️ Deleting completed file from device: \(item.fileName)")
        
        let expandedPath = expandTildePath(item.savePath)
        let fileManager = FileManager.default
        
        // حذف الملف المكتمل
        let finalFilePath = "\(expandedPath)/\(item.fileName)"
        if fileManager.fileExists(atPath: finalFilePath) {
            do {
                try fileManager.removeItem(atPath: finalFilePath)
                print("✅ Deleted completed file: \(item.fileName)")
            } catch {
                print("⚠️ Failed to delete completed file: \(error)")
            }
        }
        
        // حذف الملفات المؤقتة فقط (بدون حذف الملف النهائي مرة أخرى)
        cleanupTempFilesOnly(for: item)
    }
    
    // MARK: - Cleanup Temp Files Only (without deleting final file)
    func cleanupTempFilesOnly(for item: DownloadItem) {
        print("🧹 Cleaning up temp files only for: \(item.fileName)")
        
        let expandedPath = expandTildePath(item.savePath)
        let fileManager = FileManager.default
        
        // حذف الملفات المؤقتة المحتملة
        let tempFiles = [
            "\(item.fileName).part",
            "\(item.fileName).tmp",
            "\(item.fileName).downloading",
            "\(item.fileName).temp",
            ".\(item.fileName).downloading",  // الملف المخفي
            ".\(item.fileName).tmp",          // temp file (with dot prefix)
            ".st",                            // axel temp file
            ".st~",                           // axel temp file
            ".st.tmp"                         // axel temp file
        ]
        
        // حذف الملفات المؤقتة من مجلد التحميل
        for tempFile in tempFiles {
            let tempFilePath = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
            if fileManager.fileExists(atPath: tempFilePath.path) {
                do {
                    try fileManager.removeItem(at: tempFilePath)
                    print("🗑️ Deleted temp file: \(tempFile)")
                } catch {
                    print("⚠️ Failed to delete temp file \(tempFile): \(error)")
                }
            }
        }
        
        // حذف الملفات من المجلد المؤقت الخاص بـ SafarGet
        let tempDownloadPath = "\(expandedPath)/.safarget_temp"
        let tempFileName = "\(item.fileName).temp"
        let tempFilePath = "\(tempDownloadPath)/\(tempFileName)"
        
        if fileManager.fileExists(atPath: tempFilePath) {
            do {
                try fileManager.removeItem(atPath: tempFilePath)
                print("🗑️ Deleted SafarGet temp file: \(tempFileName)")
            } catch {
                print("⚠️ Failed to delete SafarGet temp file: \(error)")
            }
        }
        
        // حذف ملفات axel المؤقتة
        let axelTempFiles = [
            ".st",
            ".st~",
            ".st.tmp"
        ]
        
        for axelTempFile in axelTempFiles {
            let axelTempFilePath = "\(tempDownloadPath)/\(axelTempFile)"
            if fileManager.fileExists(atPath: axelTempFilePath) {
                do {
                    try fileManager.removeItem(atPath: axelTempFilePath)
                    print("🗑️ Deleted axel temp file: \(axelTempFile)")
                } catch {
                    print("⚠️ Failed to delete axel temp file: \(error)")
                }
            }
        }
        
        // حذف المجلد المؤقت إذا كان فارغاً
        if fileManager.fileExists(atPath: tempDownloadPath) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: tempDownloadPath)
                if contents.isEmpty {
                    try fileManager.removeItem(atPath: tempDownloadPath)
                    print("🗑️ Deleted empty temp directory")
                }
            } catch {
                print("⚠️ Failed to check/delete temp directory: \(error)")
            }
        }
    }
    
    // MARK: - Cleanup Incomplete Download Files
    func cleanupIncompleteDownloadFiles(for item: DownloadItem) {
        print("🧹 Cleaning up incomplete download files for: \(item.fileName)")
        
        let expandedPath = expandTildePath(item.savePath)
        let fileManager = FileManager.default
        
        // حذف الملفات المؤقتة المحتملة
        let tempFiles = [
            "\(item.fileName).part",
            "\(item.fileName).tmp",
            "\(item.fileName).downloading",
            "\(item.fileName).temp",
            ".\(item.fileName).downloading",  // الملف المخفي
            ".\(item.fileName).tmp",          // temp file (with dot prefix)
            ".st",                            // axel temp file
            ".st~",                           // axel temp file
            ".st.tmp"                         // axel temp file
        ]
        
        // حذف الملفات المؤقتة من مجلد التحميل
        for tempFile in tempFiles {
            let tempFilePath = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
            if fileManager.fileExists(atPath: tempFilePath.path) {
                do {
                    try fileManager.removeItem(at: tempFilePath)
                    print("🗑️ Deleted temp file: \(tempFile)")
                } catch {
                    print("⚠️ Failed to delete temp file \(tempFile): \(error)")
                }
            }
        }
        
        // حذف الملفات من المجلد المؤقت الخاص بـ SafarGet
        let tempDownloadPath = "\(expandedPath)/.safarget_temp"
        let tempFileName = "\(item.fileName).temp"
        let tempFilePath = "\(tempDownloadPath)/\(tempFileName)"
        
        if fileManager.fileExists(atPath: tempFilePath) {
            do {
                try fileManager.removeItem(atPath: tempFilePath)
                print("🗑️ Deleted SafarGet temp file: \(tempFileName)")
            } catch {
                print("⚠️ Failed to delete SafarGet temp file: \(error)")
            }
        }
        
        // حذف ملف التحكم aria2
        let controlFile = "\(tempFilePath).aria2"
        if fileManager.fileExists(atPath: controlFile) {
            do {
                try fileManager.removeItem(atPath: controlFile)
                print("🗑️ Deleted aria2 control file")
            } catch {
                print("⚠️ Failed to delete aria2 control file: \(error)")
            }
        }
        
        // حذف ملفات aria2 المؤقتة (مع نقطة في البداية)
        let aria2TempFile = "\(tempDownloadPath)/.\(item.fileName).tmp"
        if fileManager.fileExists(atPath: aria2TempFile) {
            do {
                try fileManager.removeItem(atPath: aria2TempFile)
                print("🗑️ Deleted aria2 temp file: .\(item.fileName).tmp")
            } catch {
                print("⚠️ Failed to delete aria2 temp file: \(error)")
            }
        }
        
        // حذف ملف التحكم aria2 (مع نقطة في البداية)
        let aria2ControlFile = "\(tempDownloadPath)/.\(item.fileName).aria2"
        if fileManager.fileExists(atPath: aria2ControlFile) {
            do {
                try fileManager.removeItem(atPath: aria2ControlFile)
                print("🗑️ Deleted aria2 control file: .\(item.fileName).aria2")
            } catch {
                print("⚠️ Failed to delete aria2 control file: \(error)")
            }
        }
        
        // حذف الملف النهائي إذا كان موجوداً (لإعادة التحميل)
        let finalFilePath = "\(expandedPath)/\(item.fileName)"
        if fileManager.fileExists(atPath: finalFilePath) {
            do {
                try fileManager.removeItem(atPath: finalFilePath)
                print("🗑️ Deleted final file for restart: \(item.fileName)")
            } catch {
                print("⚠️ Failed to delete final file: \(error)")
            }
        }
        
        // حذف المجلد المؤقت إذا كان فارغاً
        if fileManager.fileExists(atPath: tempDownloadPath) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: tempDownloadPath)
                if contents.isEmpty {
                    try fileManager.removeItem(atPath: tempDownloadPath)
                    print("🗑️ Deleted empty temp directory")
                }
            } catch {
                print("⚠️ Failed to check/delete temp directory: \(error)")
            }
        }
    }
    
    // MARK: - Build Safari Extension
    func buildSafariExtension() {
        print("🔨 Building Safari Extension...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            
            // Get the path to the build script
            if let bundlePath = Bundle.main.resourcePath {
                let scriptPath = "\(bundlePath)/../build_extension.sh"
                process.arguments = [scriptPath]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            print("✅ Safari Extension built successfully!")
                            // Show notification
                            self.notificationManager.sendCustomNotification(title: "Safari Extension", body: "Extension built successfully!")
                        } else {
                            print("❌ Failed to build Safari Extension")
                            self.notificationManager.sendCustomNotification(title: "Build Error", body: "Failed to build Safari Extension")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("❌ Error building extension: \(error)")
                        self.notificationManager.sendCustomNotification(title: "Build Error", body: "Error building Safari Extension")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("❌ Could not find bundle path")
                    self.notificationManager.sendCustomNotification(title: "Build Error", body: "Could not find build script")
                }
            }
        }
    }
    
    // MARK: - Clean All Temp Files
    func cleanupAllTempFiles() {
        print("🧹 Cleaning all temp files from Downloads folder")
        
        let downloadsPath = expandTildePath("~/Downloads")
        let fileManager = FileManager.default
        
        // حذف جميع الملفات المؤقتة من مجلد Downloads
        let tempExtensions = [".temp", ".aria2", ".downloading", ".part", ".tmp"]
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: downloadsPath)
            var deletedCount = 0
            
            for file in files {
                for ext in tempExtensions {
                    if file.hasSuffix(ext) || file.hasPrefix(".") && file.hasSuffix(ext) {
                        let filePath = "\(downloadsPath)/\(file)"
                        try fileManager.removeItem(atPath: filePath)
                        print("🗑️ Deleted temp file: \(file)")
                        deletedCount += 1
                        break
                    }
                }
            }
            
            // حذف مجلد .safarget_temp إذا كان موجوداً
            let safargetTempPath = "\(downloadsPath)/.safarget_temp"
            if fileManager.fileExists(atPath: safargetTempPath) {
                try fileManager.removeItem(atPath: safargetTempPath)
                print("🗑️ Deleted .safarget_temp directory")
                deletedCount += 1
            }
            
            print("✅ Cleaned up \(deletedCount) temp files/directories")
            
        } catch {
            print("⚠️ Failed to cleanup temp files: \(error)")
        }
    }
    
    // MARK: - Terminate Single Download Process
    func terminateDownloadProcess(_ item: DownloadItem) {
        if let process = item.processTask {
            if process.isRunning {
                // حفظ الحالة الحالية
                let currentStatus = item.status
                
                // إيقاف العملية
                process.terminate()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                    
                    // المحافظة على الحالة الصحيحة
                    if currentStatus == .paused || item.wasManuallyPaused {
                        item.status = .paused
                    }
                }
            }
            item.processTask = nil
        }
        
        // حذف الملف المخفي عند إيقاف التحميل
        removeHiddenDownloadFile(for: item)
        
        // إزالة حاسبة السرعة عند إيقاف التحميل
        RealTimeSpeedTracker.shared.remove(for: item.id)
    }
    
    func handleDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    guard let urlData = item as? Data,
                          let url = URL(dataRepresentation: urlData, relativeTo: nil) else { return }
                    
                    DispatchQueue.main.async {
                        let filePath = url.path
                        print("📥 Dropped file: \(filePath)")
                        
                        if filePath.lowercased().hasSuffix(".torrent") {
                            self.parseTorrentFile(url: URL(fileURLWithPath: filePath))
                        } else {
                            let fileType = self.detectFileType(from: filePath)
                            self.addDownloadEnhanced(
                                url: filePath,
                                fileName: URL(fileURLWithPath: filePath).lastPathComponent,
                                fileType: fileType,
                                savePath: "~/Downloads",
                                chunks: 16,
                                cookiesPath: nil as String?
                            )
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    func startTorrentDownload(url: String, savePath: String, resume: Bool = false) {
        startTorrentDownloadProcess(url: url, savePath: savePath, resume: resume, forceNew: false)
    }
    
    func addDownload(url: String, fileName: String, fileType: DownloadItem.FileType, savePath: String, chunks: Int, cookiesPath: String?) {
        addDownloadEnhanced(url: url, fileName: fileName, fileType: fileType, savePath: savePath, chunks: chunks, cookiesPath: cookiesPath)
    }
    
    func addDownloadEnhanced(url: String, fileName: String, fileType: DownloadItem.FileType, savePath: String, chunks: Int, cookiesPath: String?) {
        print("📥 Adding download: \(url)")
        
        if let existingDownload = downloads.first(where: {
            $0.url == url && $0.fileName == fileName && $0.savePath == savePath
        }) {
            let alert = NSAlert()
            alert.messageText = "Download Already Exists"
            alert.informativeText = "A download for '\(fileName)' already exists in the list. What would you like to do?"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Resume Existing")
            alert.addButton(withTitle: "Add New Download")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                if existingDownload.status != .downloading {
                    existingDownload.status = .waiting
                    startDownload(for: existingDownload)
                }
                return
            case .alertSecondButtonReturn:
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileExtension = URL(fileURLWithPath: fileName).pathExtension
                let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
                let newFileName = "\(baseName)_\(timestamp).\(fileExtension)"
                
                let newDownload = DownloadItem(
                    fileName: newFileName,
                    url: url,
                    fileSize: 0,
                    fileType: fileType
                )
                newDownload.savePath = savePath
                newDownload.chunks = chunks
                newDownload.cookiesPath = cookiesPath
                
                downloads.insert(newDownload, at: 0)
                saveDownloads()
                startDownload(for: newDownload)
                return
            default:
                return
            }
        }
        
        let newDownload = DownloadItem(
            fileName: fileName,
            url: url,
            fileSize: 0,
            fileType: fileType
        )
        newDownload.savePath = savePath
        newDownload.chunks = chunks
        newDownload.cookiesPath = cookiesPath
        
        downloads.insert(newDownload, at: 0)
        saveDownloads()
        startDownload(for: newDownload)
    }
    
    func addVideoDownloadWithHeaders(url: String, fileName: String, headers: [String: String], pageTitle: String, videoType: String, contentType: String?) {
        print("📹 Adding video download with headers: \(fileName)")
        
        let newDownload = DownloadItem(
            fileName: fileName,
            url: url,
            fileSize: 0,
            fileType: .video
        )
        
        newDownload.savePath = "~/Downloads"
        newDownload.chunks = 16
        newDownload.customHeaders = headers
        newDownload.pageTitle = pageTitle
        newDownload.videoType = videoType
        newDownload.isStreamingVideo = true
        
        // تحديد إذا كان YouTube
        if url.contains("youtube.com") || url.contains("youtu.be") {
            newDownload.isYouTubeVideo = true
            newDownload.actualVideoTitle = pageTitle
        }
        
        downloads.insert(newDownload, at: 0)
        saveDownloads()
        
        // بدء التحميل مع headers
        startVideoDownloadWithHeaders(for: newDownload)
    }
    
    // MARK: - Download Management
    func startDownload(for item: DownloadItem, isAutoResume: Bool = false) {
        print("🚀 Starting download: \(item.fileName) (Auto-resume: \(isAutoResume))")
        
        // تحديث الحالة مباشرة
        DispatchQueue.main.async {
            if item.status != .downloading {
                item.status = .downloading
            }
            item.instantSpeed = 0
            item.downloadSpeed = isAutoResume ? "Resuming..." : "Starting..."
            item.remainingTime = "--:--"
            self.objectWillChange.send()
        }
        
        // بدء التحميل فوراً بناءً على النوع
        if item.isYouTubeVideo {
            // استخدام الطريقة الجديدة لتحميل يوتيوب (فصل الفيديو والصوت)
            startYouTubeDownloadSeparate(for: item)
        } else if item.isTorrent {
            startTorrentDownload(for: item)
        } else if item.isStreamingVideo {
            startVideoDownloadWithHeaders(for: item)
        } else {
            startNormalDownload(for: item, isAutoResume: isAutoResume)
        }
        
        // حفظ التحديثات بشكل متوازي
        DispatchQueue.global(qos: .utility).async {
            self.saveDownloads()
        }
    }
    
    // MARK: - Video Download with Headers
    func startVideoDownloadWithHeaders(for item: DownloadItem) {
        print("🎬 Starting video download with headers: \(item.fileName)")
        
        DispatchQueue.main.async {
            item.status = .downloading
            item.downloadSpeed = "Preparing..."
            self.objectWillChange.send()
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            
            // التحقق من yt-dlp أولاً
            let ytDlpPath = self.findYtDlpPathOptimized()
            guard FileManager.default.fileExists(atPath: ytDlpPath) else {
                print("❌ yt-dlp not found at: \(ytDlpPath)")
                DispatchQueue.main.async {
                    item.status = .failed
                    item.downloadSpeed = "yt-dlp not found"
                    self.objectWillChange.send()
                }
                return
            }
            
            // إنشاء المجلد بشكل متوازي
            let expandedPath = self.expandTildePath(item.savePath)
            let finalOutputPath = "\(expandedPath)/\(item.fileName)"
            
            // التحقق من وجود الملف النهائي وحذفه إذا كان موجوداً عند الاستئناف
            if item.wasManuallyPaused && FileManager.default.fileExists(atPath: finalOutputPath) {
                do {
                    try FileManager.default.removeItem(atPath: finalOutputPath)
                    print("🗑️ Removed existing file for resume: \(finalOutputPath)")
                } catch {
                    print("⚠️ Failed to remove existing file: \(error)")
                }
            }
            
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("⚠️ Failed to create directory: \(error) - continuing anyway")
                }
            }
            
            // بناء arguments
            var arguments = [String]()
            
            // إضافة headers مخصصة
            if let headers = item.customHeaders {
                for (key, value) in headers {
                    // تخطي بعض headers التي قد تسبب مشاكل
                    if key.lowercased() != "host" && key.lowercased() != "content-length" {
                        arguments.append("--add-header")
                        arguments.append("\(key):\(value)")
                    }
                }
            }
            
            // إعدادات yt-dlp محسنة ومستقرة
            arguments.append(contentsOf: [
                "-o", "\(expandedPath)/\(item.fileName)",
                "--no-warnings",
                "--no-check-certificate",
                "--concurrent-fragments", "64",  // عدد الأجزاء المتزامنة - زيادة للسرعة القصوى
                "--retries", "3",
                "--fragment-retries", "3",
                "--buffer-size", "64K",  // حجم البفر
                "--http-chunk-size", "41943040", // 40MB chunks
                "--newline",
                "--progress",
                "--progress-template", "%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s",
                "--no-part",
                "--no-mtime",
                "--external-downloader", "axel",  // استخدام axel
                "--external-downloader-args", "axel:-n 16 -v -k -T 30 -U Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            ])
            
            // إضافة axel path من bundle إذا كان موجوداً
            if let axelPath = self.findAxelPath() {
                arguments.append(contentsOf: ["--external-downloader", axelPath])
                print("✅ Using bundled axel for external downloader: \(axelPath)")
            } else {
                print("⚠️ axel not found in bundle, using default downloader")
            }
            
            // إضافة URL
            arguments.append(item.url)
            
            // إنشاء العملية
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = arguments
            
            print("🎬 Video download command:")
            print("🎬 yt-dlp \(arguments.joined(separator: " "))")
            
            // معالجة output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // قراءة التقدم
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    self?.parseVideoProgress(output, for: item)
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
                        item.status = .completed
                        item.progress = 1.0
                        item.downloadSpeed = "Completed"
                        item.remainingTime = "00:00"
                        item.instantSpeed = 0
                        print("✅ Video download with headers completed: \(item.fileName)")
                        self.notificationManager.sendDownloadCompleteNotification(for: item)
                    } else if process.terminationStatus == 15 || process.terminationStatus == 9 {
                        // SIGTERM (15) أو SIGKILL (9) - تم إيقاف التحميل مؤقتاً
                        if item.status == .paused {
                            print("⏸️ Video download paused: \(item.fileName) (exit code: \(process.terminationStatus))")
                            // لا نحذف الملفات الجزئية عند الإيقاف المؤقت
                        } else {
                            item.status = .failed
                            item.downloadSpeed = "Failed (exit code: \(process.terminationStatus))"
                            print("❌ Video download with headers failed: \(item.fileName) (exit code: \(process.terminationStatus))")
                        }
                    } else {
                        item.status = .failed
                        item.downloadSpeed = "Failed (exit code: \(process.terminationStatus))"
                        print("❌ Video download with headers failed: \(item.fileName) (exit code: \(process.terminationStatus))")
                    }
                    self.saveDownloads()
                }
            } catch {
                print("❌ Failed to start video download with headers: \(error)")
                DispatchQueue.main.async {
                    item.status = .failed
                    item.downloadSpeed = "Failed to start"
                    self.objectWillChange.send()
                    self.saveDownloads()
                }
            }
        }
    }
    
    func pauseDownload(_ item: DownloadItem) {
        print("⏸️ Pausing download: \(item.fileName)")
        
        // ✅ إصلاح: تعيين الحالة أولاً لمنع اكتشاف الاكتمال
        item.status = .paused
        item.wasManuallyPaused = true
        
        // إيقاف تتبع السرعة
        RealTimeSpeedTracker.shared.reset(for: item.id)
        
        // ✅ إصلاح: تحديث واجهة المستخدم فوراً مع إزالة أي علامات اكتمال
        item.instantSpeed = 0
        item.downloadSpeed = "Paused"
        item.remainingTime = "--:--"
        
        // ✅ إصلاح: تحديث الواجهة فوراً لمنع ظهور "Completed"
        self.objectWillChange.send()
        
        // إيقاف العملية بشكل لطيف مع تحسين للـ yt-dlp
        if let process = item.processTask, process.isRunning {
            // إرسال SIGTERM أولاً (أكثر لطفاً)
            process.terminate()
            
            // انتظار قصير ثم إرسال SIGKILL إذا لزم الأمر
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if process.isRunning {
                    print("⚠️ Process still running, sending SIGKILL")
                    kill(process.processIdentifier, SIGKILL)
                }
                item.processTask = nil
                
                // حفظ التقدم الحالي
                print("💾 [PAUSE] Saved progress: \(Int(item.progress * 100))%")
                
                // تنظيف الملفات المؤقتة لـ YouTube إذا لزم الأمر
                if item.isYouTubeVideo {
                    let tempDir = NSTemporaryDirectory()
                    let tempDownloadDir = "\(tempDir)SafarGet_YouTube_Separate"
                    _ = "\(tempDownloadDir)/video_temp.mp4"
                    _ = "\(tempDownloadDir)/audio_temp.m4a"
                    
                    // لا نحذف الملفات الجزئية عند الإيقاف المؤقت، فقط نتركها للاستئناف
                    print("💾 [PAUSE] Keeping partial files for resume")
                }
                
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                    self.saveDownloads()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.saveDownloads()
            }
        }
    }
    
    func resumeDownload(_ item: DownloadItem) {
        print("▶️ Resuming download: \(item.fileName)")

        // ✅ 1. حفظ النسبة المئوية الحالية قبل إعادة التعيين
        let savedProgress = item.progress
        let savedDownloadedSize = item.downloadedSize
        print("💾 [RESUME] Saved progress: \(Int(savedProgress * 100))% (\(formatFileSize(savedDownloadedSize)))")

        // ✅ 2. إعادة تعيين أنظمة التتبع
        RealTimeSpeedTracker.shared.reset(for: item.id)
        RealTimeSpeedTracker.shared.markAsResuming(for: item.id)

        // إعادة تهيئة المتتبع الذكي
        downloadSpeedTrackers[item.id] = (item.downloadedSize, Date(), [])

        // ✅ 3. تحديث الحالة
        item.wasManuallyPaused = false
        item.status = .downloading
        
        // ✅ 4. تحديث السرعة فوراً مع الاحتفاظ بالنسبة المئوية
        item.downloadSpeed = "Connecting..."
        item.instantSpeed = 0
        item.remainingTime = "--:--"
        
        // ✅ 5. تأكد من عدم إعادة تعيين النسبة المئوية
        if item.progress != savedProgress {
            item.progress = savedProgress
            print("🔒 [RESUME] Restored progress: \(Int(item.progress * 100))%")
        }
        
        // ✅ 6. تعيين علامة لتجاهل النسبة المئوية مؤقتاً
        item.isResuming = true
        
        // ✅ إصلاح: تحديث الواجهة فوراً
        self.objectWillChange.send()
        
        // إضافة timer لمراقبة التقدم عند الاستئناف
        let resumeProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // إذا كان التحميل لا يزال في حالة الاستئناف ولم يظهر تقدم جديد
            if item.isResuming && item.status == .downloading {
                // إظهار رسالة "جاري الاستئناف" مع النسبة المحفوظة
                DispatchQueue.main.async {
                    item.downloadSpeed = "Resuming... (\(Int(savedProgress * 100))%)"
                    self.objectWillChange.send()
                }
            } else {
                timer.invalidate()
            }
        }
        
        // إزالة العلامة بعد 5 ثوانٍ (أطول للـ yt-dlp مع --continue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            item.isResuming = false
            print("🔒 [RESUME] Removed resuming flag")
            resumeProgressTimer.invalidate()
        }
        
        // ✅ 7. إرسال تحديثات UI فوراً
        DispatchQueue.main.async {
            self.objectWillChange.send()
            NotificationCenter.default.post(
                name: .downloadSpeedUpdated,
                object: nil,
                userInfo: ["downloadId": item.id]
            )
        }

        // ✅ 8. إعادة بدء التحميل مع تحسين للـ yt-dlp
        if item.processTask == nil || !item.processTask!.isRunning {
            // تأخير قصير لضمان تنظيف العملية السابقة
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if item.isYouTubeVideo {
                    // استخدام الطريقة الجديدة للاستئناف
                                                              self.startYouTubeDownloadSeparate(for: item)
                } else {
                    self.startDownload(for: item, isAutoResume: true)
                }
            }
        }

        // ✅ 5. إنشاء timer محسن لمراقبة السرعة
        let speedCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, item.status == .downloading else {
                timer.invalidate()
                return
            }

            // الحصول على السرعة من RealTimeSpeedTracker
            let speedResult = RealTimeSpeedTracker.shared.updateSpeed(
                for: item.id,
                currentBytes: item.downloadedSize,
                totalBytes: item.fileSize
            )

            // إذا حصلنا على سرعة، حدث UI
            if speedResult.speed > 0 {
                DispatchQueue.main.async {
                    // ✅ إصلاح: تحديث الحالة أولاً إلى "Downloading" إذا كانت هناك سرعة
                    if item.downloadSpeed.contains("Starting") || 
                       item.downloadSpeed.contains("Resuming") || 
                       item.downloadSpeed.contains("Connecting") {
                        item.downloadSpeed = "Downloading..."
                        print("📝 Status updated: Downloading...")
                    }
                    
                    item.updateSpeed(speedResult.speed, displaySpeed: "Downloading...")
                    item.remainingTime = speedResult.remainingTime
                    self.objectWillChange.send()
                    
                    NotificationCenter.default.post(
                        name: .downloadSpeedUpdated,
                        object: nil,
                        userInfo: ["downloadId": item.id]
                    )
                }
                
                // إذا كانت السرعة مستقرة، أوقف المراقبة المكثفة
                if speedResult.speed > 1000 {
                    print("✅ Resume speed stabilized: \(speedResult.displaySpeed)")
                    timer.invalidate()
                    return
                }
            } else {
                // إذا لم نحصل على سرعة، جرب الكشف الذكي
                self.smartSpeedDetection(for: item)
                
                // ✅ إصلاح محسن: إذا لم تنجح أي طريقة، استخدم سرعة افتراضية فقط إذا كانت السرعة صفر
                if item.instantSpeed == 0 && (item.downloadSpeed.contains("Connecting") || item.downloadSpeed.contains("Waiting")) {
                    DispatchQueue.main.async {
                        // ✅ إصلاح: تحديث الحالة أولاً إلى "Downloading" إذا كانت هناك سرعة
                        if item.downloadSpeed.contains("Starting") || 
                           item.downloadSpeed.contains("Resuming") || 
                           item.downloadSpeed.contains("Connecting") {
                            item.downloadSpeed = "Downloading..."
                            print("📝 Status updated: Downloading...")
                        }
                        
                        let fallbackSpeed = 1024.0 // 1 KB/s
                        item.updateSpeed(fallbackSpeed, displaySpeed: "Downloading...")
                        self.objectWillChange.send()
                        
                        NotificationCenter.default.post(
                            name: .downloadSpeedUpdated,
                            object: nil,
                            userInfo: ["downloadId": item.id]
                        )
                    }
                }
            }

            // إيقاف المراقبة بعد 2 ثانية للاستجابة السريعة
            if Date().timeIntervalSince(timer.fireDate) > 2 {
                timer.invalidate()
            }
        }
        
        RunLoop.main.add(speedCheckTimer, forMode: .common)

        // حفظ الحالة
    saveDownloads()
        
        print("✅ Resume initiated for: \(item.fileName)")
}
    
    func stopDownload(_ item: DownloadItem) {
        print("⏹️ Stopping download: \(item.fileName)")
        terminateDownloadProcess(item)
        item.status = .paused
        item.wasManuallyPaused = true
        item.downloadSpeed = "Stopped"
        item.remainingTime = "--:--"
        
        // تنظيف الملفات المؤقتة لـ YouTube إذا لزم الأمر
        if item.isYouTubeVideo {
            cancelYouTubeDownload(for: item)
        }
        
        saveDownloads()
    }
    
    func restartDownload(_ item: DownloadItem) {
        print("🔄 Restarting download: \(item.fileName)")
        
        // إنهاء العملية الحالية
        terminateDownloadProcess(item)
        
        // حذف جميع الملفات المؤقتة والجزئية أولاً
        cleanupIncompleteDownloadFiles(for: item)
        
        // إعادة تعيين كل شيء للبدء من جديد
        item.progress = 0
        item.downloadedSize = 0
        item.status = .waiting
        item.instantSpeed = 0
        item.downloadSpeed = "Preparing..."
        item.remainingTime = "--:--"
        item.speedHistory = []
        item.wasManuallyPaused = false
        
        // إعادة تعيين تتبع السرعة
        RealTimeSpeedTracker.shared.remove(for: item.id)
        
        print("🔄 [RESTART] Starting fresh download from 0%")
        
        // بدء التحميل من جديد
        startDownload(for: item, isAutoResume: false)
        saveDownloads()
    }
    
    func deleteDownload(_ item: DownloadItem) {
        print("🗑️ Deleting download: \(item.fileName)")
        if let index = downloads.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.easeOut(duration: 0.3)) {
                terminateDownloadProcess(item)
                
                // حذف الملفات المؤقتة والغير مكتملة فقط
                // لا نحذف الملفات المكتملة من الجهاز
                if item.status == .completed {
                    // للملفات المكتملة: نحذف فقط الملفات المؤقتة
                    cleanupTempFilesOnly(for: item)
                } else {
                    // للملفات غير المكتملة: نحذف الملفات المؤقتة والغير مكتملة
                    cleanupIncompleteDownloadFiles(for: item)
                }
                
                downloads.remove(at: index)
                selectedDownloadIDs.remove(item.id)
            }
        }
        saveDownloads()
    }
    
    func openFile(_ item: DownloadItem) {
        print("📂 Opening file: \(item.fileName)")
        guard item.status == .completed else { return }
        let path = expandTildePath(item.savePath)
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(item.fileName)
        NSWorkspace.shared.open(fileURL)
    }
    
    func openFileWith(_ item: DownloadItem) {
        print("🔧 Open with: \(item.fileName)")
        guard item.status == .completed else { return }
        let path = expandTildePath(item.savePath)
        let fileURL = URL(fileURLWithPath: path).appendingPathComponent(item.fileName)
        NSWorkspace.shared.openApplication(at: fileURL, configuration: NSWorkspace.OpenConfiguration())
    }
    
    func openFolder(_ item: DownloadItem) {
        print("📁 Opening folder: \(item.savePath)")
        let path = expandTildePath(item.savePath)
        let folderURL = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(folderURL)
    }

    // MARK: - Helper Functions
    func detectFileType(from url: String) -> DownloadItem.FileType {
        let lowercased = url.lowercased()
        
        if lowercased.hasSuffix(".torrent") || lowercased.contains("torrent") {
            return .torrent
        } else if lowercased.contains("youtube") || lowercased.hasSuffix(".mp4") || lowercased.hasSuffix(".mov") || lowercased.hasSuffix(".avi") || lowercased.hasSuffix(".mkv") {
            return .video
        } else if lowercased.hasSuffix(".mp3") || lowercased.hasSuffix(".m4a") || lowercased.hasSuffix(".wav") || lowercased.hasSuffix(".flac") {
            return .audio
        } else if lowercased.hasSuffix(".pdf") || lowercased.hasSuffix(".doc") || lowercased.hasSuffix(".docx") || lowercased.hasSuffix(".txt") {
            return .document
        } else if lowercased.hasSuffix(".zip") || lowercased.hasSuffix(".rar") || lowercased.hasSuffix(".7z") || lowercased.hasSuffix(".dmg") || lowercased.hasSuffix(".tar") {
            return .compressed
        } else if lowercased.hasSuffix(".exe") || lowercased.hasSuffix(".app") || lowercased.hasSuffix(".pkg") || lowercased.hasSuffix(".deb") {
            return .executable
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".gif") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".webp") {
            return .image
        }
        
        return .other
    }
    
    func expandTildePath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return NSString(string: path).expandingTildeInPath
        }
        return path
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatSpeedString(_ bytesPerSecond: Double) -> String {
        // ✅ إصلاح: تحسين عرض السرعة
        if bytesPerSecond < 1024 {
            return String(format: "%.1f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.1f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }
    
    // MARK: - Stuck Download Management
    func checkStuckDownloads() {
        for download in downloads {
            if download.status == .waiting && download.processTask == nil {
                print("⚠️ Found stuck download: \(download.fileName)")
                // إعادة محاولة التحميل
                startDownload(for: download)
            }
        }
    }
    
    func startStuckDownloadChecker() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkStuckDownloads()
        }
    }
    
    // MARK: - Validate Download Speed
    private func validateDownloadSpeed(_ speed: Double, for item: DownloadItem) -> Double {
        // الحد الأقصى المعقول للسرعة (100 MB/s)
        let maxReasonableSpeed: Double = 100 * 1024 * 1024
        
        // إذا كانت السرعة أكبر من الحد المعقول
        if speed > maxReasonableSpeed {
            print("⚠️ Unrealistic speed detected: \(formatSpeedString(speed)) for \(item.fileName)")
            
            // استخدم آخر سرعة معقولة إذا كانت متاحة
            if item.lastSpeedBeforeDisconnect > 0 && item.lastSpeedBeforeDisconnect < maxReasonableSpeed {
                return item.lastSpeedBeforeDisconnect
            }
            
            // وإلا ارجع 0
            return 0
        }
        
        return speed
    }
    
    // MARK: - Axel Error Handling
    private func getAxelErrorMessage(exitCode: Int32) -> String {
        switch exitCode {
        case 1: return "Generic error"
        case 2: return "Timeout occurred"
        case 3: return "Resource not found"
        case 4: return "Network problem occurred"
        case 5: return "SSL/TLS error"
        case 6: return "File already exists"
        case 7: return "Permission denied"
        case 8: return "Disk full"
        case 9: return "Invalid URL"
        case 10: return "HTTP error"
        case 11: return "Connection refused"
        case 12: return "Host not found"
        case 13: return "Operation cancelled"
        case 14: return "Invalid argument"
        case 15: return "Memory allocation failed"
        default: return "Unknown error (exit code: \(exitCode))"
        }
    }
    
    // MARK: - Aria2 Error Handling (for torrents)
    private func getAria2ErrorMessage(exitCode: Int32) -> String {
        switch exitCode {
        case 1: return "Unknown error occurred"
        case 2: return "Time exceeded"
        case 3: return "Resource not found"
        case 4: return "Network problem occurred"
        case 5: return "Quota exceeded"
        case 6: return "Checksum error"
        case 7: return "Same file already exists"
        case 8: return "Renamed file already exists"
        case 9: return "File not found"
        case 10: return "No permission to create directory"
        case 11: return "Name resolution failed"
        case 12: return "Network is unreachable"
        case 13: return "Network is down"
        case 14: return "Network is unreachable"
        case 15: return "Host is unreachable"
        case 16: return "Connection refused"
        case 17: return "Connection timed out"
        case 18: return "Connection reset by peer"
        case 19: return "Network is unreachable"
        case 20: return "Network is unreachable"
        case 21: return "Network is unreachable"
        case 22: return "Invalid argument"
        case 23: return "File I/O error"
        case 24: return "File I/O error"
        case 25: return "File I/O error"
        case 26: return "File I/O error"
        case 27: return "File I/O error"
        case 28: return "Network problem occurred (server error or connection issue)"
        case 29: return "Network problem occurred"
        case 30: return "Network problem occurred"
        default: return "Unknown error (exit code: \(exitCode))"
        }
    }
    
    private func canRetryDownload(exitCode: Int32) -> Bool {
        // الأخطاء التي يمكن إعادة المحاولة فيها
        let retryableErrors: [Int32] = [2, 4, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 28, 29, 30]
        return retryableErrors.contains(exitCode)
    }
    
    // MARK: - Clean Temporary Files
    private func cleanTemporaryFiles() {
        let downloadsPath = expandTildePath("~/Downloads")
        let tempPath = "\(downloadsPath)/.safarget_temp"
        
        do {
            if FileManager.default.fileExists(atPath: tempPath) {
                let contents = try FileManager.default.contentsOfDirectory(atPath: tempPath)
                for file in contents {
                    let filePath = "\(tempPath)/\(file)"
                    // حذف الملفات القديمة (أكثر من 24 ساعة)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                       let modificationDate = attributes[.modificationDate] as? Date,
                       Date().timeIntervalSince(modificationDate) > 86400 {
                        try? FileManager.default.removeItem(atPath: filePath)
                    }
                }
            }
            
            // تنظيف ملفات axel المؤقتة
            let axelTempFiles = [
                ".st",
                ".st~",
                ".st.tmp"
            ]
            
            for tempFile in axelTempFiles {
                let tempFilePath = "\(downloadsPath)/\(tempFile)"
                if FileManager.default.fileExists(atPath: tempFilePath) {
                    try? FileManager.default.removeItem(atPath: tempFilePath)
                }
            }
        } catch {
            print("⚠️ Failed to clean temporary files: \(error)")
        }
    }
    
    // MARK: - Show Error
    private func showError(_ message: String, for item: DownloadItem) {
        // لا تظهر أخطاء الاتصال المؤقتة
        if message.contains("timeout") || message.contains("Connection") {
            print("🔄 Connection issue (will retry): \(message)")
            return
        }
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Download Failed"
            alert.informativeText = "\(item.fileName)\n\n\(message)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Initialize Download Speed
    private func initializeDownloadSpeed(for item: DownloadItem) {
        DispatchQueue.main.async {
            item.instantSpeed = 0
            item.downloadSpeed = "Connecting..."
            item.remainingTime = "--:--"
            
            // إنشاء timer مؤقت لتحديث السرعة حتى يبدأ axel في إرسال البيانات
            var updateCount = 0
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                updateCount += 1
                
                // إذا بدأت السرعة الفعلية، أوقف التحديث المؤقت
                if item.instantSpeed > 0 || updateCount > 10 {
                    timer.invalidate()
                    return
                }
                
                // تحديث حالة الاتصال
                if updateCount < 3 {
                    item.downloadSpeed = "Connecting..."
                } else if updateCount < 6 {
                    item.downloadSpeed = "Initializing..."
                } else {
                    item.downloadSpeed = "Starting download..."
                }
                
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Parse Size Helper
    private func parseSize(_ sizeStr: String) -> Int64 {
        let cleanStr = sizeStr.trimmingCharacters(in: .whitespaces)
        
        // Extract number and unit
        let pattern = #"^([\d.]+)\s*([KMGT]?i?B)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: cleanStr, options: [], range: NSRange(location: 0, length: cleanStr.utf16.count)),
              match.numberOfRanges >= 2 else {
            return Int64(cleanStr) ?? 0
        }
        
        // Extract number
        guard let numberRange = Range(match.range(at: 1), in: cleanStr),
              let number = Double(String(cleanStr[numberRange])) else {
            return 0
        }
        
        // Extract unit (if exists)
        var unit = "B"
        if match.numberOfRanges > 2,
           let unitRange = Range(match.range(at: 2), in: cleanStr) {
            unit = String(cleanStr[unitRange])
        }
        
        let multiplier: Double
        switch unit.uppercased() {
        case "B": multiplier = 1
        case "KB", "KIB", "K": multiplier = 1024
        case "MB", "MIB", "M": multiplier = 1024 * 1024
        case "GB", "GIB", "G": multiplier = 1024 * 1024 * 1024
        case "TB", "TIB", "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }
        
        return Int64(number * multiplier)
    }
    
    // MARK: - Parse Speed Helper
    private func parseSpeed(_ speedStr: String) -> Double {
        let cleanStr = speedStr.replacingOccurrences(of: "/s", with: "")
        let bytes = parseSize(cleanStr)
        return Double(bytes)
    }
    
    // MARK: - Check Existing File
    func checkExistingFile(for item: DownloadItem) -> FileCheckResult {
        let expandedPath = expandTildePath(item.savePath)
        let fileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(item.fileName)
        
        // التحقق من ملفات axel المؤقتة
        let axelTempFiles = [
            ".st",
            ".st~",
            ".st.tmp"
        ]
        
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: fileURL.path) {
            // التحقق من وجود ملفات axel مؤقتة
            var hasAxelTemp = false
            for tempFile in axelTempFiles {
                let tempFileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
                if fileManager.fileExists(atPath: tempFileURL.path) {
                    hasAxelTemp = true
                    break
                }
            }
            
            if hasAxelTemp {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let currentSize = attributes[.size] as? Int64 ?? 0
                    return .incomplete(currentSize: currentSize)
                } catch {
                    return .notExists
                }
            } else {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    if item.fileSize > 0 && fileSize == item.fileSize {
                        return .complete(size: fileSize)
                    } else if item.fileSize == 0 {
                        return .complete(size: fileSize)
                    } else {
                        return .incomplete(currentSize: fileSize)
                    }
                } catch {
                    return .notExists
                }
            }
        }
        
        return .notExists
    }
    
    enum FileCheckResult {
        case complete(size: Int64)
        case incomplete(currentSize: Int64)
        case notExists
    }
    
    func handleExistingFile(for item: DownloadItem, result: FileCheckResult, isAutoResume: Bool = false, completion: @escaping (FileAction) -> Void) {
        DispatchQueue.main.async {
            switch result {
            case .complete(let size):
                if isAutoResume {
                    item.status = .completed
                    item.fileSize = size
                    item.downloadedSize = size
                    item.progress = 1.0
                    self.saveDownloads()
                    completion(.skip)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "File Already Downloaded"
                    alert.informativeText = "The file '\(item.fileName)' (\(self.formatFileSize(size))) already exists and appears to be complete."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Open File")
                    alert.addButton(withTitle: "Re-download (New Name)")
                    alert.addButton(withTitle: "Cancel")
                    
                    let response = alert.runModal()
                    switch response {
                    case .alertFirstButtonReturn:
                        item.status = .completed
                        item.fileSize = size
                        item.downloadedSize = size
                        item.progress = 1.0
                        self.saveDownloads()
                        self.openFile(item)
                        completion(.skip)
                    case .alertSecondButtonReturn:
                        completion(.redownloadNewName)
                    default:
                        completion(.cancel)
                    }
                }
                
            case .incomplete(let currentSize):
                if isAutoResume {
                    item.downloadedSize = currentSize
                    completion(.resume)
                } else {
                    if let existingDownload = self.downloads.first(where: {
                        $0.url == item.url && $0.fileName == item.fileName && $0.id != item.id
                    }) {
                        existingDownload.status = .waiting
                        self.startDownload(for: existingDownload)
                        completion(.useExisting)
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Incomplete Download Found"
                        alert.informativeText = "The file '\(item.fileName)' exists but is incomplete (\(self.formatFileSize(currentSize)) downloaded). Would you like to resume?"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Resume")
                        alert.addButton(withTitle: "Start Over")
                        alert.addButton(withTitle: "Download with New Name")
                        alert.addButton(withTitle: "Cancel")
                        
                        let response = alert.runModal()
                        switch response {
                        case .alertFirstButtonReturn:
                            item.downloadedSize = currentSize
                            completion(.resume)
                        case .alertSecondButtonReturn:
                            completion(.redownload)
                        case NSApplication.ModalResponse(rawValue: 1002):
                            completion(.redownloadNewName)
                        default:
                            completion(.cancel)
                        }
                    }
                }
                
            case .notExists:
                completion(.download)
            }
        }
    }
    
    enum FileAction {
        case download
        case resume
        case redownload
        case redownloadNewName
        case skip
        case cancel
        case useExisting
    }
    
    func startNormalDownload(for item: DownloadItem, isAutoResume: Bool = false) {
        let fileCheckResult = checkExistingFile(for: item)
        
        handleExistingFile(for: item, result: fileCheckResult, isAutoResume: isAutoResume) { action in
            switch action {
            case .download, .resume:
                self.performNormalDownload(for: item, resume: action == .resume)
            case .redownload:
                self.deleteExistingFile(for: item)
                self.performNormalDownload(for: item, resume: false)
            case .redownloadNewName:
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileExtension = URL(fileURLWithPath: item.fileName).pathExtension
                let baseName = URL(fileURLWithPath: item.fileName).deletingPathExtension().lastPathComponent
                item.fileName = "\(baseName)_\(timestamp).\(fileExtension)"
                self.performNormalDownload(for: item, resume: false)
            case .skip:
                break
            case .cancel:
                self.deleteDownload(item)
            case .useExisting:
                self.deleteDownload(item)
            }
        }
    }
    
    private func deleteExistingFile(for item: DownloadItem) {
        let expandedPath = expandTildePath(item.savePath)
        let fileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(item.fileName)
        
        // حذف الملف الرئيسي
        try? FileManager.default.removeItem(at: fileURL)
        
        // حذف ملفات axel المؤقتة
        let axelTempFiles = [
            ".st",
            ".st~",
            ".st.tmp"
        ]
        
        for tempFile in axelTempFiles {
            let tempFileURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(tempFile)
            try? FileManager.default.removeItem(at: tempFileURL)
        }
    }

    // MARK: - Perform Normal Download
    private func performNormalDownload(for item: DownloadItem, resume: Bool) {
        // تهيئة السرعة
        initializeDownloadSpeed(for: item)
        
        // إذا كان استئناف، ضع علامة
        if resume {
            RealTimeSpeedTracker.shared.markAsResuming(for: item.id)
            print("📊 Resuming download: \(item.fileName)")
            print("📊 Saved progress: \(formatFileSize(item.downloadedSize)) / \(formatFileSize(item.fileSize)) (\(Int(item.progress * 100))%)")
            
            // ✅ إصلاح: حفظ النسبة المئوية الحالية
            let savedProgress = item.progress
            let _ = item.downloadedSize // تجاهل التحذير
            
            // مهم: لا تحاول قراءة حجم الملف من القرص
            // axel لا يدعم الاستئناف بشكل صريح، لذا سنبدأ من جديد
            // استخدم القيم المحفوظة فقط
            
            DispatchQueue.main.async {
                // تأكد من أن القيم صحيحة
                if item.downloadedSize > item.fileSize && item.fileSize > 0 {
                    // إصلاح القيم إذا كانت خاطئة
                    item.downloadedSize = Int64(Double(item.fileSize) * item.progress)
                    print("⚠️ Fixed downloaded size to: \(self.formatFileSize(item.downloadedSize))")
                }
                
                // ✅ إصلاح: تأكد من عدم إعادة تعيين النسبة المئوية
                if item.progress != savedProgress {
                    item.progress = savedProgress
                    print("🔒 [PERFORM] Restored progress: \(Int(item.progress * 100))%")
                }
                
                // تحديث واجهة المستخدم
                self.objectWillChange.send()
            }
        } else {
            // بداية جديدة
            RealTimeSpeedTracker.shared.reset(for: item.id)
            item.downloadedSize = 0
            item.progress = 0
            print("🆕 Starting new download: \(item.fileName)")
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            
            // البحث عن axel أولاً (للتحميل العادي)
            var axelPath: String?
            
            // البحث في bundle أولاً
            if let bundledPath = getBundledExecutablePath(name: "axel") {
                axelPath = bundledPath
            } else {
                // البحث في النظام
                let possiblePaths = [
                    "/opt/homebrew/bin/axel",
                    "/usr/local/bin/axel",
                    "/usr/bin/axel",
                    "/bin/axel"
                ]
                
                for path in possiblePaths {
                    if FileManager.default.fileExists(atPath: path) {
                        axelPath = path
                        break
                    }
                }
            }
            
            guard let finalPath = axelPath else {
                print("❌ axel not found")
                self.fallbackDownload(for: item)
                return
            }
            
            // إنشاء العملية فوراً
            let process = Process()
            process.executableURL = URL(fileURLWithPath: finalPath)
            
            let expandedPath = self.expandTildePath(item.savePath)
            
            // مسار مؤقت للتحميل
            let tempDownloadPath = "\(expandedPath)/.safarget_temp"
            let tempFileName = item.fileName  // ✅ إصلاح: استخدام اسم الملف النهائي مباشرة

            // إنشاء المجلد المؤقت بشكل متوازي
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.createDirectory(
                        atPath: tempDownloadPath, 
                        withIntermediateDirectories: true, 
                        attributes: [.posixPermissions: 0o755]
                    )
                    print("✅ Created temp directory: \(tempDownloadPath)")
                } catch {
                    print("⚠️ Failed to create temp directory: \(error) - continuing anyway")
                }
            }
            
            // إعدادات axel محسنة ومستقرة (للملفات العادية)
            var arguments: [String] = [
                "-n", "16",                         // 16 اتصال
                "-o", tempFileName,                 // اسم الملف المؤقت
                "-v",                               // verbose output
                "-k",                               // لا تتحقق من الشهادة
                "-T", "30",                         // timeout 30 ثانية
                "-U", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"  // user agent
            ]
            
            // إضافة headers
            arguments.append(contentsOf: [
                "-H", "Accept: */*",
                "-H", "Accept-Language: en-US,en;q=0.9",
                "-H", "Connection: keep-alive"
            ])
            
            // إضافة URL
            arguments.append(item.url)
            
            print("🚀 Starting axel download for: \(item.fileName)")
            if resume {
                print("📊 Resuming from: \(self.formatFileSize(item.downloadedSize))")
            }
            
            process.arguments = arguments
            process.qualityOfService = .userInitiated
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var lastOutputTime = Date()
            var outputBuffer = ""
            
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                autoreleasepool {
                    guard let self = self else { return }
                    let data = handle.availableData
                    if data.isEmpty { return }
                    
                    if let output = String(data: data, encoding: .utf8) {
                        outputBuffer += output
                        
                        // معالجة الأسطر الكاملة فقط
                        let lines = outputBuffer.components(separatedBy: .newlines)
                        outputBuffer = lines.last ?? ""
                        
                        for line in lines.dropLast() {
                            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmedLine.isEmpty { continue }
                            
                            // Debug: طباعة output axel
                            if trimmedLine.contains("File size:") || trimmedLine.contains("[") || trimmedLine.contains("Downloaded") {
                                print("🔍 [AXEL] Output: \(trimmedLine)")
                            }
                            
                            // استخدام parser
                            let parsedData = AxelOutputParser.parseOutput(trimmedLine)
                            

                            
                            DispatchQueue.main.async {
                                // تحديث البيانات الأساسية
                                if parsedData.totalBytes > 0 {
                                    item.fileSize = parsedData.totalBytes
                                }
                                
                                if parsedData.downloadedBytes > 0 {
                                    item.downloadedSize = parsedData.downloadedBytes
                                }
                                
                                // ✅ إصلاح: توحيد مصدر البيانات من AxelOutputParser
                                
                                // تحديث حجم الملف إذا لم يكن محدداً
                                if item.fileSize == 0 && parsedData.totalBytes > 0 {
                                    item.fileSize = parsedData.totalBytes

                                }
                                
                                // تحديث التقدم - استخدام البيانات من axel مباشرة
                                if parsedData.progress > 0 {
                                    let oldProgress = item.progress
                                    item.progress = parsedData.progress
                                    item.downloadedSize = Int64(Double(item.fileSize) * parsedData.progress)
                                    

                                    
                                    // تحديث الواجهة فوراً عند تغيير التقدم
                                    self.objectWillChange.send()
                                }
                                
                                // كشف السرعة من axel - المصدر الرئيسي للسرعة
                                if parsedData.speedBytesPerSec > 0 {
                                    let oldSpeed = item.instantSpeed
                                    item.instantSpeed = parsedData.speedBytesPerSec
                                    item.downloadSpeed = self.formatSpeedString(parsedData.speedBytesPerSec)
                                    

                                    
                                    // إزالة tracker إذا حصلنا على سرعة من axel
                                    self.downloadSpeedTrackers.removeValue(forKey: item.id)
                                    
                                    // تحديث الواجهة فوراً عند تغيير السرعة
                                    self.objectWillChange.send()
                                }
                                
                                // تحديث الوقت المتبقي
                                if !parsedData.eta.isEmpty && parsedData.eta != "--:--" {
                                    item.remainingTime = parsedData.eta
                                } else if item.instantSpeed > 0 && item.fileSize > item.downloadedSize {
                                    let remaining = item.fileSize - item.downloadedSize
                                    let seconds = Double(remaining) / item.instantSpeed
                                    item.remainingTime = self.formatTime(seconds)
                                }
                                
                                // ✅ إصلاح: التحقق من اكتمال التحميل مع فحص شامل للحالة
                                if parsedData.isComplete {
                                    // فحص شامل: التأكد من أن التحميل لم يتم إيقافه مؤقتاً
                                    if item.status != .paused && !item.wasManuallyPaused && item.status == .downloading {
                                        item.status = .completed
                                        item.progress = 1.0
                                        item.downloadSpeed = "Completed"
                                        item.remainingTime = "00:00"
                                        item.instantSpeed = 0 // ✅ إصلاح: إيقاف السرعة عند الاكتمال
                                        print("✅ Axel download completed: \(item.fileName)")
                                        
                                        // ✅ إصلاح: إيقاف RealTimeSpeedTracker عند الاكتمال
                                        RealTimeSpeedTracker.shared.remove(for: item.id)
                                        self.downloadSpeedTrackers.removeValue(forKey: item.id)
                                        
                                        self.objectWillChange.send()
                                        
                                        // ✅ إصلاح: نقل الملف فوراً عند اكتشاف الاكتمال
                                        self.moveCompletedFile(for: item, tempPath: tempDownloadPath, tempFileName: tempFileName, finalPath: expandedPath)
                                    } else {
                                        print("⚠️ [VIEWMODEL] Ignoring completion - download is paused or manually stopped")
                                    }
                                }
                                
                                // ✅ إصلاح: إزالة التحديثات الدورية المتضاربة
                                // البيانات من AxelOutputParser كافية لتحديث الواجهة
                            }
                        }
                    }
                }
            }
            
            var errorOutput = ""
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                
                if let error = String(data: data, encoding: .utf8) {
                    errorOutput += error
                    // لا نطبع أخطاء الاتصال المؤقتة
                    if !error.contains("timeout") && !error.contains("Connection") {
                        print("⚠️ axel error: \(error)")
                    }
                }
            }
            
            // تشغيل العملية
            do {
                try process.run()
                DispatchQueue.main.sync {
                    item.processTask = process
                    item.status = .downloading
                }
                
                process.waitUntilExit()
                
                // تنظيف
                DispatchQueue.main.async {
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    let exitCode = process.terminationStatus
                    
                    if item.status == .paused || item.wasManuallyPaused {
                        print("⏸️ Download paused by user")
                    } else if exitCode == 0 || item.status == .completed {
                        // ✅ إصلاح: نقل الملف إذا كان exitCode == 0 أو إذا كان التحميل مكتملاً
                        let tempFilePath = "\(tempDownloadPath)/\(tempFileName)"
                        let finalFilePath = "\(expandedPath)/\(item.fileName)"
                        

                        
                        do {
                            // حذف الملف النهائي إذا كان موجوداً
                            if FileManager.default.fileExists(atPath: finalFilePath) {
                                try FileManager.default.removeItem(atPath: finalFilePath)
                            }
                            
                            // نقل الملف المؤقت إلى المكان النهائي
                            try FileManager.default.moveItem(atPath: tempFilePath, toPath: finalFilePath)
                            
                            // حذف المجلد المؤقت إذا كان فارغاً
                            try? FileManager.default.removeItem(atPath: tempDownloadPath)
                            
                            // حذف الملف المخفي عند اكتمال التحميل
                            self.removeHiddenDownloadFile(for: item)
                            
                            item.status = .completed
                            item.progress = 1.0
                            item.downloadSpeed = "Completed"
                            item.remainingTime = "00:00"
                            item.instantSpeed = 0
                            print("✅ Download completed and moved: \(item.fileName)")
                            self.notificationManager.sendDownloadCompleteNotification(for: item)
                        } catch {
                            print("❌ Failed to move completed file: \(error)")
                            item.status = .failed
                            self.showError("Failed to save completed file", for: item)
                        }
                    } else if !NetworkMonitor.shared.isConnected {
                        // لا تفشل التحميل عند انقطاع الإنترنت
                        print("⏸️ Download paused due to no internet connection")
                        item.status = .paused
                        item.wasManuallyPaused = false
                    } else {
                        // ✅ إصلاح: معالجة أفضل للأخطاء الشائعة
                        let errorMessage = self.getAxelErrorMessage(exitCode: exitCode)
                        
                        // التحقق من إمكانية إعادة المحاولة
                        if self.canRetryDownload(exitCode: exitCode) {
                            print("🔄 Retrying download due to error code: \(exitCode)")
                            item.status = .waiting
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                self.startDownload(for: item)
                            }
                        } else {
                            // حذف الملف المخفي عند فشل التحميل
                            self.removeHiddenDownloadFile(for: item)
                            
                            item.status = .failed
                            // تنظيف الملفات المؤقتة عند الفشل
                            let tempFilePath = "\(tempDownloadPath)/\(tempFileName)"
                            try? FileManager.default.removeItem(atPath: tempFilePath)
                            self.showError("Download failed: \(errorMessage)", for: item)
                        }
                    }
                    
                    // تنظيف تتبع السرعة
                    RealTimeSpeedTracker.shared.remove(for: item.id)
                    self.saveDownloads()
                }
            } catch {
                print("💥 Failed to start download: \(error)")
                DispatchQueue.main.async {
                    item.status = .failed
                    self.saveDownloads()
                    self.showError("Failed to start download: \(error.localizedDescription)", for: item)
                }
            }
        }
    }
    
    // MARK: - File Management
    private func moveCompletedFile(for item: DownloadItem, tempPath: String, tempFileName: String, finalPath: String) {
        let tempFilePath = "\(tempPath)/\(tempFileName)"
        let finalFilePath = "\(finalPath)/\(item.fileName)"
        
        do {
            // حذف الملف النهائي إذا كان موجوداً
            if FileManager.default.fileExists(atPath: finalFilePath) {
                try FileManager.default.removeItem(atPath: finalFilePath)
            }
            
            // نقل الملف المؤقت إلى المكان النهائي
            try FileManager.default.moveItem(atPath: tempFilePath, toPath: finalFilePath)
            
            // حذف المجلد المؤقت إذا كان فارغاً
            try? FileManager.default.removeItem(atPath: tempPath)
            
            // حذف الملف المخفي عند اكتمال التحميل
            self.removeHiddenDownloadFile(for: item)
            
            print("✅ File moved successfully: \(item.fileName)")
            self.notificationManager.sendDownloadCompleteNotification(for: item)
        } catch {
            print("❌ Failed to move completed file: \(error)")
            // لا نغير حالة التحميل إلى failed هنا، فقط نطبع الخطأ
        }
    }
    
    // MARK: - Fallback Download
    private func fallbackDownload(for item: DownloadItem) {
        print("🔄 Using fallback axel download for: \(item.fileName)")
        
        guard let url = URL(string: item.url) else {
            DispatchQueue.main.async {
                item.status = .failed
                self.showError("Invalid URL", for: item)
            }
            return
        }
        
        // البحث عن axel في النظام
        let possiblePaths = [
            "/opt/homebrew/bin/axel",
            "/usr/local/bin/axel",
            "/usr/bin/axel",
            "/bin/axel"
        ]
        
        var axelPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                axelPath = path
                break
            }
        }
        
        guard let finalPath = axelPath else {
            print("❌ axel not found in system, using URLSession")
            self.fallbackToURLSession(for: item)
            return
        }
        
        // إنشاء العملية
        let process = Process()
        process.executableURL = URL(fileURLWithPath: finalPath)
        
        let expandedPath = expandTildePath(item.savePath)
        let finalOutputPath = "\(expandedPath)/\(item.fileName)"
        
        // إنشاء المجلد إذا لم يكن موجوداً
        do {
            try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create directory: \(error)")
            DispatchQueue.main.async {
                item.status = .failed
                self.saveDownloads()
                self.showError("Failed to create directory", for: item)
            }
            return
        }
        
        // إعدادات axel بسيطة
        var arguments: [String] = [
            "-n", "8",                              // 8 اتصالات
            "-o", item.fileName,                    // اسم الملف
            "-v",                                   // verbose output
            "-k",                                   // لا تتحقق من الشهادة
            "-T", "30",                             // timeout 30 ثانية
            "-U", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"  // user agent
        ]
        
        // إضافة URL
        arguments.append(item.url)
        
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: expandedPath)
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        var outputBuffer = ""
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let output = String(data: data, encoding: .utf8) {
                outputBuffer += output
                
                let lines = outputBuffer.components(separatedBy: .newlines)
                outputBuffer = lines.last ?? ""
                
                for line in lines.dropLast() {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine.isEmpty { continue }
                    
                    let parsedData = AxelOutputParser.parseOutput(trimmedLine)
                    
                    DispatchQueue.main.async {
                        if parsedData.totalBytes > 0 {
                            item.fileSize = parsedData.totalBytes
                        }
                        
                        if parsedData.downloadedBytes > 0 {
                            item.downloadedSize = parsedData.downloadedBytes
                        }
                        
                        if parsedData.progress > 0 {
                            item.progress = parsedData.progress
                        }
                        
                        if parsedData.speedBytesPerSec > 0 {
                            item.instantSpeed = parsedData.speedBytesPerSec
                            item.downloadSpeed = self?.formatSpeedString(parsedData.speedBytesPerSec) ?? "0 KB/s"
                        }
                        
                        if parsedData.isComplete {
                            item.status = .completed
                            item.progress = 1.0
                            item.downloadSpeed = "Completed"
                            item.remainingTime = "00:00"
                            print("✅ Fallback axel download completed: \(item.fileName)")
                            self?.notificationManager.sendDownloadCompleteNotification(for: item)
                            self?.saveDownloads()
                        }
                        
                        self?.objectWillChange.send()
                    }
                }
            }
        }
        
        do {
            try process.run()
            DispatchQueue.main.async {
                item.processTask = process
                item.status = .downloading
                item.downloadSpeed = "Starting..."
                self.objectWillChange.send()
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    print("✅ Fallback axel download completed: \(item.fileName)")
                } else {
                    print("❌ Fallback axel download failed with exit code: \(process.terminationStatus)")
                    item.status = .failed
                    self.showError("Download failed", for: item)
                }
                
                self.saveDownloads()
            }
        } catch {
            print("💥 Failed to start fallback axel download: \(error)")
            DispatchQueue.main.async {
                item.status = .failed
                self.saveDownloads()
                self.showError("Failed to start download: \(error.localizedDescription)", for: item)
            }
        }
    }
    
    // MARK: - Fallback to URLSession
    private func fallbackToURLSession(for item: DownloadItem) {
        print("🔄 Using URLSession as final fallback for: \(item.fileName)")
        
        guard let url = URL(string: item.url) else {
            DispatchQueue.main.async {
                item.status = .failed
                self.showError("Invalid URL", for: item)
            }
            return
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        
        let session = URLSession(configuration: config)
        
        let task = session.downloadTask(with: url) { [weak self, weak item] location, response, error in
            guard let self = self, let item = item else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    item.status = .failed
                    self.showError("Download failed: \(error.localizedDescription)", for: item)
                    self.saveDownloads()
                }
                return
            }
            
            guard let location = location else {
                DispatchQueue.main.async {
                    item.status = .failed
                    self.showError("No file downloaded", for: item)
                    self.saveDownloads()
                }
                return
            }
            
            // نقل الملف إلى المكان المطلوب
            let expandedPath = self.expandTildePath(item.savePath)
            let destinationURL = URL(fileURLWithPath: expandedPath).appendingPathComponent(item.fileName)
            
            do {
                // حذف الملف القديم إذا كان موجوداً
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // نقل الملف
                try FileManager.default.moveItem(at: location, to: destinationURL)
                
                DispatchQueue.main.async {
                    item.status = .completed
                    item.progress = 1.0
                    item.downloadSpeed = "Completed"
                    print("✅ Download completed (URLSession fallback): \(item.fileName)")
                    self.notificationManager.sendDownloadCompleteNotification(for: item)
                    self.saveDownloads()
                }
            } catch {
                DispatchQueue.main.async {
                    item.status = .failed
                    self.showError("Failed to save file: \(error.localizedDescription)", for: item)
                    self.saveDownloads()
                }
            }
        }
        
        // مراقبة التقدم
        let observation = task.progress.observe(\Progress.fractionCompleted, options: [.new]) { [weak item] progress, _ in
            guard let item = item else { return }
            DispatchQueue.main.async {
                item.progress = progress.fractionCompleted
                item.downloadedSize = Int64(Double(item.fileSize) * progress.fractionCompleted)
                _ = RealTimeSpeedTracker.shared.updateSpeed(
                    for: item.id,
                    currentBytes: item.downloadedSize,
                    totalBytes: item.fileSize
                )
            }
        }
        
        DispatchQueue.main.async {
            item.status = .downloading
            self.objectWillChange.send()
        }
        
        // بدء التحميل مع الاحتفاظ بالمراقب
        withExtendedLifetime(observation) {
            task.resume()
        }
    }
    
    // MARK: - Handle Resume Error
    private func handleResumeError(for item: DownloadItem) {
        let alert = NSAlert()
        alert.messageText = "Cannot Resume Download"
        alert.informativeText = "The download cannot be resumed. Would you like to start over?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Start Over")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            deleteExistingFile(for: item)
            item.downloadedSize = 0
            item.progress = 0
            performNormalDownload(for: item, resume: false)
        } else {
            item.status = .failed
            saveDownloads()
        }
    }
    
    
    // MARK: - Torrent Check Result
enum TorrentCheckResult {
    case complete(size: Int64)
    case incomplete(downloadedSize: Int64, totalSize: Int64)
    case notExists
}


    // MARK: - Torrent Operations
    func checkExistingTorrent(url: String, savePath: String) -> TorrentCheckResult {
        let expandedPath = expandTildePath(savePath)
        let torrentName = URL(fileURLWithPath: url).deletingPathExtension().lastPathComponent
        
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: expandedPath)
            
            var hasCompleteFiles = false
            var hasIncompleteFiles = false
            var totalSize: Int64 = 0
            var downloadedSize: Int64 = 0
            
            for file in files {
                if file.contains(torrentName) && !file.hasSuffix(".aria2") {
                    let filePath = URL(fileURLWithPath: expandedPath).appendingPathComponent(file).path
                    let controlFile = "\(filePath).aria2"
                    
                    if let attributes = try? fileManager.attributesOfItem(atPath: filePath) {
                        let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
                        totalSize += fileSize
                        
                        if fileManager.fileExists(atPath: controlFile) {
                            hasIncompleteFiles = true
                            downloadedSize += fileSize
                        } else {
                            hasCompleteFiles = true
                            downloadedSize += fileSize
                        }
                    }
                }
            }
            
            if hasCompleteFiles && !hasIncompleteFiles {
                return .complete(size: totalSize)
            } else if hasIncompleteFiles {
                return .incomplete(downloadedSize: downloadedSize, totalSize: totalSize)
            }
        } catch {
            print("❌ Error checking torrent files: \(error)")
        }
        
        return .notExists
    }
    
    func parseTorrentFile(url: URL) {
        print("📥 Parsing torrent file: \(url.path)")
        pendingTorrentURL = url.path
        currentTorrentFiles = []

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.settings.aria2Path)
            process.arguments = [
                "--show-files=true",
                url.path
            ]
            let outputPipe = Pipe()
            process.standardOutput = outputPipe

            do {
                try process.run()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if let output = String(data: data, encoding: .utf8) {
                    var files: [TorrentFile] = []
                    let lines = output.components(separatedBy: .newlines)
                    var isInFilesList = false
                    var lastFileName: String?
                    var idx = 0

                    for line in lines {
                        if line.contains("idx|path/length") {
                            isInFilesList = true
                            continue
                        }
                        if isInFilesList && line.contains("===") {
                            continue
                        }
                        if isInFilesList && line.hasPrefix("---+"){
                            break
                        }
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if isInFilesList && !trimmed.isEmpty {
                            if let barIndex = line.firstIndex(of: "|") {
                                let left = line[..<barIndex].trimmingCharacters(in: .whitespaces)
                                let right = line[line.index(after: barIndex)...].trimmingCharacters(in: .whitespaces)
                                
                                if let index = Int(left), index > 0 {
                                    lastFileName = right.replacingOccurrences(of: "./", with: "")
                                    idx = index
                                } else if left.isEmpty && right.contains("(") && lastFileName != nil {
                                    let sizePart = right
                                    if let sizeMatch = sizePart.range(of: #"\((\d+(?:,\d+)*)\)"#, options: .regularExpression) {
                                        let sizeStr = String(sizePart[sizeMatch])
                                            .replacingOccurrences(of: "(", with: "")
                                            .replacingOccurrences(of: ")", with: "")
                                            .replacingOccurrences(of: ",", with: "")
                                        if let size = Int64(sizeStr) {
                                            let fileName = lastFileName!
                                            files.append(
                                                TorrentFile(
                                                    index: idx,
                                                    name: fileName,
                                                    size: size,
                                                    isSelected: true,
                                                    path: fileName
                                                )
                                            )
                                            lastFileName = nil
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        self.currentTorrentFiles = files
                        self.fetchTorrentInfo(url: url)
                        self.showTorrentFiles = true
                    }
                }
            } catch {
                print("❌ Failed to parse torrent: \(error)")
            }
        }
    }
    
    func fetchTorrentInfo(url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: self.settings.aria2Path)
            process.arguments = [
                "--bt-tracker-connect-timeout=5",
                "--bt-tracker-timeout=5",
                "--enable-dht=true",
                "--show-console-readout=true",
                "--summary-interval=0",
                "--dry-run=true",
                url.path
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                    process.terminate()
                }
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    self.parseTorrentStatistics(output: output)
                }
                
                process.waitUntilExit()
            } catch {
                print("❌ Failed to fetch torrent info: \(error)")
                DispatchQueue.main.async {
                    self.currentTorrentInfo = TorrentInfo(
                        name: URL(fileURLWithPath: self.pendingTorrentURL).deletingPathExtension().lastPathComponent,
                        peersCount: 0,
                        seedsCount: 0,
                        totalSize: self.currentTorrentFiles.reduce(0) { $0 + $1.size },
                        filesCount: self.currentTorrentFiles.count
                    )
                }
            }
        }
    }
    
    func startTorrentDownloadProcess(url: String, savePath: String, resume: Bool = false, forceNew: Bool = false) {
        if let existingDownload = downloads.first(where: {
            $0.url == url && $0.savePath == savePath && !forceNew
        }) {
            if resume {
                existingDownload.status = .waiting
                startDownload(for: existingDownload)
            } else if !forceNew {
                existingDownload.status = .waiting
                startDownload(for: existingDownload)
            }
        } else {
            let torrentName = URL(fileURLWithPath: url).deletingPathExtension().lastPathComponent
            let fileName = forceNew ? "\(torrentName)_\(Int(Date().timeIntervalSince1970))" : torrentName
            
            let newDownload = DownloadItem(
                fileName: fileName,
                url: url,
                fileSize: currentTorrentFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size },
                fileType: .torrent
            )
            newDownload.savePath = savePath
            newDownload.isTorrent = true
            
            downloads.insert(newDownload, at: 0)
            saveDownloads()
            startDownload(for: newDownload)
        }
        
        currentTorrentFiles = []
        pendingTorrentURL = ""
        showTorrentFiles = false
    }
    
    func startTorrentDownload(for item: DownloadItem) {
        DispatchQueue.global(qos: .background).async { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            
            let expandedPath = self.expandTildePath(item.savePath)
            let process = Process()
            
            do {
                try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed to create directory: \(error)")
            }
            
            process.executableURL = URL(fileURLWithPath: self.settings.aria2Path)
            
            let downloadPath = item.fileName.contains("_") ? "\(expandedPath)/\(item.fileName)" : expandedPath
            if item.fileName.contains("_") {
                try? FileManager.default.createDirectory(atPath: downloadPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // استخدام الإعدادات المتوافقة من TorrentPerformanceOptimizer
            var arguments = TorrentPerformanceOptimizer.getCompatibleTorrentArguments(downloadPath: downloadPath, expandedPath: expandedPath)
            
            if !self.currentTorrentFiles.isEmpty {
                let selectedIndexes = self.currentTorrentFiles
                    .filter { $0.isSelected }
                    .map { String($0.index) }
                    .joined(separator: ",")
                
                if !selectedIndexes.isEmpty {
                    arguments.append("--select-file=\(selectedIndexes)")
                }
            }
            
            arguments.append(item.url)
            
            process.arguments = arguments
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            let outputHandle = outputPipe.fileHandleForReading
            outputHandle.readabilityHandler = { [weak self] handle in
                guard let self = self else { return }
                let data = handle.availableData
                if data.isEmpty { return }
                
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.parseAria2Output(output, for: item.id)
                        // تحديث إحصائيات التورنت كل 5 ثوانٍ فقط
                        let now = Date()
                        if item.isTorrent && (item.lastPeersUpdate == nil || now.timeIntervalSince(item.lastPeersUpdate!) >= 5.0) {
                            self.parseTorrentStats(output, for: item)
                        }
                    }
                }
            }
            
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                
                if let errorOutput = String(data: data, encoding: .utf8) {
                    print("⚠️ Aria2 error: \(errorOutput)")
                }
            }
            
            do {
                try process.run()
                DispatchQueue.main.sync {
                    item.processTask = process
                    item.status = .downloading
                }
                
                process.waitUntilExit()
                
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                
                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        item.status = .completed
                        item.progress = 1.0
                        item.downloadSpeed = "Completed"
                        item.remainingTime = "00:00"
                        item.uploadSpeed = "0 KB/s"
                        print("✅ Torrent download completed: \(item.fileName)")
                        
                        self.notificationManager.sendDownloadCompleteNotification(for: item)
                    } else {
                        if item.status != .paused {
                            item.status = .failed
                            print("❌ Torrent download failed with status: \(process.terminationStatus)")
                            
                            self.notificationManager.sendDownloadFailedNotification(for: item)
                        }
                    }
                    self.saveDownloads()
                }
            } catch {
                print("💥 Failed to start torrent download: \(error)")
                DispatchQueue.main.async {
                    item.status = .failed
                    self.saveDownloads()
                    self.notificationManager.sendDownloadFailedNotification(for: item, reason: "Failed to start torrent: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func parseTorrentStatistics(output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        var peersCount = 0
        var seedsCount = 0
        
        for line in lines {
            let peerPatterns = [
                #"Peer\((\d+)/(\d+)\)"#,
                #"Peers?\s*(\d+)"#,
                #"Connected.*?(\d+)"#
            ]
            
            for pattern in peerPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[range])
                    let numbers = matchString.replacingOccurrences(of: "Peer(", with: "").replacingOccurrences(of: ")", with: "")
                    let parts = numbers.components(separatedBy: "/")
                    if parts.count == 2 {
                        peersCount = Int(parts[0]) ?? 0
                    }
                    break
                }
            }
            
            let seedPatterns = [
                #"Seed\((\d+)\)"#,
                #"Seeds?\s*(\d+)"#,
                #"Seeders?\s*(\d+)"#
            ]
            
            for pattern in seedPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[range])
                    let number = matchString.replacingOccurrences(of: "Seed(", with: "").replacingOccurrences(of: ")", with: "")
                    seedsCount = Int(number) ?? 0
                    break
                }
            }
        }
        
        DispatchQueue.main.async {
            self.currentTorrentInfo = TorrentInfo(
                name: URL(fileURLWithPath: self.pendingTorrentURL).deletingPathExtension().lastPathComponent,
                peersCount: peersCount,
                seedsCount: seedsCount,
                totalSize: self.currentTorrentFiles.reduce(0) { $0 + $1.size },
                filesCount: self.currentTorrentFiles.count
            )
        }
    }
    
    func parseTorrentStats(_ output: String, for item: DownloadItem) {
        let lines = output.components(separatedBy: .newlines)
        
        // حساب عدد الاتصالات الفريدة
        var uniqueConnections = Set<String>()
        
        for line in lines {
            // Debug: طباعة كل سطر للتورنت
            if item.isTorrent && (line.contains("Peer") || line.contains("Seed") || line.contains("CUID#")) {
                print("🔍 [TORRENT_STATS] Line: \(line)")
            }
            
            // استخراج عناوين IP من الاتصالات
            if line.contains("CUID#") && (line.contains("From:") || line.contains("To:")) {
                let ipPattern = #"(\d+\.\d+\.\d+\.\d+):\d+"#
                if let range = line.range(of: ipPattern, options: .regularExpression) {
                    let ipAddress = String(line[range])
                    uniqueConnections.insert(ipAddress)
                }
            }
            
            let peerPatterns = [
                #"Peer\((\d+)/(\d+)\)"#,
                #"Peers?\s*(\d+)"#,
                #"Connected.*?(\d+)"#,
                #"CUID#\d+.*?From:\s*(\d+\.\d+\.\d+\.\d+)"#,
                #"CUID#\d+.*?To:\s*(\d+\.\d+\.\d+\.\d+)"#
            ]
            
            for pattern in peerPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[range])
                    let numbers = extractNumbers(from: matchString)
                    
                    if numbers.count >= 2 {
                        let newPeers = "\(numbers[0])/\(numbers[1])"
                        if item.peers != newPeers {
                            DispatchQueue.main.async {
                                item.peers = newPeers
                                item.lastPeersUpdate = Date()
                                print("🌱 [TORRENT_STATS] Updated peers: \(item.peers)")
                            }
                        }
                    } else if numbers.count == 1 {
                        let newPeers = "\(numbers[0])"
                        if item.peers != newPeers {
                            DispatchQueue.main.async {
                                item.peers = newPeers
                                item.lastPeersUpdate = Date()
                                print("🌱 [TORRENT_STATS] Updated peers: \(item.peers)")
                            }
                        }
                    }
                    break
                }
            }
            
            let seedPatterns = [
                #"Seed\((\d+)\)"#,
                #"Seeds?\s*(\d+)"#,
                #"Seeders?\s*(\d+)"#,
                #"Announce.*?(\d+)\s*seeds"#
            ]
            
            for pattern in seedPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[range])
                    let numbers = extractNumbers(from: matchString)
                    
                    if let seedCount = numbers.first {
                        let newSeeds = "\(seedCount)"
                        if item.seeds != newSeeds {
                            DispatchQueue.main.async {
                                item.seeds = newSeeds
                                item.lastSeedsUpdate = Date()
                                print("🌱 [TORRENT_STATS] Updated seeds: \(item.seeds)")
                            }
                        }
                        break
                    }
                }
            }
            
            let uploadPatterns = [
                #"UP:\s*([0-9.]+[KMGT]?B/s)"#,
                #"Upload:\s*([0-9.]+[KMGT]?B/s)"#,
                #"↑\s*([0-9.]+[KMGT]?B/s)"#
            ]
            
            for pattern in uploadPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let matchString = String(line[range])
                    if let speedRange = matchString.range(of: #"[0-9.]+[KMGT]?B/s"#, options: .regularExpression) {
                        let uploadSpeed = String(matchString[speedRange])
                        DispatchQueue.main.async {
                            item.uploadSpeed = uploadSpeed
                        }
                        break
                    }
                }
            }
        }
        
        // تحديث عدد الاتصالات الفريدة إذا لم يتم العثور على معلومات أخرى
        if !uniqueConnections.isEmpty {
            let connectionCount = uniqueConnections.count
            
            // تحديث فقط إذا كانت القيم فارغة أو صفر، أو إذا تغير عدد الاتصالات بشكل كبير
            let currentPeers = Int(item.peers) ?? 0
            let currentSeeds = Int(item.seeds) ?? 0
            
            let shouldUpdatePeers = (item.peers.isEmpty || item.peers == "0" || abs(connectionCount - currentPeers) >= 3) && 
                                   (Date().timeIntervalSince(item.lastPeersUpdate ?? Date.distantPast) >= 3.0)
            let shouldUpdateSeeds = (item.seeds.isEmpty || item.seeds == "0" || abs(connectionCount - currentSeeds) >= 3) && 
                                   (Date().timeIntervalSince(item.lastSeedsUpdate ?? Date.distantPast) >= 3.0)
            
            if shouldUpdatePeers {
                DispatchQueue.main.async {
                    item.peers = "\(connectionCount)"
                    item.lastPeersUpdate = Date()
                    print("🌱 [TORRENT_STATS] Updated peers from connections: \(item.peers)")
                }
            }
            
            if shouldUpdateSeeds {
                DispatchQueue.main.async {
                    // تقدير بسيط: 20% من الاتصالات هي seeds
                    let estimatedSeeds = max(1, Int(Double(connectionCount) * 0.5))
                    item.seeds = "\(estimatedSeeds)"
                    item.lastSeedsUpdate = Date()
                    print("🌱 [TORRENT_STATS] Updated seeds from connections: \(item.seeds)")
                }
            }
        }
    }
    
    private func extractNumbers(from string: String) -> [Int] {
        let pattern = #"\d+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: string) {
                return Int(String(string[range]))
            }
            return nil
        }
    }

    // MARK: - Parse Aria2 Output
    func parseAria2Output(_ output: String, for id: UUID) {
        guard let item = downloads.first(where: { $0.id == id }) else { return }
        
        // طباعة تشخيصية للاستئناف
        if item.downloadSpeed.contains("Resuming") || item.downloadSpeed.contains("Connecting") {
            print("🔍 [RESUME] Output: \(output)")
        }
        
        // استخدام parser
        let parsedData = Aria2OutputParser.parseOutput(output)
        
        DispatchQueue.main.async {
            // تحديث peers و seeds للتورنت مع تأخير زمني
            if item.isTorrent {
                let oldPeers = item.peers
                let oldSeeds = item.seeds
                let newPeers = parsedData.peers > 0 ? String(parsedData.peers) : "0"
                let newSeeds = parsedData.seeders > 0 ? String(parsedData.seeders) : "0"
                
                // تحديث فقط إذا تغيرت القيم بشكل كبير أو بعد مرور وقت كافٍ
                let shouldUpdatePeers = abs((Int(newPeers) ?? 0) - (Int(oldPeers) ?? 0)) >= 5 || 
                                       (Date().timeIntervalSince(item.lastPeersUpdate ?? Date.distantPast) >= 10.0)
                let shouldUpdateSeeds = abs((Int(newSeeds) ?? 0) - (Int(oldSeeds) ?? 0)) >= 5 || 
                                       (Date().timeIntervalSince(item.lastSeedsUpdate ?? Date.distantPast) >= 10.0)
                
                if shouldUpdatePeers {
                    item.peers = newPeers
                    item.lastPeersUpdate = Date()
                    print("🌱 [TORRENT] Peers updated: \(oldPeers) -> \(item.peers)")
                }
                
                if shouldUpdateSeeds {
                    item.seeds = newSeeds
                    item.lastSeedsUpdate = Date()
                    print("🌱 [TORRENT] Seeds updated: \(oldSeeds) -> \(item.seeds)")
                }
            }
            var dataUpdated = false
            
            // تحديث الحجم الكلي
            if parsedData.totalBytes > 0 && parsedData.totalBytes != item.fileSize {
                item.fileSize = parsedData.totalBytes
                dataUpdated = true
            }
            
            // تحديث الحجم المحمل
            if parsedData.downloadedBytes > 0 {
                let oldSize = item.downloadedSize
                item.downloadedSize = parsedData.downloadedBytes
                
                // إذا تغير الحجم، احسب السرعة
                if oldSize != item.downloadedSize && oldSize > 0 {
                    let timeDiff = 0.5 // نصف ثانية
                    let bytesDiff = item.downloadedSize - oldSize
                    let calculatedSpeed = Double(bytesDiff) / timeDiff
                    
                    if calculatedSpeed > 0 && parsedData.speedBytesPerSec == 0 {
                        item.instantSpeed = calculatedSpeed
                        item.downloadSpeed = self.formatSpeedString(calculatedSpeed)
                        print("📊 Calculated speed from size change: \(item.downloadSpeed)")
                    }
                }
                
                dataUpdated = true
            }
            
            // تحديث التقدم - إصلاح مشكلة النسبة المئوية عند الاستئناف
            if item.fileSize > 0 {
                // ✅ إصلاح: عند الاستئناف، احتفظ بالنسبة المئوية المحفوظة حتى نتأكد من صحة البيانات
                let isResuming = item.downloadSpeed.contains("Resuming") || 
                                item.downloadSpeed.contains("Connecting") ||
                                item.downloadSpeed.contains("Starting")
                
                if isResuming && item.downloadedSize == 0 {
                    // إذا كان الاستئناف والحجم المحمل صفر، احتفظ بالنسبة المئوية المحفوظة
                    print("🔒 [RESUME] Keeping saved progress: \(Int(item.progress * 100))%")
                } else {
                    // احسب النسبة المئوية الجديدة فقط إذا كانت البيانات صحيحة
                    let newProgress = Double(item.downloadedSize) / Double(item.fileSize)
                    
                    // ✅ إصلاح: تأكد من أن النسبة المئوية منطقية
                    if newProgress >= 0 && newProgress <= 1.0 && newProgress != item.progress {
                        // ✅ إصلاح: منع القفزات المفاجئة في النسبة المئوية
                        let progressDiff = abs(newProgress - item.progress)
                        if progressDiff < 0.1 || item.downloadedSize > 0 { // السماح بتغيير صغير أو إذا كان هناك تقدم حقيقي
                            item.updateProgress(newProgress)
                            dataUpdated = true
                            print("📊 Progress updated: \(Int(newProgress * 100))%")
                        } else {
                            print("⚠️ Skipping suspicious progress jump: \(Int(item.progress * 100))% -> \(Int(newProgress * 100))%")
                        }
                    }
                }
            }
            
            // تحديث السرعة من aria2
            if parsedData.speedBytesPerSec > 0 {
                // ✅ إصلاح: تحديث الحالة أولاً إلى "Downloading" إذا كانت هناك سرعة
                if item.downloadSpeed.contains("Starting") || 
                   item.downloadSpeed.contains("Resuming") || 
                   item.downloadSpeed.contains("Connecting") {
                    item.downloadSpeed = "Downloading..."
                    print("📝 Status updated: Downloading...")
                }
                
                // استخدام الدالة الجديدة في DownloadItem
                item.updateSpeed(parsedData.speedBytesPerSec, displaySpeed: "Downloading...")
                
                // إعادة تعيين RealTimeSpeedTracker عند الحصول على سرعة من aria2
                RealTimeSpeedTracker.shared.reset(for: item.id)
                
                // إجبار تحديث UI فوراً
                self.objectWillChange.send()
                
                dataUpdated = true
            } else if parsedData.downloadedBytes > 0 {
                // ✅ إصلاح: إذا لم تكن هناك سرعة من aria2 ولكن هناك تقدم، استخدم RealTimeSpeedTracker
                let speedResult = RealTimeSpeedTracker.shared.updateSpeed(
                    for: item.id,
                    currentBytes: item.downloadedSize,
                    totalBytes: item.fileSize
                )
                
                if speedResult.speed > 0 {
                    item.updateSpeed(speedResult.speed, displaySpeed: speedResult.displaySpeed)
                    print("✅ RealTimeSpeedTracker speed detected: \(item.downloadSpeed)")
                    self.objectWillChange.send()
                    dataUpdated = true
                } else if item.instantSpeed > 0 {
                    // ✅ إصلاح: احتفظ بالسرعة السابقة إذا لم تكن هناك سرعة جديدة
                    print("🔍 Keeping previous speed: \(item.downloadSpeed)")
                    self.objectWillChange.send()
                    dataUpdated = true
                } else {
                    // إذا لم تنجح RealTimeSpeedTracker، استخدم الكشف الذكي
                    self.smartSpeedDetection(for: item)
                    
                    // ✅ إصلاح: إذا لم تنجح أي طريقة، استخدم سرعة افتراضية فقط إذا كانت السرعة صفر
                    if item.instantSpeed == 0 && (item.downloadSpeed.contains("Connecting") || item.downloadSpeed.contains("Waiting")) {
                        let fallbackSpeed = 1024.0 // 1 KB/s
                        item.updateSpeed(fallbackSpeed, displaySpeed: "Slow")
                        print("⚠️ Using fallback speed: \(item.downloadSpeed)")
                        self.objectWillChange.send()
                dataUpdated = true
                    }
                }
            }
            
            // تحديث الوقت المتبقي
            if parsedData.eta != "--:--" && !parsedData.eta.isEmpty {
                item.remainingTime = parsedData.eta
            } else if item.instantSpeed > 0 && item.fileSize > item.downloadedSize {
                let remaining = item.fileSize - item.downloadedSize
                let seconds = Double(remaining) / item.instantSpeed
                item.remainingTime = self.formatTime(seconds)
            }
            
            // تحديث معلومات Torrent
            if item.isTorrent {
                if parsedData.seeders > 0 {
                    item.seeds = "\(parsedData.seeders)"
                }
                if parsedData.peers > 0 {
                    item.peers = "\(parsedData.peers)"
                }
                if parsedData.uploadSpeed > 0 {
                    item.uploadSpeed = self.formatSpeedString(parsedData.uploadSpeed)
                }
            }
            
            if dataUpdated {
                self.objectWillChange.send()
                NotificationCenter.default.post(
                    name: .downloadProgressUpdated,
                    object: nil,
                    userInfo: ["downloadId": item.id]
                )
            }
        }
    }

    // MARK: - Smart Speed Detection for Resume
    private func smartSpeedDetection(for item: DownloadItem) {
        let currentTime = Date()
        let currentSize = item.downloadedSize
        
        // الحصول على أو إنشاء tracker
        if let tracker = downloadSpeedTrackers[item.id] {
            let timeDiff = currentTime.timeIntervalSince(tracker.lastTime)
            let sizeDiff = currentSize - tracker.lastSize
            
            if timeDiff >= 0.1 && sizeDiff > 0 { // تقليل إلى 0.1 ثانية للاستجابة الفورية
                // حساب السرعة
                let speed = Double(sizeDiff) / timeDiff
                
                // إضافة العينة
                var samples = tracker.speedSamples
                samples.append(speed)
                if samples.count > 1 { // تقليل إلى عينة واحدة للاستجابة الفورية
                    samples.removeFirst()
                }
                
                // حساب متوسط السرعة
                let avgSpeed = samples.reduce(0, +) / Double(samples.count)
                
                // تحديث السرعة إذا كانت معقولة
                if avgSpeed > 0 && avgSpeed < 100 * 1024 * 1024 { // أقل من 100MB/s
                    DispatchQueue.main.async {
                        // استخدام الدالة الجديدة في DownloadItem
                        item.updateSpeed(avgSpeed, displaySpeed: self.formatSpeedString(avgSpeed))
                        
                        // حساب الوقت المتبقي
                        if item.fileSize > currentSize {
                            let remaining = item.fileSize - currentSize
                            let seconds = Double(remaining) / avgSpeed
                            item.remainingTime = self.formatTime(seconds)
                        }
                        
                        print("🎯 Smart speed detected: \(item.downloadSpeed)")
                        
                        // إجبار تحديث UI فوراً
                        self.objectWillChange.send()
                    }
                }
                
                // تحديث tracker
                downloadSpeedTrackers[item.id] = (currentSize, currentTime, samples)
            }
        } else {
            // إنشاء tracker جديد
            downloadSpeedTrackers[item.id] = (currentSize, currentTime, [])
        }
    }

    // MARK: - Extension Communication
    private func setupExtensionCommunication() {
        // Setup for Safari Extension communication
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleExtensionDownload(_:)),
            name: NSNotification.Name("com.SafaR.Go.download"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }
    
    @objc private func handleExtensionDownload(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? String else { return }
        
        let fileName = userInfo["fileName"] as? String ?? "download"
        
        DispatchQueue.main.async {
            self.pendingURL = url
            self.pendingFileName = fileName
            QuickDownloadWindowController.shared.show(with: self)
        }
    }
    
    // MARK: - Extract Speed from Output
    private func extractSpeedFromOutput(_ line: String) -> Double? {
        // البحث عن سرعة في aria2 output
        let patterns = [
            "speed=([0-9.]+)([KMGT]?B/s)",
            "([0-9.]+)\\s*([KMGT]?B/s)",
            "([0-9.]+)\\s*([kmgt]?b/s)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: line.utf16.count)
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    if match.numberOfRanges > 2,
                       let speedRange = Range(match.range(at: 1), in: line),
                       let unitRange = Range(match.range(at: 2), in: line) {
                        
                        let speedStr = String(line[speedRange])
                        let unitStr = String(line[unitRange])
                        
                        if let speed = Double(speedStr) {
                            // تحويل الوحدة إلى bytes/s
                            let multiplier: Double
                            switch unitStr.uppercased() {
                            case "B/S": multiplier = 1
                            case "KB/S": multiplier = 1024
                            case "MB/S": multiplier = 1024 * 1024
                            case "GB/S": multiplier = 1024 * 1024 * 1024
                            default: multiplier = 1
                            }
                            
                            return speed * multiplier
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private func findYtDlpPath() -> String {
        // استخدام الدالة المحسنة من YouTubeDownloader.swift
        return findYtDlpPathOptimized()
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
    
    // MARK: - Bundled yt-dlp Path Finder
    private func findYtDlpPathOptimized() -> String {
        // البحث عن yt-dlp في bundle التطبيق فقط (Resources)
        if let bundledPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة مرة واحدة فقط
                        setupBundledEnvironmentOnce()
                        print("✅ Using bundled yt-dlp: \(bundledPath)")
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let writablePath = copyToWritableLocation(bundledPath, name: "yt-dlp") {
                    // تعيين متغيرات البيئة للمكتبات المدمجة مرة واحدة فقط
                    setupBundledEnvironmentOnce()
                    print("✅ Using copied yt-dlp: \(writablePath)")
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
                        // تعيين متغيرات البيئة للمكتبات المدمجة مرة واحدة فقط
                        setupBundledEnvironmentOnce()
                        print("✅ Using bundled yt-dlp from Scripts: \(bundledPath)")
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let writablePath = copyToWritableLocation(bundledPath, name: "yt-dlp") {
                    // تعيين متغيرات البيئة للمكتبات المدمجة مرة واحدة فقط
                    setupBundledEnvironmentOnce()
                    print("✅ Using copied yt-dlp from Scripts: \(writablePath)")
                    return writablePath
                }
            }
        }
        
        // إذا لم يوجد في bundle، استخدم المسار الافتراضي في Resources
        let defaultPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) ?? ""
        print("❌ yt-dlp not found in bundle. Expected path: \(defaultPath)")
        return defaultPath
    }
    
    // MARK: - Setup Environment Once (Optimized)
    private static var environmentSetup = false
    
    private func setupBundledEnvironmentOnce() {
        // تجنب إعداد البيئة مرات متعددة
        guard !Self.environmentSetup else { return }
        
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
        
        // إعداد متغيرات إضافية لتسريع بدء التحميل
        setenv("PYTHONOPTIMIZE", "1", 1)
        setenv("PYTHONFAULTHANDLER", "0", 1)
        setenv("PYTHONTRACEMALLOC", "0", 1)
        setenv("PYTHONPROFILEIMPORTTIME", "0", 1)
        
        // إعداد متغيرات الشبكة لتسريع الاتصال
        setenv("REQUESTS_CA_BUNDLE", "", 1)
        setenv("SSL_CERT_FILE", "", 1)
        setenv("CURL_CA_BUNDLE", "", 1)
        
        Self.environmentSetup = true
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
                    setupBundledEnvironmentOnce()
                    return writablePath
                } catch {
                    print("❌ Failed to copy \(name) to writable location: \(error)")
                    return nil
                }
            } else {
                // الملف موجود بالفعل، تأكد من صلاحياته
                try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                // تعيين متغيرات البيئة للمكتبات المدمجة
                setupBundledEnvironmentOnce()
                return writablePath
            }
        }
        
        return nil
    }
    
    // MARK: - Optimized Download Settings
    private func getOptimizedDownloadArgs() -> [String] {
        return [
                            "--concurrent-fragments", "64",  // زيادة عدد القطع للسرعة القصوى
            "--buffer-size", "128K",         // زيادة حجم البفر
            "--http-chunk-size", "10485760", // 10MB chunks
            "--downloader-args", "aria2c:-x 16 -s 16 -k 1M -c -m 0 --max-connection-per-server=16 --min-split-size=1M --split=16 --max-concurrent-downloads=8 --continue=true --max-download-limit=0 --max-upload-limit=0 --file-allocation=falloc --no-file-allocation-limit=1M --allow-overwrite=true --check-certificate=false --timeout=30 --connect-timeout=30 --max-tries=3 --retry-wait=2 --always-resume=true --max-resume-failure-tries=3 --save-session-interval=1 --force-save=true --disk-cache=32M --enable-mmap=true --optimize-concurrent-downloads=true",
            "--external-downloader-args", "aria2c:-x 16 -s 16 -k 1M -c -m 0 --max-connection-per-server=16 --min-split-size=1M --split=16 --max-concurrent-downloads=8 --continue=true --max-download-limit=0 --max-upload-limit=0 --file-allocation=falloc --no-file-allocation-limit=1M --allow-overwrite=true --check-certificate=false --timeout=30 --connect-timeout=30 --max-tries=3 --retry-wait=2 --always-resume=true --max-resume-failure-tries=3 --save-session-interval=1 --force-save=true --disk-cache=32M --enable-mmap=true --optimize-concurrent-downloads=true",
            "--retries", "10",               // زيادة عدد المحاولات
            "--fragment-retries", "10",      // زيادة محاولات القطع
            "--file-access-retries", "10",   // زيادة محاولات الوصول للملف
            "--extractor-retries", "10",     // زيادة محاولات الاستخراج
            "--sleep-interval", "0",         // عدم الانتظار بين المحاولات
            "--max-sleep-interval", "0",     // عدم الانتظار الأقصى
            "--no-check-certificate",        // تجاهل شهادات SSL
            "--ignore-errors",               // تجاهل الأخطاء البسيطة
            "--no-mtime",                    // عدم تحديث وقت التعديل
            "--no-playlist",                 // عدم تحميل قوائم التشغيل
            "--continue",                    // دعم الاستئناف
            "--part"                         // إنشاء ملفات جزئية للاستئناف
        ]
    }
    
    func findAxelPath() -> String? {
        // البحث عن axel في bundle التطبيق فقط
        if let bundledPath = Bundle.main.path(forResource: "axel", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        print("✅ Using bundled axel: \(bundledPath)")
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let supportDir = getSupportDirectory() {
                    let writablePath = (supportDir as NSString).appendingPathComponent("axel")
                    
                    // نسخ الملف إذا لم يكن موجوداً
                    if !FileManager.default.fileExists(atPath: writablePath) {
                        do {
                            try FileManager.default.copyItem(atPath: bundledPath, toPath: writablePath)
                            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                            print("✅ Copied axel to writable location: \(writablePath)")
                            return writablePath
                        } catch {
                            print("❌ Failed to copy axel to writable location: \(error)")
                        }
                    } else {
                        // الملف موجود بالفعل، تأكد من صلاحياته
                        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                        return writablePath
                    }
                }
            }
        }
        
        // إذا لم يوجد في bundle، استخدم المسار الافتراضي في Resources
        let defaultPath = Bundle.main.path(forResource: "axel", ofType: nil) ?? ""
        print("❌ axel not found in bundle. Expected path: \(defaultPath)")
        return nil
    }
    
    func findAria2cPath() -> String? {
        // البحث عن aria2c في bundle التطبيق فقط (للترنت)
        if let bundledPath = Bundle.main.path(forResource: "aria2c", ofType: nil) {
            if FileManager.default.fileExists(atPath: bundledPath) {
                // التحقق من أن الملف قابل للتنفيذ
                if let attributes = try? FileManager.default.attributesOfItem(atPath: bundledPath),
                   let permissions = attributes[.posixPermissions] as? NSNumber {
                    let isExecutable = (permissions.intValue & 0o111) != 0
                    if isExecutable {
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        print("✅ Using bundled aria2c: \(bundledPath)")
                        return bundledPath
                    }
                }
                
                // إذا لم يكن قابل للتنفيذ، حاول نسخه إلى موقع قابل للكتابة
                if let supportDir = getSupportDirectory() {
                    let writablePath = (supportDir as NSString).appendingPathComponent("aria2c")
                    
                    // نسخ الملف إذا لم يكن موجوداً
                    if !FileManager.default.fileExists(atPath: writablePath) {
                        do {
                            try FileManager.default.copyItem(atPath: bundledPath, toPath: writablePath)
                            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                            print("✅ Copied aria2c to writable location: \(writablePath)")
                            // تعيين متغيرات البيئة للمكتبات المدمجة
                            setupBundledEnvironment()
                            return writablePath
                        } catch {
                            print("❌ Failed to copy aria2c to writable location: \(error)")
                        }
                    } else {
                        // الملف موجود بالفعل، تأكد من صلاحياته
                        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                        // تعيين متغيرات البيئة للمكتبات المدمجة
                        setupBundledEnvironment()
                        return writablePath
                    }
                }
            }
        }
        
        // إذا لم يوجد في bundle، استخدم المسار الافتراضي في Resources
        let defaultPath = Bundle.main.path(forResource: "aria2c", ofType: nil) ?? ""
        print("❌ aria2c not found in bundle. Expected path: \(defaultPath)")
        return nil
    }
    
    /// تعيين متغيرات البيئة للمكتبات المدمجة
    private func setupBundledEnvironment() {
        // استخدام الدالة المحسنة من YouTubeDownloader.swift
        setupBundledEnvironmentOnce()
    }
    
    /// التحقق من وجود aria2c في bundle التطبيق
    private func checkBundledAria2c() {
        // التحقق من وجود aria2c في bundle
        if let aria2cPath = Bundle.main.path(forResource: "aria2c", ofType: nil) {
            // اختبار aria2c الحالي
            let process = Process()
            process.executableURL = URL(fileURLWithPath: aria2cPath)
            process.arguments = ["--help"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // إذا نجح aria2c، طباعة رسالة تأكيد
                if process.terminationStatus == 0 {
                    print("✅ aria2c bundled version works correctly")
                } else {
                    print("❌ aria2c bundled version failed with exit code: \(process.terminationStatus)")
                }
            } catch {
                print("❌ aria2c bundled version failed: \(error)")
            }
        } else {
            print("❌ aria2c not found in bundle")
        }
    }
    
    /// التحقق من وجود aria2c في bundle التطبيق
    private func verifyBundledAria2c() {
        if let aria2cPath = Bundle.main.path(forResource: "aria2c", ofType: nil) {
            print("✅ aria2c found in bundle at: \(aria2cPath)")
            checkBundledAria2c()
        } else {
            print("❌ aria2c not found in bundle")
        }
    }
    
    func getSupportDirectory() -> String? {
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
            return supportDir
        }
        
        return nil
    }
    
    private func parseVideoProgress(_ output: String, for item: DownloadItem) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("|") {
                let components = line.components(separatedBy: "|")
                if components.count >= 5 {
                    let progressStr = components[0].trimmingCharacters(in: .whitespaces)
                    let speedStr = components[1].trimmingCharacters(in: .whitespaces)
                    let etaStr = components[2].trimmingCharacters(in: .whitespaces)
                    let downloadedStr = components[3].trimmingCharacters(in: .whitespaces)
                    let totalStr = components[4].trimmingCharacters(in: .whitespaces)
                    
                    DispatchQueue.main.async {
                        // تحديث التقدم
                        if let progress = Double(progressStr.replacingOccurrences(of: "%", with: "")) {
                            item.progress = progress / 100.0
                        }
                        
                        // تحديث السرعة
                        item.downloadSpeed = speedStr
                        
                        // تحديث الوقت المتبقي
                        item.remainingTime = etaStr
                        
                        // تحديث الحجم المحمل
                        if let downloaded = Int64(downloadedStr) {
                            item.downloadedSize = downloaded
                        }
                        
                        // تحديث الحجم الكلي
                        if let total = Int64(totalStr) {
                            item.fileSize = total
                        }
                        
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    // MARK: - YouTube Download with Headers
    func addYouTubeDownloadWithHeaders(url: String, title: String, quality: String, headers: [String: String]) {
        print("📥 Adding YouTube download with headers: \(title) [\(quality)]")
        
        // تحسين الجودة المختارة
        let optimizedQuality = translateQualityToYtDlpFormat(quality)
        print("🎬 Quality optimization in addYouTubeDownloadWithHeaders: '\(quality)' -> '\(optimizedQuality)'")
        
        // طباعة تفصيلية للـ headers
        print("📋 Headers in addYouTubeDownloadWithHeaders:")
        for (key, value) in headers {
            if key.lowercased() == "cookie" {
                print("  \(key): \(String(value.prefix(50)))...")
            } else {
                print("  \(key): \(value)")
            }
        }
        
        // إنشاء اسم الملف مع نظام الترقيم التلقائي
        let fileName = generateUniqueYouTubeFileName(title: title, quality: quality)
        
        let newDownload = DownloadItem(
            fileName: fileName,
            url: url,
            fileSize: 0,
            fileType: .video
        )
        newDownload.savePath = "~/Downloads"
        newDownload.chunks = 1
        newDownload.isYouTubeVideo = true
        newDownload.videoQuality = quality
        newDownload.videoFormat = optimizedQuality
        newDownload.actualVideoTitle = title
        newDownload.customHeaders = headers
        
        print("🔍 Debug: Set videoFormat = '\(optimizedQuality)'")
        print("🔍 Debug: Set videoQuality = '\(quality)'")
        
        downloads.insert(newDownload, at: 0)
        saveDownloads()
        startYouTubeDownloadWithHeaders(for: newDownload)
    }
    

    /// بدء تحميل ذكي مع النظام الجديد
    private func startSmartDownload(url: String, fileName: String, downloadInfo: [String: Any]) {
        print("🧠 Starting smart download for: \(url)")
        
        // استخدام SmartDownloadManager
        let downloadId = SmartDownloadManager.shared.startSmartDownload(
            url: url,
            onProgress: { progress in
                print("📊 Smart download progress: \(Int(progress * 100))%")
            },
            onCompletion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fileInfo):
                        print("✅ Smart download completed successfully")
                        print("📝 Final filename: \(fileInfo.fileName)")
                        print("📋 MIME type: \(fileInfo.mimeType)")
                        print("📏 File size: \(fileInfo.fileSize)")
                        
                        // إضافة التحميل إلى القائمة
                        self?.addDownloadEnhanced(
                            url: fileInfo.url,
                            fileName: fileInfo.fileName,
                            fileType: self?.determineFileType(from: fileInfo.url, contentType: fileInfo.mimeType) ?? .other,
                            savePath: "~/Downloads",
                            chunks: 16,
                            cookiesPath: nil
                        )
                        
                    case .failure(let error):
                        print("❌ Smart download failed: \(error)")
                        // العودة للنظام العادي في حالة الفشل
                        self?.pendingURL = url
                        self?.pendingFileName = fileName
                        QuickDownloadWindowController.shared.show(with: self!)
                    }
                }
            }
        )
        
        print("🆔 Smart download ID: \(downloadId)")
    }

private func sanitizeFileName(_ fileName: String) -> String {
    let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let sanitized = fileName.components(separatedBy: invalidCharacters).joined(separator: "_")
    return sanitized.isEmpty ? "download" : sanitized
}

private func getQualityLabel(from quality: String, isAudio: Bool) -> String {
    if isAudio {
        return "audio"
    }
    
    if quality.contains("2160") { return "4K" }
    if quality.contains("1440") { return "2K" }
    if quality.contains("1080") { return "1080p" }
    if quality.contains("720") { return "720p" }
    if quality.contains("480") { return "480p" }
    if quality.contains("360") { return "360p" }
    if quality.contains("240") { return "240p" }
    if quality.contains("144") { return "144p" }
    if quality == "best" || quality.contains("best") { return "best" }
    
    return "video"
}

private func determineFileType(from url: String, contentType: String?) -> DownloadItem.FileType {
    let urlLower = url.lowercased()
    
    // فحص امتداد الملف
    if urlLower.contains(".mp4") || urlLower.contains(".avi") || urlLower.contains(".mkv") || 
       urlLower.contains(".mov") || urlLower.contains(".wmv") || urlLower.contains(".webm") {
        return .video
    }
    
    if urlLower.contains(".mp3") || urlLower.contains(".wav") || urlLower.contains(".flac") || 
       urlLower.contains(".aac") || urlLower.contains(".m4a") || urlLower.contains(".ogg") {
        return .audio
    }
    
    if urlLower.contains(".pdf") || urlLower.contains(".doc") || urlLower.contains(".docx") || 
       urlLower.contains(".xls") || urlLower.contains(".xlsx") || urlLower.contains(".ppt") || 
       urlLower.contains(".pptx") || urlLower.contains(".txt") {
        return .document
    }
    
    if urlLower.contains(".exe") || urlLower.contains(".dmg") || urlLower.contains(".pkg") || 
       urlLower.contains(".deb") || urlLower.contains(".rpm") || urlLower.contains(".msi") || 
       urlLower.contains(".apk") || urlLower.contains(".ipa") {
        return .executable
    }
    
    if urlLower.contains(".zip") || urlLower.contains(".rar") || urlLower.contains(".7z") || 
       urlLower.contains(".tar") || urlLower.contains(".gz") || urlLower.contains(".bz2") {
        return .compressed
    }
    
    // فحص Content-Type
    if let contentType = contentType?.lowercased() {
        if contentType.contains("video") {
            return .video
        }
        if contentType.contains("audio") {
            return .audio
        }
        if contentType.contains("image") {
            return .image
        }
        if contentType.contains("application/pdf") {
            return .document
        }
    }
    
    return .other
}

}
