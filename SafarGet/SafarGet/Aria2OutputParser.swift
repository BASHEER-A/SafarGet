import Foundation

// MARK: - Aria2 Output Parser
class Aria2OutputParser {

    // MARK: - Parsing Result
    struct ParsedData {
        var downloadedBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var speedBytesPerSec: Double = 0
        var progress: Double = 0
        var eta: String = "--:--"
        var connections: Int = 0
        var seeders: Int = 0
        var peers: Int = 0
        var uploadSpeed: Double = 0
    }

    // MARK: - Parse Output
    static func parseOutput(_ output: String) -> ParsedData {
        var result = ParsedData()
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let progressData = parseProgressLine(trimmed) {
                result = progressData
            } else if let downloadData = parseDownloadStatusLine(trimmed) {
                result.merge(with: downloadData)
            } else if let fileData = parseFileInfoLine(trimmed) {
                result.totalBytes = fileData.size
            } else if let summaryData = parseSummaryLine(trimmed) {
                result.merge(with: summaryData)
            }

            // Parse torrent information from aria2c output
            if trimmed.contains("Seed") || trimmed.contains("Peer") {
                if let torrentData = parseTorrentLine(trimmed) {
                    result.seeders = torrentData.seeders
                    result.peers = torrentData.peers
                    print("🔍 [PARSER] Found torrent data: Seeds=\(torrentData.seeders), Peers=\(torrentData.peers) in line: \(trimmed)")
                }
            }
            
            // Parse connection information from aria2c logs
            // سنترك ViewModel يتعامل مع حساب الاتصالات الفريدة
        }

