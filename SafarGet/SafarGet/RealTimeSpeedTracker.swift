import Foundation
import Combine

// MARK: - Enhanced Real-Time Speed Tracker with Improved Resume Handling
class RealTimeSpeedTracker: ObservableObject {
    static let shared = RealTimeSpeedTracker()
    
    private var trackers: [UUID: DownloadTracker] = [:]
    private let queue = DispatchQueue(label: "com.safar.speedtracker", qos: .userInitiated)

    // MARK: - Speed Sample
    private struct SpeedSample {
        let timestamp: Date
        let bytes: Int64
        let instantSpeed: Double
    }

    // MARK: - Download Tracker
    private class DownloadTracker {
        var samples: [SpeedSample] = []
        var lastBytes: Int64 = 0
        var lastTimestamp = Date()
        var isFirstUpdate = true
        var startTime: Date?
        var totalBytesAtStart: Int64 = 0

        // Resume handling
        var resumeState: ResumeState = .notResuming
        var resumeStartTime: Date?
        var bytesAtResume: Int64 = 0
        var lastActiveBytes: Int64 = 0

        enum ResumeState {
            case notResuming
            case waitingForConnection
            case receivingData
            case completed
        }

        var currentSpeed: Double = 0
        var averageSpeed: Double = 0
        var smoothedSpeed: Double = 0
        var realtimeSpeed: Double = 0

        let maxReasonableSpeed: Double = 100 * 1024 * 1024 // 100 MB/s
        let connectionTimeout: TimeInterval = 15.0

        let sampleInterval: TimeInterval = 0.1  // تقليل الفاصل الزمني للاستجابة الأسرع
        let maxSamples = 20
        let smoothingFactor = 0.3

