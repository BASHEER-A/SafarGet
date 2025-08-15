import Foundation
import Combine

// MARK: - Torrent Resume Manager
class TorrentResumeManager: ObservableObject {
    static let shared = TorrentResumeManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var resumeQueue: [UUID] = []
    private var isProcessingResume = false
    
    // MARK: - Resume Configuration
    struct ResumeConfig {
        static let maxRetryAttempts = 10              // زيادة عدد المحاولات
        static let retryDelay: TimeInterval = 1.0     // تقليل وقت الانتظار
        static let connectionCheckDelay: TimeInterval = 1.0  // تقليل وقت فحص الاتصال
        static let maxResumeQueueSize = 20            // زيادة حجم قائمة الاستئناف
        static let resumeTimeout: TimeInterval = 30.0 // timeout للاستئناف
        static let healthCheckInterval: TimeInterval = 5.0   // فحص صحة التورنت كل 5 ثوانٍ
    }
    
    init() {
        setupNetworkObservers()
    }
    
    // MARK: - Network Observers
    private func setupNetworkObservers() {
        // مراقبة عودة الإنترنت
        NotificationCenter.default.publisher(for: .internetReconnected)
            .sink { [weak self] _ in
                self?.handleInternetReconnected()
            }
            .store(in: &cancellables)
        
        // مراقبة انقطاع الإنترنت
        NotificationCenter.default.publisher(for: .internetDisconnected)
            .sink { [weak self] _ in
                self?.handleInternetDisconnected()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Internet Disconnection Handler
    private func handleInternetDisconnected() {
        print("🔴 TorrentResumeManager: Internet disconnected")
        
        // حفظ حالة التورنتات النشطة
        if let viewModel = getViewModel() {
            for download in viewModel.downloads where download.isTorrent && download.status == .downloading {
                // حفظ معلومات التحميل
                download.lastProgressBeforeDisconnect = download.progress
                download.lastSpeedBeforeDisconnect = download.instantSpeed
                download.disconnectTime = Date()
                
                // إضافة إلى قائمة الاستئناف
                addToResumeQueue(download.id)
                
                print("💾 Saved torrent state: \(download.fileName) - Progress: \(Int(download.progress * 100))%")
            }
        }
    }
    
    // MARK: - Internet Reconnection Handler
    private func handleInternetReconnected() {
        print("🟢 TorrentResumeManager: Internet reconnected")
        
        // انتظار قليلاً للتأكد من استقرار الاتصال
        DispatchQueue.main.asyncAfter(deadline: .now() + ResumeConfig.connectionCheckDelay) { [weak self] in
            self?.processResumeQueue()
        }
    }
    
    // MARK: - Resume Queue Management
    private func addToResumeQueue(_ downloadId: UUID) {
        guard resumeQueue.count < ResumeConfig.maxResumeQueueSize else {
            print("⚠️ Resume queue is full, removing oldest entry")
            resumeQueue.removeFirst()
            return
        }
        
        if !resumeQueue.contains(downloadId) {
            resumeQueue.append(downloadId)
            print("📋 Added to resume queue: \(downloadId)")
        }
    }
    
    private func processResumeQueue() {
        guard !isProcessingResume else {
            print("⏳ Already processing resume queue")
            return
        }
        
        isProcessingResume = true
        print("🔄 Processing resume queue with \(resumeQueue.count) items")
        
        guard let viewModel = getViewModel() else {
            isProcessingResume = false
            return
        }
        
        for downloadId in resumeQueue {
            if let download = viewModel.downloads.first(where: { $0.id == downloadId }) {
                resumeTorrentDownload(download, viewModel: viewModel)
            }
        }
        
        // تفريغ القائمة بعد المعالجة
        resumeQueue.removeAll()
        isProcessingResume = false
    }
    
    // MARK: - Torrent Resume Logic
    private func resumeTorrentDownload(_ download: DownloadItem, viewModel: DownloadManagerViewModel) {
        guard download.isTorrent && download.status == .downloading else {
            print("⚠️ Cannot resume: \(download.fileName) - Not a torrent or not downloading")
            return
        }
        
        print("🔄 Attempting to resume torrent: \(download.fileName)")
        
        // التحقق من وجود aria2c
        guard FileManager.default.fileExists(atPath: viewModel.settings.aria2Path) else {
            print("❌ aria2c not found at: \(viewModel.settings.aria2Path)")
            return
        }
        
        // التحقق من وجود ملف التورنت
        let expandedPath = viewModel.expandTildePath(download.savePath)
        let torrentFilePath = "\(expandedPath)/\(download.fileName).torrent"
        
        guard FileManager.default.fileExists(atPath: torrentFilePath) else {
            print("❌ Torrent file not found: \(torrentFilePath)")
            return
        }
        
        // إعادة تشغيل التحميل
        DispatchQueue.main.async {
            // تحديث الحالة
            download.downloadSpeed = "Torrent reconnecting..."
            download.instantSpeed = 0
            download.isResuming = true
            
            // وضع علامة الاستئناف لتتبع السرعة
            RealTimeSpeedTracker.shared.markAsResuming(for: download.id)
            
            viewModel.objectWillChange.send()
        }
        
        // إعادة تشغيل عملية aria2c
        DispatchQueue.global(qos: .background).async {
            self.restartTorrentProcess(download, viewModel: viewModel)
        }
    }
    
    // MARK: - Restart Torrent Process
    private func restartTorrentProcess(_ download: DownloadItem, viewModel: DownloadManagerViewModel) {
        let expandedPath = viewModel.expandTildePath(download.savePath)
        let process = Process()
        
        // إعداد aria2c
        process.executableURL = URL(fileURLWithPath: viewModel.settings.aria2Path)
        
        let downloadPath = download.fileName.contains("_") ? "\(expandedPath)/\(download.fileName)" : expandedPath
        
        // تحديد مسار ملف التورنت
        let torrentFilePath = "\(expandedPath)/\(download.fileName).torrent"
        
        // استخدام الإعدادات المتوافقة من TorrentPerformanceOptimizer
        var arguments = TorrentPerformanceOptimizer.getCompatibleTorrentArguments(downloadPath: downloadPath, expandedPath: expandedPath)
        
        // إضافة ملف التورنت
        arguments.append(torrentFilePath)
        
        process.arguments = arguments
        
        // إعداد pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // معالجة المخرجات
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard self != nil else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    viewModel.parseAria2Output(output, for: download.id)
                    
                    // تحديث إحصائيات التورنت
                    let now = Date()
                    if download.isTorrent && (download.lastPeersUpdate == nil || now.timeIntervalSince(download.lastPeersUpdate!) >= 5.0) {
                        viewModel.parseTorrentStats(output, for: download)
                    }
                }
            }
        }
        