        return result
    }

    // MARK: - Parse Progress Line
    private static func parseProgressLine(_ line: String) -> ParsedData? {
    var result = ParsedData()
    
    // معالجة التنسيقات المختلفة لـ aria2
    // تنسيق 1: [#a1b2c3 123.4MiB/456.7MiB(27%) CN:16 DL:1.2MiB ETA:5m10s]
    // تنسيق 2: [MEMORY][#a1b2c3 123.4MiB/456.7MiB(27%)]
    // تنسيق 3: #1 SIZE:123.4MiB/456.7MiB(27%) CN:16 SPD:1.2MiBx8
    
    // استخراج معلومات التحميل بأنماط متعددة
    let patterns = [
        // نمط مع الحجم والنسبة
        "(\\d+\\.?\\d*[KMGT]?i?B)/(\\d+\\.?\\d*[KMGT]?i?B)\\s*\\((\\d+)%\\)",
        // نمط SIZE:
        "SIZE:(\\d+\\.?\\d*[KMGT]?i?B)/(\\d+\\.?\\d*[KMGT]?i?B)\\s*\\((\\d+)%\\)",
        // نمط مع pipe
        "\\|\\s*(\\d+\\.?\\d*[KMGT]?i?B)/(\\d+\\.?\\d*[KMGT]?i?B)\\s*\\((\\d+)%\\)"
    ]
    
    var foundSizeInfo = false
    for pattern in patterns {
        if let matches = matchGroups(in: line, pattern: pattern), matches.count >= 3 {
            result.downloadedBytes = parseSize(matches[0])
            result.totalBytes = parseSize(matches[1])
            result.progress = Double(matches[2])! / 100.0
            foundSizeInfo = true
            break
        }
    }
    
    // استخراج السرعة
    let speedPatterns = [
        "DL:(\\d+\\.?\\d*[KMGT]?i?B)",
        "SPD:(\\d+\\.?\\d*[KMGT]?i?B)",
        "\\[DL:(\\d+\\.?\\d*[KMGT]?i?B)\\]",
        "DL=(\\d+\\.?\\d*[KMGT]?i?B)"
    ]
    
    for pattern in speedPatterns {
        if let matches = matchGroups(in: line, pattern: pattern), !matches.isEmpty {
            result.speedBytesPerSec = parseSpeed(matches[0] + "/s")
            break
        }
    }
    
    // استخراج ETA
    let etaPatterns = [
        "ETA:([0-9hms]+)",
        "ETA=([0-9hms]+)",
        "eta:([0-9hms]+)"
    ]
    
    for pattern in etaPatterns {
        if let matches = matchGroups(in: line, pattern: pattern), !matches.isEmpty {
            result.eta = matches[0]
            break
        }
    }
    
    // استخراج عدد الاتصالات
    if let matches = matchGroups(in: line, pattern: "CN:(\\d+)") {
        result.connections = Int(matches[0]) ?? 0
    }
    
    return (foundSizeInfo || result.speedBytesPerSec > 0) ? result : nil
}

    // MARK: - Parse Alternative Formats
    private static func parseAlternativeFormat(_ line: String) -> ParsedData? {
        var result = ParsedData()
        
        // تنسيق: [#1 SIZE:1.2GiB/2.3GiB(52%) CN:16 SPD:1.2MiBx8]
        if line.contains("SIZE:") && line.contains("/") {
            // استخرج الحجم المحمل والكلي
            if let sizeMatch = line.range(of: "SIZE:(\\S+)/(\\S+)", options: .regularExpression) {
                let sizeString = String(line[sizeMatch])
                let parts = sizeString.replacingOccurrences(of: "SIZE:", with: "").components(separatedBy: "/")
                if parts.count == 2 {
                    result.downloadedBytes = parseSize(parts[0])
                    let totalPart = parts[1].components(separatedBy: "(")[0] // إزالة النسبة المئوية
                    result.totalBytes = parseSize(totalPart)
                }
            }
            
            // استخرج النسبة المئوية
            if let percentMatch = line.range(of: "\\((\\d+)%\\)", options: .regularExpression) {
                let percentString = String(line[percentMatch])
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: "%)", with: "")
                if let percent = Double(percentString) {
                    result.progress = percent / 100.0
                }
            }
            
            // استخرج السرعة
            if let speedMatch = line.range(of: "SPD:(\\S+)", options: .regularExpression) {
                let speedString = String(line[speedMatch]).replacingOccurrences(of: "SPD:", with: "")
                // إزالة x8 أو أي مضاعف
                let cleanSpeed = speedString.components(separatedBy: "x")[0]
                result.speedBytesPerSec = parseSpeed(cleanSpeed + "/s")
            }
        }
        
        // تنسيق آخر: DL:1.5MiB ETA:10m5s
        if line.contains("DL:") && !line.contains("[") {
            if let dlMatch = line.range(of: "DL:(\\S+)", options: .regularExpression) {
                let dlString = String(line[dlMatch]).replacingOccurrences(of: "DL:", with: "")
                // DL يعطي السرعة وليس الحجم المحمل
                result.speedBytesPerSec = parseSpeed(dlString + "/s")
            }
            
            if let etaMatch = line.range(of: "ETA:(\\S+)", options: .regularExpression) {
                let etaString = String(line[etaMatch]).replacingOccurrences(of: "ETA:", with: "")
                result.eta = etaString
            }
        }
        
        return result.isValid ? result : nil
    }

    // MARK: - Parse Download Status Line
    private static func parseDownloadStatusLine(_ line: String) -> ParsedData? {
        guard line.contains("[DL:") || line.contains("DL:") else { return nil }
        var result = ParsedData()

        if let matches = matchGroups(in: line, pattern: "\\[DL:(\\d+\\.?\\d*[KMGT]?i?B)\\]") {
            result.speedBytesPerSec = parseSpeed(matches[0] + "/s")
        }

        if let matches = matchGroups(in: line, pattern: "(\\d+\\.?\\d*[KMGT]?i?B)/(\\d+\\.?\\d*[KMGT]?i?B)\\((\\d+)%\\)") {
            result.downloadedBytes = parseSize(matches[0])
            result.totalBytes = parseSize(matches[1])
            result.progress = Double(matches[2])! / 100.0
        }

        if let matches = matchGroups(in: line, pattern: "\\[ETA:([^\\]]+)\\]") {
            result.eta = matches[0]
        }

        return result.isValid ? result : nil
    }

    // MARK: - Parse File Info Line
    private static func parseFileInfoLine(_ line: String) -> (size: Int64, name: String?)? {
        guard line.contains("FILE:") else { return nil }
        var size: Int64 = 0
        var name: String?

        if let matches = matchGroups(in: line, pattern: "SIZE:(\\d+)") {
            size = Int64(matches[0]) ?? 0
        }

        if let matches = matchGroups(in: line, pattern: "FILE:\\s*(.+)") {
            name = matches[0].trimmingCharacters(in: .whitespaces)
        }

        return size > 0 ? (size, name) : nil
    }

    // MARK: - Parse Summary Line
    private static func parseSummaryLine(_ line: String) -> ParsedData? {
        var result = ParsedData()

        if line.contains("DL:") && !line.contains("[") {
            if let matches = matchGroups(in: line, pattern: "DL:(\\d+\\.?\\d*[KMGT]?i?B)") {
                result.speedBytesPerSec = parseSpeed(matches[0] + "/s")
            }
        }

        if let matches = matchGroups(in: line, pattern: "ETA:([0-9hms]+)") {
            result.eta = matches[0]
        }

        if let matches = matchGroups(in: line, pattern: "CN:(\\d+)") {
            result.connections = Int(matches[0]) ?? 0
        }

        return result.speedBytesPerSec > 0 ? result : nil
    }

    // MARK: - Parse Torrent Line
    private static func parseTorrentLine(_ line: String) -> (seeders: Int, peers: Int)? {
        var seeders = 0
        var peers = 0

        if let matches = matchGroups(in: line, pattern: "Seed\\((\\d+)\\)") {
            seeders = Int(matches[0]) ?? 0
        }

        if let matches = matchGroups(in: line, pattern: "Peer\\((\\d+)/(\\d+)\\)") {
            peers = Int(matches[0]) ?? 0
        }

        return (seeders > 0 || peers > 0) ? (seeders, peers) : nil
    }
    
    // MARK: - Parse Connection Line
    private static func parseConnectionLine(_ line: String) -> (seeders: Int, peers: Int)? {
        // لا نريد إرجاع قيم ثابتة من هنا
        // سنترك ViewModel يتعامل مع حساب الاتصالات الفريدة
        return nil
    }

    // MARK: - Helper Functions
    private static func parseSize(_ sizeStr: String) -> Int64 {
        let cleanStr = sizeStr.trimmingCharacters(in: .whitespaces)

        if let matches = matchGroups(in: cleanStr, pattern: "([\\d.]+)\\s*([KMGT]?i?B)?") {
            let number = Double(matches[0]) ?? 0
            let unit = matches.count > 1 ? matches[1].uppercased() : "B"

            let multiplier: Double
            switch unit {
            case "B": multiplier = 1
            case "KB", "KIB": multiplier = 1024
            case "MB", "MIB": multiplier = 1024 * 1024
            case "GB", "GIB": multiplier = 1024 * 1024 * 1024
            case "TB", "TIB": multiplier = 1024 * 1024 * 1024 * 1024
            default: multiplier = 1
            }

            return Int64(number * multiplier)
        }

        return Int64(cleanStr) ?? 0
    }

    private static func parseSpeed(_ speedStr: String) -> Double {
        let cleanStr = speedStr.replacingOccurrences(of: "/s", with: "")
        let bytes = parseSize(cleanStr)
        return Double(bytes)
    }

    private static func matchGroups(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsrange) else { return nil }

        var results: [String] = []
        for i in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: text) {
                results.append(String(text[range]))
            }
        }
        return results
    }
}

// MARK: - Extensions
extension Aria2OutputParser.ParsedData {
    var isValid: Bool {
        return speedBytesPerSec > 0 || downloadedBytes > 0 || totalBytes > 0
    }

    mutating func merge(with other: Aria2OutputParser.ParsedData) {
        if other.downloadedBytes > 0 { downloadedBytes = other.downloadedBytes }
        if other.totalBytes > 0 { totalBytes = other.totalBytes }
        if other.speedBytesPerSec > 0 { speedBytesPerSec = other.speedBytesPerSec }
        if other.progress > 0 { progress = other.progress }
        if other.eta != "--:--" { eta = other.eta }
        if other.connections > 0 { connections = other.connections }
        if other.seeders > 0 { seeders = other.seeders }
        if other.peers > 0 { peers = other.peers }
        if other.uploadSpeed > 0 { uploadSpeed = other.uploadSpeed }
    }
}