        // ✅ التعديل النهائي المحسن - أسرع بداية
        func update(currentBytes: Int64) -> (speed: Double, displaySpeed: String, remainingTime: String, isRealtime: Bool) {
            let now = Date()

            if isFirstUpdate {
                startTime = now
                lastTimestamp = now
                lastBytes = currentBytes
                totalBytesAtStart = currentBytes
                isFirstUpdate = false
                
                // بدء تتبع السرعة فوراً إذا كان هناك بيانات
                if currentBytes > 0 {
                    return (0, "Connecting...", "--:--", false)
                }
                return (0, "Starting...", "--:--", false)
            }
            
            // ✅ إصلاح: إذا كان هناك سرعة سابقة، احتفظ بها
            if currentSpeed > 0 && currentBytes == lastBytes {
                return (currentSpeed, formatSpeed(currentSpeed), calculateRemainingTime(), false)
            }

            // ✅ تحسين منطق الاستئناف - تقليل أوقات الانتظار
            switch resumeState {
            case .waitingForConnection:
                if resumeStartTime == nil {
                    resumeStartTime = now
                    bytesAtResume = currentBytes
                }
                
                // تقليل وقت الانتظار إلى 0.01 ثانية للاستجابة السريعة
                if let startTime = resumeStartTime, now.timeIntervalSince(startTime) > 0.01 {
                    resumeState = .completed
                    samples.removeAll()
                    lastBytes = currentBytes
                    lastTimestamp = now
                }
                
                // إذا تغير حجم الملف، انتقل إلى حالة استقبال البيانات
                if currentBytes > bytesAtResume || (bytesAtResume == 0 && currentBytes > 0) {
                    resumeState = .receivingData
                    lastBytes = currentBytes
                    lastTimestamp = now
                    return (0, "Resuming...", "--:--", false)
                }
                return (0, "Connecting...", "--:--", false)

            case .receivingData:
                let timeSinceResume = resumeStartTime.map { now.timeIntervalSince($0) } ?? 0
                
                // تقليل وقت التحليل إلى 0.001 ثانية للاستجابة الفورية
                if timeSinceResume > 0.001 {
                    resumeState = .completed
                    samples.removeAll()
                    lastBytes = currentBytes
                    lastTimestamp = now
                }
                
                // حساب السرعة الفورية أثناء الاستئناف
                let timeDiff = now.timeIntervalSince(lastTimestamp)
                if timeDiff >= 0.001 && currentBytes > lastBytes {
                    let bytesDiff = currentBytes - lastBytes
                    let instantSpeed = Double(bytesDiff) / timeDiff
                    
                    if instantSpeed > 0 && instantSpeed < maxReasonableSpeed {
                        lastBytes = currentBytes
                        lastTimestamp = now
                        return (instantSpeed, formatSpeed(instantSpeed), "--:--", true)
                    }
                }
                return (0, "Resuming...", "--:--", false)

            case .completed, .notResuming:
                // ✅ إصلاح: حساب السرعة في الحالة العادية
                let timeDiff = now.timeIntervalSince(lastTimestamp)
                
                // تقليل الفاصل الزمني إلى 0.001 ثانية للاستجابة الفورية
                guard timeDiff >= 0.001 else {
                    // ✅ إصلاح: احتفظ بالسرعة السابقة إذا لم يحن الوقت للتحديث
                    if currentSpeed > 0 {
                        return (currentSpeed, formatSpeed(currentSpeed), calculateRemainingTime(), false)
                    }
                    return (0, "Starting...", "--:--", false)
                }

                let bytesDiff = currentBytes - lastBytes
                
                if bytesDiff > 0 {
                    let instantSpeed = Double(bytesDiff) / timeDiff
                    
                    // التحقق من معقولية السرعة
                    if instantSpeed > 0 && instantSpeed < maxReasonableSpeed {
                        // إضافة العينة
                        let sample = SpeedSample(timestamp: now, bytes: currentBytes, instantSpeed: instantSpeed)
                        samples.append(sample)

                        // الحفاظ على عدد محدود من العينات
                        if samples.count > maxSamples {
                            samples.removeFirst()
                        }

                        // حساب السرعة الحالية والمتوسطة
                        currentSpeed = instantSpeed
                        
                        // حساب المتوسط من العينات الأخيرة
                        let recentSamples = Array(samples.suffix(3))
                        if recentSamples.count >= 2 {
                            let avgSpeed = recentSamples.map { $0.instantSpeed }.reduce(0, +) / Double(recentSamples.count)
                            averageSpeed = avgSpeed
                            smoothedSpeed = smoothedSpeed * (1 - smoothingFactor) + avgSpeed * smoothingFactor
                        } else {
                            averageSpeed = instantSpeed
                            smoothedSpeed = instantSpeed
                        }
                        
                        realtimeSpeed = instantSpeed
                        
                        lastBytes = currentBytes
                        lastTimestamp = now
                        
                        return (smoothedSpeed, formatSpeed(smoothedSpeed), calculateRemainingTime(), true)
                    }
                }
                
                // ✅ إصلاح محسن: احتفظ بالسرعة السابقة إذا لم تكن هناك سرعة جديدة
                if currentSpeed > 0 {
                    // تحديث الوقت فقط إذا لم تتغير البيانات
                    if currentBytes == lastBytes {
                        lastTimestamp = now
                    }
                    return (currentSpeed, formatSpeed(currentSpeed), calculateRemainingTime(), false)
                }
                
                // ✅ إصلاح: إذا كان هناك سرعة سابقة في العينات، استخدمها
                if let lastSample = samples.last, lastSample.instantSpeed > 0 {
                    currentSpeed = lastSample.instantSpeed
                    return (currentSpeed, formatSpeed(currentSpeed), calculateRemainingTime(), false)
                }
                
                return (0, "Starting...", "--:--", false)
            }
        }

        private func updateSpeeds(currentBytes: Int64) {
            if let lastSample = samples.last {
                currentSpeed = lastSample.instantSpeed
            }
            if let start = startTime {
                let totalTime = Date().timeIntervalSince(start)
                let totalBytes = currentBytes - totalBytesAtStart
                averageSpeed = totalTime > 0 ? Double(totalBytes) / totalTime : 0
            }
            if samples.count >= 3 {
                let recentSamples = samples.suffix(5)
                var totalSpeed = 0.0
                var totalWeight = 0.0
                for (index, sample) in recentSamples.enumerated() {
                    let weight = Double(index + 1)
                    totalSpeed += sample.instantSpeed * weight
                    totalWeight += weight
                }
                smoothedSpeed = totalWeight > 0 ? totalSpeed / totalWeight : 0
            } else {
                smoothedSpeed = currentSpeed
            }
            realtimeSpeed = realtimeSpeed * (1 - smoothingFactor) + smoothedSpeed * smoothingFactor
            realtimeSpeed = min(realtimeSpeed, maxReasonableSpeed)
        }

        private func calculateRemainingTime() -> String {
            guard smoothedSpeed > 0 else { return "--:--" }
            return "--:--" // سيتم حساب الوقت المتبقي في getRemainingTime
        }