        // معالجة الأخطاء
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            
            if let errorOutput = String(data: data, encoding: .utf8) {
                print("⚠️ Torrent resume error: \(errorOutput)")
            }
        }
        
        do {
            try process.run()
            
            DispatchQueue.main.async {
                download.processTask = process
                download.status = .downloading
                download.isResuming = false
                viewModel.objectWillChange.send()
            }
            
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    download.status = .completed
                    download.progress = 1.0
                    download.downloadSpeed = "Completed"
                    download.remainingTime = "00:00"
                    download.uploadSpeed = "0 KB/s"
                    print("✅ Torrent resume completed: \(download.fileName)")
                    
                    viewModel.notificationManager.sendDownloadCompleteNotification(for: download)
                } else {
                    if download.status != .paused {
                        download.status = .failed
                        print("❌ Torrent resume failed with status: \(process.terminationStatus)")
                        
                        viewModel.notificationManager.sendDownloadFailedNotification(for: download)
                    }
                }
                viewModel.saveDownloads()
            }
        } catch {
            print("💥 Failed to restart torrent process: \(error)")
            DispatchQueue.main.async {
                download.status = .failed
                download.isResuming = false
                viewModel.saveDownloads()
                viewModel.notificationManager.sendDownloadFailedNotification(for: download, reason: "Failed to restart: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getViewModel() -> DownloadManagerViewModel? {
        // هذا سيحتاج إلى تحديث حسب كيفية الوصول إلى ViewModel
        // يمكن تمريره كمعامل أو استخدام NotificationCenter
        return nil
    }
    
    // MARK: - Public Methods
    func addTorrentToResumeQueue(_ downloadId: UUID) {
        addToResumeQueue(downloadId)
    }
    
    func clearResumeQueue() {
        resumeQueue.removeAll()
        print("🧹 Cleared resume queue")
    }
    
    func getResumeQueueStatus() -> [String: Any] {
        return [
            "queueSize": resumeQueue.count,
            "isProcessing": isProcessingResume,
            "maxQueueSize": ResumeConfig.maxResumeQueueSize
        ]
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let torrentResumeStarted = Notification.Name("torrentResumeStarted")
    static let torrentResumeCompleted = Notification.Name("torrentResumeCompleted")
    static let torrentResumeFailed = Notification.Name("torrentResumeFailed")
} 
