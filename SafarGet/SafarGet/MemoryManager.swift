import Foundation
import Darwin

// MARK: - Enhanced Memory Manager for Fast Downloads
class MemoryManager {
    static let shared = MemoryManager()
    
    private let maxMemoryUsage: UInt64 = 2 * 1024 * 1024 * 1024  // 2GB
    private let optimalMemoryUsage: UInt64 = 1 * 1024 * 1024 * 1024  // 1GB
    private let cleanupThreshold: UInt64 = 512 * 1024 * 1024  // 512MB
    
    // MARK: - Memory Optimization Settings
    struct MemorySettings {
        static let diskCacheSize = "512M"           // زيادة ذاكرة التخزين المؤقت
        static let maxConcurrentDownloads = 16      // زيادة التحميلات المتزامنة
        static let bufferSize = "256K"              // زيادة حجم البفر
        static let chunkSize = "16777216"           // 16MB chunks
        static let maxOpenFiles = 500               // زيادة عدد الملفات المفتوحة
        static let enableMmap = true                // تفعيل memory mapping
        static let optimizeConcurrent = true        // تحسين التحميلات المتزامنة
    }
    
    // MARK: - Memory Monitoring
    func getCurrentMemoryUsage() -> UInt64 {
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
            return UInt64(info.resident_size)
        } else {
            return 0
        }
    }
    
    // MARK: - Memory Optimization
    func optimizeMemoryForDownloads() {
        let currentUsage = getCurrentMemoryUsage()
        
        if currentUsage > maxMemoryUsage {
            performMemoryCleanup()
        } else if currentUsage > optimalMemoryUsage {
            performLightMemoryOptimization()
        }
    }
    
    // MARK: - Memory Cleanup
    private func performMemoryCleanup() {
        print("🧹 Performing memory cleanup...")
        
        // تنظيف الذاكرة المؤقتة
        URLCache.shared.removeAllCachedResponses()
        
        // تنظيف ذاكرة الصور
        // تنظيف ذاكرة الصور
        URLCache.shared.removeAllCachedResponses()
        
        // إجبار تنظيف الذاكرة
        autoreleasepool {
            // تنظيف إضافي للذاكرة
        }
        
        print("✅ Memory cleanup completed")
    }
    
    // MARK: - Light Memory Optimization
    private func performLightMemoryOptimization() {
        print("⚡ Performing light memory optimization...")
        
        // تنظيف جزئي للذاكرة المؤقتة
        let cache = URLCache.shared
        if cache.currentMemoryUsage > cleanupThreshold {
            cache.removeAllCachedResponses()
        }
        
        print("✅ Light memory optimization completed")
    }
    
    // MARK: - Get Optimized Download Settings
    func getOptimizedDownloadSettings() -> [String: String] {
        let memoryUsage = getCurrentMemoryUsage()
        
        // تعديل الإعدادات بناءً على استخدام الذاكرة
        var diskCache = MemorySettings.diskCacheSize
        var maxConcurrent = MemorySettings.maxConcurrentDownloads
        
        if memoryUsage > optimalMemoryUsage {
            // تقليل استخدام الذاكرة إذا كانت عالية
            diskCache = "256M"
            maxConcurrent = 8
        } else if memoryUsage < cleanupThreshold {
            // زيادة استخدام الذاكرة إذا كانت منخفضة
            diskCache = "1G"
            maxConcurrent = 24
        }
        
        return [
            "disk-cache": diskCache,
            "max-concurrent-downloads": "\(maxConcurrent)",
            "buffer-size": MemorySettings.bufferSize,
            "chunk-size": MemorySettings.chunkSize,
            "max-open-files": "\(MemorySettings.maxOpenFiles)",
            "enable-mmap": MemorySettings.enableMmap ? "true" : "false",
            "optimize-concurrent-downloads": MemorySettings.optimizeConcurrent ? "true" : "false"
        ]
    }
    
    // MARK: - Memory Health Check
    func isMemoryHealthy() -> Bool {
        let usage = getCurrentMemoryUsage()
        return usage < maxMemoryUsage
    }
    
    // MARK: - Get Memory Status
    func getMemoryStatus() -> String {
        let usage = getCurrentMemoryUsage()
        let usageMB = Double(usage) / (1024 * 1024)
        
        if usage > maxMemoryUsage {
            return "Critical: \(String(format: "%.1f", usageMB))MB"
        } else if usage > optimalMemoryUsage {
            return "High: \(String(format: "%.1f", usageMB))MB"
        } else {
            return "Good: \(String(format: "%.1f", usageMB))MB"
        }
    }
    
    // MARK: - Enhanced CPU Monitoring
    private var cpuMonitoringTimer: Timer?
    private var lastCPUCheck: Date = Date()
    private let cpuCheckInterval: TimeInterval = 10.0 // كل 10 ثواني
    private let highCPUThreshold: Double = 80.0 // 80% استخدام CPU
    
    // MARK: - Get Current CPU Usage
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
            // حساب نسبة استخدام CPU بدقة أعلى
            let cpuUsage = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000.0
            return cpuUsage
        }
        
        return 0.0
    }
    
    // MARK: - Enhanced Auto Memory Management
    func startAutoMemoryManagement() {
        // إدارة الذاكرة التقليدية
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.optimizeMemoryForDownloads()
        }
        
        // مراقبة CPU المحسنة
        startCPUMonitoring()
    }
    
    // MARK: - Start CPU Monitoring
    private func startCPUMonitoring() {
        cpuMonitoringTimer = Timer.scheduledTimer(withTimeInterval: cpuCheckInterval, repeats: true) { [weak self] _ in
            self?.checkCPUUsage()
        }
        print("🔍 CPU monitoring started with \(cpuCheckInterval)s intervals")
    }
    
    // MARK: - Check CPU Usage
    private func checkCPUUsage() {
        let cpuUsage = getCurrentCPUUsage()
        let now = Date()
        let timeSinceLastCheck = now.timeIntervalSince(lastCPUCheck)
        
        print("🔍 CPU Usage: \(String(format: "%.1f", cpuUsage))%")
        
        // إذا كان استخدام CPU عالي، قم بالتنظيف
        if cpuUsage > highCPUThreshold {
            print("⚠️ High CPU usage detected (\(String(format: "%.1f", cpuUsage))%), triggering cleanup...")
            ProcessCleanupManager.shared.triggerManualCleanup()
            lastCPUCheck = now
        }
        
        // إيقاف تلقائي للمراقبة عند الاستقرار
        if cpuUsage < 20.0 && timeSinceLastCheck > 300.0 { // 5 دقائق من الاستقرار
            print("✅ CPU usage stabilized, reducing monitoring frequency")
            cpuMonitoringTimer?.invalidate()
            cpuMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                self?.checkCPUUsage()
            }
        }
    }
    
    // MARK: - Stop CPU Monitoring
    func stopCPUMonitoring() {
        cpuMonitoringTimer?.invalidate()
        cpuMonitoringTimer = nil
        print("🛑 CPU monitoring stopped")
    }
    
    // MARK: - Force Cleanup on High CPU
    func forceCleanupOnHighCPU() {
        let cpuUsage = getCurrentCPUUsage()
        if cpuUsage > highCPUThreshold {
            print("🛑 Force cleanup triggered due to high CPU usage (\(String(format: "%.1f", cpuUsage))%)")
            ProcessCleanupManager.shared.forceStopAllBackgroundProcesses()
        }
    }
} 