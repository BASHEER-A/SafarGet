import Foundation
import Darwin

// MARK: - Process Cleanup Manager
class ProcessCleanupManager {
    static let shared = ProcessCleanupManager()
    
    private var cleanupTimer: DispatchSourceTimer?
    private let cleanupInterval: TimeInterval = 30.0 // كل 30 ثانية
    private var lastCleanupTime: Date = Date()
    private let cleanupQueue = DispatchQueue(label: "com.safarget.processcleanup", qos: .utility)
    private var isCleaning: Bool = false
    private var activeYouTubeOperations: Int = 0
    
    private init() {
        setupAutoCleanup()
    }
    
    // MARK: - Setup Auto Cleanup
    private func setupAutoCleanup() {
        let timer = DispatchSource.makeTimerSource(queue: cleanupQueue)
        timer.schedule(deadline: .now() + cleanupInterval, repeating: cleanupInterval)
        timer.setEventHandler { [weak self] in
            self?.performPeriodicCleanup()
        }
        timer.resume()
        cleanupTimer = timer
        print("🔧 Process cleanup manager initialized with auto-cleanup every \(cleanupInterval) seconds (background queue)")
    }
    
    // MARK: - Periodic Cleanup
    private func performPeriodicCleanup() {
        let now = Date()
        let timeSinceLastCleanup = now.timeIntervalSince(lastCleanupTime)
        
        guard timeSinceLastCleanup >= cleanupInterval else { return }
        
        // منع التداخل إذا كانت عملية تنظيف قيد التنفيذ
        guard !isCleaning else { return }
        
        // لا تنظف عمليات yt-dlp/aria2c/ffmpeg أثناء وجود تنزيلات YouTube نشطة
        if activeYouTubeOperations > 0 {
            print("⏭️ Skipping process cleanup (YouTube operations active: \(activeYouTubeOperations))")
            lastCleanupTime = Date()
            return
        }
        isCleaning = true
        print("🧹 Performing periodic process cleanup (background)...")
        
        // يتم التنفيذ بالكامل على طابور الخلفية
        performYouTubeDownloadCleanup()
        lastCleanupTime = Date()
        isCleaning = false
    }
    
    // MARK: - YouTube Download Cleanup (Enhanced)
    func performYouTubeDownloadCleanup() {
        // لا تنظف أثناء التنزيلات النشطة
        if activeYouTubeOperations > 0 {
            print("⏭️ Skipping YouTube cleanup (active operations: \(activeYouTubeOperations))")
            return
        }
        print("🧹 Starting enhanced YouTube download cleanup...")
        
        // المرحلة 1: تنظيف عمليات yt-dlp
        cleanupYtDlpProcesses()
        
        // المرحلة 2: تنظيف عمليات aria2c
        cleanupAria2cProcesses()
        
        // المرحلة 3: تنظيف عمليات ffmpeg
        cleanupFfmpegProcesses()
        
        // المرحلة 4: تنظيف عمليات Python
        cleanupPythonProcesses()
        
        // المرحلة 5: تنظيف الملفات المؤقتة
        cleanupTempFiles()
        
        print("✅ Enhanced YouTube download cleanup completed")
    }
    
    // MARK: - Cleanup yt-dlp Processes
    private func cleanupYtDlpProcesses() {
        print("🧹 Cleaning yt-dlp processes...")
        
        // استخدام pkill مع SIGKILL للعمليات العنيدة
        let ytDlpCleanupCommands = [
            "pkill -f yt-dlp",
            "pkill -f 'python.*yt-dlp'",
            "killall yt-dlp 2>/dev/null || true",
            "killall python3 2>/dev/null || true"
        ]
        
        for command in ytDlpCleanupCommands {
            executeCleanupCommand(command)
        }
        
        // تنظيف إضافي للعمليات المتبقية
        cleanupRemainingProcesses(withNames: ["yt-dlp", "python3"])
    }
    
    // MARK: - Cleanup aria2c Processes
    private func cleanupAria2cProcesses() {
        print("🧹 Cleaning aria2c processes...")
        
        let aria2cCleanupCommands = [
            "pkill -f aria2c",
            "killall aria2c 2>/dev/null || true"
        ]
        
        for command in aria2cCleanupCommands {
            executeCleanupCommand(command)
        }
        
        // تنظيف إضافي للعمليات المتبقية
        cleanupRemainingProcesses(withNames: ["aria2c"])
    }
    
    // MARK: - Cleanup ffmpeg Processes
    private func cleanupFfmpegProcesses() {
        print("🧹 Cleaning ffmpeg processes...")
        
        let ffmpegCleanupCommands = [
            "pkill -f ffmpeg",
            "killall ffmpeg 2>/dev/null || true"
        ]
        
        for command in ffmpegCleanupCommands {
            executeCleanupCommand(command)
        }
        
        // تنظيف إضافي للعمليات المتبقية
        cleanupRemainingProcesses(withNames: ["ffmpeg"])
    }
    
    // MARK: - Cleanup Python Processes
    private func cleanupPythonProcesses() {
        print("🧹 Cleaning Python processes...")
        
        let pythonCleanupCommands = [
            "pkill -f 'python.*download'",
            "pkill -f 'python.*youtube'",
            "killall python3 2>/dev/null || true"
        ]
        
        for command in pythonCleanupCommands {
            executeCleanupCommand(command)
        }
        
        // تنظيف إضافي للعمليات المتبقية
        cleanupRemainingProcesses(withNames: ["python3", "python"])
    }
    
