import Foundation

// MARK: - Axel Output Parser
struct AxelOutputParser {
    
    struct ParsedData {
        let totalBytes: Int64
        let downloadedBytes: Int64
        let progress: Double
        let speedBytesPerSec: Double
        let eta: String
        let connections: Int
        let isComplete: Bool
    }
    
    /// Parses axel output line and extracts download information
    static func parseOutput(_ line: String) -> ParsedData {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Default values
        var totalBytes: Int64 = 0
        var downloadedBytes: Int64 = 0
        var progress: Double = 0
        var speedBytesPerSec: Double = 0
        let eta: String = "--:--"
        var connections: Int = 1
        var isComplete: Bool = false
        

        
        // Parse file size information
        if trimmedLine.contains("File size:") {
            // البحث عن الحجم بالبايت في نهاية السطر
            let sizePattern = #"\((\d+)\s*bytes?\)"#
            if let regex = try? NSRegularExpression(pattern: sizePattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let range = Range(match.range(at: 1), in: trimmedLine) {
                totalBytes = Int64(trimmedLine[range]) ?? 0
            }
        }
        
        // Parse progress bar
        if trimmedLine.contains("[") && trimmedLine.contains("]") && trimmedLine.contains("%") {
            // Extract percentage from progress bar
            let percentagePattern = #"\[(\d+)%\]"#
            if let regex = try? NSRegularExpression(pattern: percentagePattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let range = Range(match.range(at: 1), in: trimmedLine) {
                let percentage = Int(trimmedLine[range]) ?? 0
                progress = Double(percentage) / 100.0
                downloadedBytes = Int64(Double(totalBytes) * progress)

            }
            
            // Extract speed from progress bar - تحسين النمط ليشمل المسافات
            let speedPattern = #"\[\s*([\d.]+[KMG]?B/s)\s*\]"#
            if let regex = try? NSRegularExpression(pattern: speedPattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let range = Range(match.range(at: 1), in: trimmedLine) {
                let speedString = String(trimmedLine[range])
                speedBytesPerSec = parseSpeedString(speedString)

            }
        }
        
        // Parse completion message - ✅ إصلاح: تحسين اكتشاف الاكتمال
        if trimmedLine.contains("Downloaded") && trimmedLine.contains("byte(s)") && trimmedLine.contains("in") && trimmedLine.contains("second(s)") {
            isComplete = true
            progress = 1.0
            downloadedBytes = totalBytes
            
            // Extract final speed from completion message
            let finalSpeedPattern = #"\(([\d.]+ [KMG]?B/s)\)"#
            if let speedRegex = try? NSRegularExpression(pattern: finalSpeedPattern),
               let speedMatch = speedRegex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let speedRange = Range(speedMatch.range(at: 1), in: trimmedLine) {
                let speedString = String(trimmedLine[speedRange])
                speedBytesPerSec = parseSpeedString(speedString)
            }
        }
        
        // ✅ إصلاح: لا نعتبر 100% اكتمالاً إلا إذا كان هناك رسالة اكتمال فعلي
        // 100% في شريط التقدم لا يعني اكتمال التحميل
        
        // Parse connection information
        if trimmedLine.contains("connection") {
            let connectionPattern = #"(\d+)\s*connection"#
            if let regex = try? NSRegularExpression(pattern: connectionPattern),
               let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
               let range = Range(match.range(at: 1), in: trimmedLine) {
                connections = Int(trimmedLine[range]) ?? 1
            }
        }
        
        return ParsedData(
            totalBytes: totalBytes,
            downloadedBytes: downloadedBytes,
            progress: progress,
            speedBytesPerSec: speedBytesPerSec,
            eta: eta,
            connections: connections,
            isComplete: isComplete
        )
    }
    
    /// Parses speed string to bytes per second
    private static func parseSpeedString(_ speedString: String) -> Double {
        let pattern = #"([\d.]+)\s*([KMG]?B)/s"#
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
    
    /// Converts speed value + unit to bytes per second
    private static func calculateBytesPerSecond(_ value: Double, unit: String) -> Double {
        switch unit.lowercased() {
        case "b/s", "bps":
            return value
        case "kb/s", "kbps":
            return value * 1024  // ✅ إصلاح: استخدام 1024 بدلاً من 1000
        case "mb/s", "mbps":
            return value * 1024 * 1024  // ✅ إصلاح: استخدام 1024^2
        case "gb/s", "gbps":
            return value * 1024 * 1024 * 1024  // ✅ إصلاح: استخدام 1024^3
        default:
            return value
        }
    }
    
    /// Checks if the output line contains progress information
    static func isProgressLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.contains("[") && trimmedLine.contains("%") && trimmedLine.contains("]")
    }
    
    /// Checks if the output line indicates completion
    static func isCompletionLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.contains("Downloaded") && trimmedLine.contains("byte(s)")
    }
    
    /// Checks if the output line contains an error
    static func isErrorLine(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorKeywords = ["error", "failed", "timeout", "connection refused", "not found", "forbidden"]
        return errorKeywords.contains { trimmedLine.lowercased().contains($0) }
    }
}