        private func formatSpeed(_ bytesPerSecond: Double) -> String {
            guard bytesPerSecond > 0 else { return "0 KB/s" }
            let units = ["B/s", "KB/s", "MB/s", "GB/s"]
            var speed = bytesPerSecond
            var unitIndex = 0
            
            while speed >= 1024 && unitIndex < units.count - 1 {
                speed /= 1024
                unitIndex += 1
            }
            
            if unitIndex == 0 {
                return String(format: "%.0f %@", speed, units[unitIndex])
            } else {
                return String(format: "%.2f %@", speed, units[unitIndex])
            }
        }

        private func formatTime(seconds: Int) -> String {
            guard seconds > 0 else { return "00:00" }
            if seconds < 60 {
                return String(format: "00:%02d", seconds)
            } else if seconds < 3600 {
                let minutes = seconds / 60
                let remainingSeconds = seconds % 60
                return String(format: "%02d:%02d", minutes, remainingSeconds)
            } else {
                let hours = seconds / 3600
                let minutes = (seconds % 3600) / 60
                let remainingSeconds = seconds % 60
                return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
            }
        }
        
        func getRemainingTime(totalBytes: Int64, downloadedBytes: Int64) -> String {
            guard smoothedSpeed > 0 else { return "--:--" }
            let remainingBytes = totalBytes - downloadedBytes
            let seconds = Int(Double(remainingBytes) / smoothedSpeed)
            return formatTime(seconds: seconds)
        }
        
        func reset() {
            // ✅ إصلاح: حفظ القيم المهمة قبل إعادة التعيين
            let wasResuming = resumeState == .waitingForConnection || resumeState == .receivingData
            let savedBytes = lastBytes
            let _ = currentSpeed // تجاهل التحذير
            
            samples.removeAll()
            lastBytes = 0
            lastTimestamp = Date()
            isFirstUpdate = true
            startTime = nil
            totalBytesAtStart = 0
            resumeState = .notResuming
            resumeStartTime = nil
            bytesAtResume = 0
            lastActiveBytes = 0
            currentSpeed = 0
            averageSpeed = 0
            smoothedSpeed = 0
            realtimeSpeed = 0
            
            // ✅ إصلاح: إذا كان الاستئناف، احتفظ بالقيم المهمة
            if wasResuming {
                lastBytes = savedBytes
                bytesAtResume = savedBytes
                lastActiveBytes = savedBytes
                print("🔒 [TRACKER] Preserved bytes during reset: \(savedBytes)")
            }
        }
        
        func markAsResuming() {
            resumeState = .waitingForConnection
            resumeStartTime = nil
            bytesAtResume = lastBytes
            lastActiveBytes = lastBytes
        }
    }
    
    // MARK: - Public Methods
    private func getOrCreateTracker(for downloadId: UUID) -> DownloadTracker {
        if let tracker = trackers[downloadId] {
            return tracker
        } else {
            let tracker = DownloadTracker()
            trackers[downloadId] = tracker
            return tracker
        }
    }
    
    public func updateSpeed(for downloadId: UUID, currentBytes: Int64, totalBytes: Int64) -> (speed: Double, displaySpeed: String, remainingTime: String, isRealtime: Bool) {
        let tracker = getOrCreateTracker(for: downloadId)
        let result = tracker.update(currentBytes: currentBytes)
        let remainingTime = tracker.getRemainingTime(totalBytes: totalBytes, downloadedBytes: currentBytes)
        return (result.speed, result.displaySpeed, remainingTime, result.isRealtime)
    }
    
    public func getInstantSpeed(for downloadId: UUID) -> Double {
        return trackers[downloadId]?.currentSpeed ?? 0
    }
    
    public func getAverageSpeed(for downloadId: UUID) -> Double {
        return trackers[downloadId]?.averageSpeed ?? 0
    }
    
    public func reset(for downloadId: UUID) {
        queue.async { [weak self] in
            self?.trackers[downloadId]?.reset()
        }
    }
    
    public func markAsResuming(for downloadId: UUID) {
        queue.async { [weak self] in
            self?.trackers[downloadId]?.markAsResuming()
        }
    }
    
    public func remove(for downloadId: UUID) {
        queue.async { [weak self] in
            self?.trackers.removeValue(forKey: downloadId)
        }
    }
}