    // MARK: - Execute Cleanup Command
    private func executeCleanupCommand(_ command: String) {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ Cleanup command executed: \(command)")
            } else {
                print("⚠️ Cleanup command failed (exit code \(process.terminationStatus)): \(command)")
            }
        } catch {
            print("❌ Failed to execute cleanup command: \(command) - \(error)")
        }
    }
    
    // MARK: - Cleanup Remaining Processes
    private func cleanupRemainingProcesses(withNames processNames: [String]) {
        for processName in processNames {
            // البحث عن العمليات المتبقية
            let findCommand = "ps aux | grep '\(processName)' | grep -v grep | awk '{print $2}'"
            
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", findCommand]
            
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: outputData, encoding: .utf8) {
                        let pids = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        
                        for pid in pids {
                            if let pidInt = Int32(pid.trimmingCharacters(in: .whitespaces)) {
                                print("🧹 Force killing process \(processName) with PID: \(pidInt)")
                                kill(pidInt, SIGKILL)
                            }
                        }
                    }
                }
            } catch {
                print("❌ Failed to find remaining \(processName) processes: \(error)")
            }
        }
    }
    
    // MARK: - Cleanup Temp Files
    private func cleanupTempFiles() {
        print("🧹 Cleaning temporary files...")
        
        let tempDir = NSTemporaryDirectory()
        _ = FileManager.default
        
        // قائمة الملفات المؤقتة للحذف
        let tempFilePatterns = [
            "SafarGet_Downloads",
            "SafarGet_YouTube_Separate",
            "*.aria2",
            "*.part",
            "*.temp",
            "*.tmp",
            "*.downloading"
        ]
        
        for pattern in tempFilePatterns {
            let cleanupCommand = "find \(tempDir) -name '\(pattern)' -delete 2>/dev/null || true"
            executeCleanupCommand(cleanupCommand)
        }
        
        // تنظيف مجلد Downloads من الملفات المؤقتة
        let downloadsPath = NSString(string: "~/Downloads").expandingTildeInPath
        let downloadsCleanupCommand = "find '\(downloadsPath)' -name '*.aria2' -o -name '*.part' -o -name '*.temp' -o -name '*.tmp' -o -name '*.downloading' -delete 2>/dev/null || true"
        executeCleanupCommand(downloadsCleanupCommand)
    }
    
    // MARK: - Force Cleanup All Background Processes
    func forceStopAllBackgroundProcesses() {
        print("🛑 Force stopping all background processes...")
        
        // المرحلة 1: إيقاف جميع العمليات المرتبطة بالتحميل
        let forceStopCommands = [
            "pkill -9 -f yt-dlp",
            "pkill -9 -f aria2c",
            "pkill -9 -f ffmpeg",
            "pkill -9 -f 'python.*download'",
            "pkill -9 -f 'python.*youtube'",
            "killall -9 yt-dlp 2>/dev/null || true",
            "killall -9 aria2c 2>/dev/null || true",
            "killall -9 ffmpeg 2>/dev/null || true",
            "killall -9 python3 2>/dev/null || true"
        ]
        
        for command in forceStopCommands {
            executeCleanupCommand(command)
        }
        
        // المرحلة 2: تنظيف الملفات المؤقتة
        cleanupTempFiles()
        
        // المرحلة 3: إعادة تعيين مؤشرات التنظيف
        lastCleanupTime = Date()
        
        print("✅ Force cleanup completed")
    }
    
    // MARK: - Cleanup on App Termination
    func cleanupOnAppTermination() {
        print("🛑 Cleaning up on app termination...")
        
        // إيقاف timer التنظيف التلقائي
        cleanupTimer?.cancel()
        cleanupTimer = nil
        
        // تنظيف شامل للعمليات
        forceStopAllBackgroundProcesses()
        
        print("✅ App termination cleanup completed")
    }

    // MARK: - Non-blocking public triggers
    func triggerManualCleanup() {
        print("🔧 Manual cleanup triggered (queued)...")
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isCleaning else { return }
            if self.activeYouTubeOperations > 0 { return }
            self.isCleaning = true
            self.performYouTubeDownloadCleanup()
            self.lastCleanupTime = Date()
            self.isCleaning = false
        }
    }

    func forceStopAllBackgroundProcessesAsync() {
        print("🛑 Force stopping all background processes (queued)...")
        cleanupQueue.async { [weak self] in
            guard let self = self else { return }
            if self.activeYouTubeOperations > 0 {
                print("⏭️ Skipping force stop (YouTube operations active)")
                return
            }
            self.forceStopAllBackgroundProcesses()
        }
    }

    // MARK: - Activity Guards
    func beginYouTubeOperation() {
        cleanupQueue.sync {
            activeYouTubeOperations += 1
            print("▶️ YouTube operation started (active: \(activeYouTubeOperations))")
        }
    }
    
    func endYouTubeOperation() {
        cleanupQueue.sync {
            activeYouTubeOperations = max(0, activeYouTubeOperations - 1)
            print("⏹️ YouTube operation ended (active: \(activeYouTubeOperations))")
        }
    }
    
    // MARK: - Get CPU Usage
    func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // حساب نسبة استخدام CPU
            let cpuUsage = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000.0
            return cpuUsage
        }
        
        return 0.0
    }
    
    // MARK: - Check if Cleanup is Needed
    func isCleanupNeeded() -> Bool {
        let cpuUsage = getCurrentCPUUsage()
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCleanupTime)
        
        // تنظيف إذا كان استخدام CPU عالي أو مر وقت طويل منذ آخر تنظيف
        return cpuUsage > 50.0 || timeSinceLastCleanup > 60.0
    }
    
    // (legacy triggerManualCleanup removed in favor of queued variant above)
}
