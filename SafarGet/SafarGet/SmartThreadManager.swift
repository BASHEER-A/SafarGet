import Foundation

// MARK: - Smart Thread Manager
class SmartThreadManager {
    static let shared = SmartThreadManager()
    
    private let maxThreads = 64               // زيادة الحد الأقصى للخيوط
    private let defaultThreads = 16           // زيادة الخيوط الافتراضية
    private let threadTimeout: TimeInterval = 15.0  // تقليل timeout للسرعة
    
    struct ServerCapabilities {
        let supportsRangeRequests: Bool
        let maxConnections: Int
        let recommendedThreads: Int
        let serverType: ServerType
        
        enum ServerType {
            case standard
            case cdn
            case limited
            case unknown
        }
    }
    
    // MARK: - Check Server Capabilities
    func checkServerCapabilities(for url: String, completion: @escaping (ServerCapabilities) -> Void) {
        guard let requestURL = URL(string: url) else {
            completion(ServerCapabilities(
                supportsRangeRequests: false,
                maxConnections: 1,
                recommendedThreads: 1,
                serverType: .unknown
            ))
            return
        }
        
        // Create HEAD request to check server capabilities
        var request = URLRequest(url: requestURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10.0
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    let capabilities = self.analyzeServerResponse(httpResponse)
                    completion(capabilities)
                } else {
                    // Default to safe values
                    completion(ServerCapabilities(
                        supportsRangeRequests: false,
                        maxConnections: 1,
                        recommendedThreads: 1,
                        serverType: .unknown
                    ))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Analyze Server Response
    private func analyzeServerResponse(_ response: HTTPURLResponse) -> ServerCapabilities {
        let headers = response.allHeaderFields
        
        // Check for Range support
        let acceptRanges = headers["Accept-Ranges"] as? String
        let supportsRangeRequests = acceptRanges?.lowercased() == "bytes"
        
        // Detect server type
        let serverType = detectServerType(from: headers)
        
        // Determine max connections based on server type
        let maxConnections = determineMaxConnections(serverType: serverType, headers: headers)
        
        // Calculate recommended threads
        let recommendedThreads = calculateRecommendedThreads(
            supportsRange: supportsRangeRequests,
            serverType: serverType,
            maxConnections: maxConnections
        )
        
        return ServerCapabilities(
            supportsRangeRequests: supportsRangeRequests,
            maxConnections: maxConnections,
            recommendedThreads: recommendedThreads,
            serverType: serverType
        )
    }
    
    // MARK: - Server Type Detection
    private func detectServerType(from headers: [AnyHashable: Any]) -> ServerCapabilities.ServerType {
        let serverHeader = headers["Server"] as? String ?? ""
        let _ = headers["X-Powered-By"] as? String ?? ""
        
        // Check for CDN providers
        if headers["CF-Ray"] != nil || serverHeader.contains("cloudflare") {
            return .cdn
        }
        
        if headers["X-Amz-Cf-Id"] != nil || serverHeader.contains("CloudFront") {
            return .cdn
        }
        
        if headers["X-Served-By"] != nil && serverHeader.contains("Fastly") {
            return .cdn
        }
        
        // Check for limited servers
        if serverHeader.contains("nginx") || serverHeader.contains("Apache") {
            // Check for rate limiting headers
            if headers["X-RateLimit-Limit"] != nil ||
               headers["X-Rate-Limit-Limit"] != nil ||
               headers["Retry-After"] != nil {
                return .limited
            }
            return .standard
        }
        
        return .standard
    }
    
    // MARK: - Determine Max Connections
    private func determineMaxConnections(serverType: ServerCapabilities.ServerType, headers: [AnyHashable: Any]) -> Int {
        // Check for explicit connection limits
        if let maxConnHeader = headers["X-Max-Connections"] as? String,
           let maxConn = Int(maxConnHeader) {
            return min(maxConn, maxThreads)
        }
        
        switch serverType {
        case .cdn:
            return 64 // CDNs usually support many connections - زيادة للسرعة
        case .standard:
            return 32 // Standard servers - زيادة للسرعة
        case .limited:
            return 16 // Rate-limited servers - زيادة للسرعة
        case .unknown:
            return 24 // Safe default - زيادة للسرعة
        }
    }
    
    // MARK: - Calculate Recommended Threads
    private func calculateRecommendedThreads(
        supportsRange: Bool,
        serverType: ServerCapabilities.ServerType,
        maxConnections: Int
    ) -> Int {
        guard supportsRange else {
            return 1 // No multi-threading without range support
        }
        
        switch serverType {
        case .cdn:
            return min(32, maxConnections)  // زيادة للـ CDN
        case .standard:
            return min(16, maxConnections)  // زيادة للخوادم العادية
        case .limited:
            return min(8, maxConnections)   // زيادة للخوادم المحدودة
        case .unknown:
            return min(12, maxConnections)  // زيادة للخوادم المجهولة
        }
    }
    
    // MARK: - Validate Thread Count
    func validateThreadCount(_ requestedThreads: Int, capabilities: ServerCapabilities) -> (threads: Int, warning: String?) {
        if !capabilities.supportsRangeRequests {
            return (1, "Server doesn't support multi-threaded downloads. Using single connection.")
        }
        
        if requestedThreads > capabilities.maxConnections {
            return (
                capabilities.recommendedThreads,
                "Server supports maximum \(capabilities.maxConnections) connections. Using \(capabilities.recommendedThreads) threads."
            )
        }
        
        if requestedThreads > maxThreads {
            return (maxThreads, "Maximum thread limit is \(maxThreads).")
        }
        
        return (requestedThreads, nil)
    }
    
    // MARK: - Get Auto Thread Count
    func getAutoThreadCount(for url: String, fileSize: Int64, completion: @escaping (Int) -> Void) {
        checkServerCapabilities(for: url) { capabilities in
            var threads = capabilities.recommendedThreads
            
            // Adjust based on file size - أكثر عدوانية للسرعة
            if fileSize > 0 {
                if fileSize < 10 * 1024 * 1024 { // < 10MB
                    threads = min(threads, 4)  // زيادة من 2 إلى 4
                } else if fileSize < 50 * 1024 * 1024 { // < 50MB
                    threads = min(threads, 8)  // زيادة من 4 إلى 8
                } else if fileSize < 100 * 1024 * 1024 { // < 100MB
                    threads = min(threads, 16) // زيادة من 8 إلى 16
                } else if fileSize < 500 * 1024 * 1024 { // < 500MB
                    threads = min(threads, 24) // إضافة فئة جديدة
                } else { // > 500MB
                    threads = min(threads, 32) // إضافة فئة للملفات الكبيرة
                }
            }
            
            // ضمان حد أدنى من الخيوط للسرعة
            threads = max(threads, 4)
            
            completion(threads)
        }
    }
    
    // MARK: - Monitor Thread Performance
    func createThreadMonitor() -> ThreadMonitor {
        return ThreadMonitor()
    }
    
    class ThreadMonitor {
        private var threadPerformance: [Int: ThreadPerformance] = [:]
        private let performanceQueue = DispatchQueue(label: "com.safarget.threadmonitor")
        
        struct ThreadPerformance {
            var startTime: Date
            var bytesDownloaded: Int64
            var lastUpdate: Date
            var isStalled: Bool
            var averageSpeed: Double
        }
        
        func startMonitoring(threadId: Int) {
            performanceQueue.async {
                self.threadPerformance[threadId] = ThreadPerformance(
                    startTime: Date(),
                    bytesDownloaded: 0,
                    lastUpdate: Date(),
                    isStalled: false,
                    averageSpeed: 0
                )
            }
        }
        
        func updateProgress(threadId: Int, bytesDownloaded: Int64) {
            performanceQueue.async {
                guard var performance = self.threadPerformance[threadId] else { return }
                
                let now = Date()
                let timeDiff = now.timeIntervalSince(performance.lastUpdate)
                
                if timeDiff > 0 {
                    let speed = Double(bytesDownloaded - performance.bytesDownloaded) / timeDiff
                    performance.averageSpeed = (performance.averageSpeed + speed) / 2
                }
                
                performance.bytesDownloaded = bytesDownloaded
                performance.lastUpdate = now
                performance.isStalled = timeDiff > 10.0 && performance.bytesDownloaded == bytesDownloaded
                
                self.threadPerformance[threadId] = performance
            }
        }
        
        func getStalledThreads() -> [Int] {
            performanceQueue.sync {
                return threadPerformance.compactMap { (id, performance) in
                    performance.isStalled ? id : nil
                }
            }
        }
        
        func getAverageSpeed() -> Double {
            performanceQueue.sync {
                let speeds = threadPerformance.values.map { $0.averageSpeed }
                return speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
            }
        }
        
        func stopMonitoring(threadId: Int) {
            performanceQueue.async {
                self.threadPerformance.removeValue(forKey: threadId)
            }
        }
    }
} 
