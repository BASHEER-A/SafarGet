import Foundation

// MARK: - Redirect Tracker - نظام تتبع التحويلات الذكي
class RedirectTracker {
    
    // MARK: - Properties
    private var redirectChain: [URL] = []
    private var originalRequest: URLRequest?
    private var finalDestination: URL?
    private var originalFilename: String?
    private var originalMimeType: String?
    private var maxRedirects: Int = 10
    private var currentRedirectCount: Int = 0
    
    // معلومات إضافية من كل redirect
    private var redirectInfo: [RedirectInfo] = []
    
    // MARK: - Initialization
    init() {
        print("🔄 RedirectTracker: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// بدء تتبع redirects لطلب معين
    func startTracking(request: URLRequest) {
        print("🔄 RedirectTracker: Starting tracking for URL: \(request.url?.absoluteString ?? "unknown")")
        
        originalRequest = request
        redirectChain.removeAll()
        redirectInfo.removeAll()
        currentRedirectCount = 0
        
        if let url = request.url {
            redirectChain.append(url)
        }
    }
    
    /// تسجيل redirect جديد
    func recordRedirect(from: URL, to: URL, response: HTTPURLResponse) {
        currentRedirectCount += 1
        
        print("🔄 RedirectTracker: Redirect \(currentRedirectCount) from \(from.absoluteString) to \(to.absoluteString)")
        
        // إضافة إلى السلسلة
        redirectChain.append(to)
        
        // حفظ معلومات الـ redirect
        let info = RedirectInfo(
            from: from,
            to: to,
            statusCode: response.statusCode,
            headers: response.allHeaderFields,
            redirectNumber: currentRedirectCount
        )
        redirectInfo.append(info)
        
        // استخراج معلومات الملف من الـ response
        extractFileInfoFromResponse(response)
        
        // التحقق من عدد الـ redirects
        if currentRedirectCount >= maxRedirects {
            print("⚠️ RedirectTracker: Maximum redirects reached (\(maxRedirects))")
        }
    }
    
    /// الحصول على الـ URL النهائي
    func getFinalURL() -> URL? {
        return redirectChain.last ?? finalDestination
    }
    
    /// الحصول على سلسلة الـ redirects
    func getRedirectChain() -> [URL] {
        return redirectChain
    }
    
    /// الحصول على معلومات الـ redirects
    func getRedirectInfo() -> [RedirectInfo] {
        return redirectInfo
    }
    
    /// الحصول على اسم الملف الأصلي
    func getOriginalFilename() -> String? {
        return originalFilename
    }
    
    /// الحصول على نوع MIME الأصلي
    func getOriginalMimeType() -> String? {
        return originalMimeType
    }
    
    /// التحقق من وجود redirects
    func hasRedirects() -> Bool {
        return redirectChain.count > 1
    }
    
    /// الحصول على عدد الـ redirects
    func getRedirectCount() -> Int {
        return redirectChain.count - 1 // نطرح 1 لأن العنصر الأول هو الـ URL الأصلي
    }
    
    /// تنظيف البيانات
    func reset() {
        redirectChain.removeAll()
        redirectInfo.removeAll()
        originalRequest = nil
        finalDestination = nil
        originalFilename = nil
        originalMimeType = nil
        currentRedirectCount = 0
        
        print("🔄 RedirectTracker: Reset")
    }
    
    // MARK: - Private Methods
    
    /// استخراج معلومات الملف من الـ response
    private func extractFileInfoFromResponse(_ response: HTTPURLResponse) {
        // استخراج اسم الملف من Content-Disposition
        if let contentDisposition = response.allHeaderFields["Content-Disposition"] as? String {
            if let filename = extractFileNameFromContentDisposition(contentDisposition) {
                originalFilename = filename
                print("📋 RedirectTracker: Found filename in redirect: \(filename)")
            }
        }
        
        // استخراج نوع MIME
        if let contentType = response.allHeaderFields["Content-Type"] as? String {
            originalMimeType = contentType
            print("📋 RedirectTracker: Found MIME type in redirect: \(contentType)")
        }
        
        // استخراج حجم الملف
        if let contentLength = response.allHeaderFields["Content-Length"] as? String {
            print("📋 RedirectTracker: Found file size in redirect: \(contentLength) bytes")
        }
    }
    
    /// استخراج اسم الملف من Content-Disposition
    private func extractFileNameFromContentDisposition(_ contentDisposition: String) -> String? {
        // البحث عن filename في Content-Disposition header
        let pattern = "filename[^;=\n]*=((['\"]).*?\\2|[^;\n]*)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(location: 0, length: contentDisposition.count)) {
            
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: contentDisposition) {
                var fileName = String(contentDisposition[swiftRange])
                    .replacingOccurrences(of: "filename=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                
                // فك ترميز URL encoding
                if let decoded = fileName.removingPercentEncoding {
                    fileName = decoded
                }
                
                return fileName
            }
        }
        
        // البحث عن filename* (RFC 5987)
        let starPattern = "filename\\*[^;=\n]*=([^;\n]*)"
        
        if let regex = try? NSRegularExpression(pattern: starPattern, options: []),
           let match = regex.firstMatch(in: contentDisposition, options: [], range: NSRange(location: 0, length: contentDisposition.count)) {
            
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: contentDisposition) {
                var fileName = String(contentDisposition[swiftRange])
                    .replacingOccurrences(of: "filename*=", with: "")
                
                // فك ترميز RFC 5987 format
                if fileName.contains("''") {
                    let parts = fileName.components(separatedBy: "''")
                    if parts.count == 2 {
                        fileName = parts[1]
                        if let decoded = fileName.removingPercentEncoding {
                            fileName = decoded
                        }
                    }
                }
                
                return fileName
            }
        }
        
        return nil
    }
    
    /// تحليل سلسلة الـ redirects للعثور على أفضل اسم للملف
    func analyzeRedirectChainForBestFilename() -> String? {
        // البحث عن اسم الملف في آخر redirect أولاً
        if let lastInfo = redirectInfo.last {
            if let filename = extractFileNameFromContentDisposition(lastInfo.headers["Content-Disposition"] as? String ?? "") {
                return filename
            }
        }
        
        // البحث في جميع الـ redirects
        for info in redirectInfo.reversed() {
            if let filename = extractFileNameFromContentDisposition(info.headers["Content-Disposition"] as? String ?? "") {
                return filename
            }
        }
        
        // البحث في الـ URL النهائي
        if let finalURL = getFinalURL() {
            let fileName = finalURL.lastPathComponent
            if !fileName.isEmpty && fileName != "/" {
                return fileName
            }
        }
        
        return nil
    }
    
    /// تحليل سلسلة الـ redirects للعثور على أفضل نوع MIME
    func analyzeRedirectChainForBestMimeType() -> String? {
        // البحث عن نوع MIME في آخر redirect أولاً
        if let lastInfo = redirectInfo.last {
            if let mimeType = lastInfo.headers["Content-Type"] as? String {
                return mimeType
            }
        }
        
        // البحث في جميع الـ redirects
        for info in redirectInfo.reversed() {
            if let mimeType = info.headers["Content-Type"] as? String {
                return mimeType
            }
        }
        
        return nil
    }
    
    /// إنشاء تقرير مفصل عن سلسلة الـ redirects
    func generateRedirectReport() -> RedirectReport {
        let finalURL = getFinalURL()
        let bestFilename = analyzeRedirectChainForBestFilename()
        let bestMimeType = analyzeRedirectChainForBestMimeType()
        
        return RedirectReport(
            originalURL: redirectChain.first,
            finalURL: finalURL,
            redirectCount: getRedirectCount(),
            redirectChain: redirectChain,
            redirectInfo: redirectInfo,
            bestFilename: bestFilename,
            bestMimeType: bestMimeType,
            hasRedirects: hasRedirects()
        )
    }
}

// MARK: - Redirect Info Model
struct RedirectInfo {
    let from: URL
    let to: URL
    let statusCode: Int
    let headers: [AnyHashable: Any]
    let redirectNumber: Int
    
    var isPermanent: Bool {
        return statusCode == 301 || statusCode == 308
    }
    
    var isTemporary: Bool {
        return statusCode == 302 || statusCode == 303 || statusCode == 307
    }
}

// MARK: - Redirect Report Model
struct RedirectReport {
    let originalURL: URL?
    let finalURL: URL?
    let redirectCount: Int
    let redirectChain: [URL]
    let redirectInfo: [RedirectInfo]
    let bestFilename: String?
    let bestMimeType: String?
    let hasRedirects: Bool
    
    var summary: String {
        var summary = "Redirect Report:\n"
        summary += "Original URL: \(originalURL?.absoluteString ?? "unknown")\n"
        summary += "Final URL: \(finalURL?.absoluteString ?? "unknown")\n"
        summary += "Redirect Count: \(redirectCount)\n"
        summary += "Best Filename: \(bestFilename ?? "unknown")\n"
        summary += "Best MIME Type: \(bestMimeType ?? "unknown")\n"
        
        if hasRedirects {
            summary += "Redirect Chain:\n"
            for (index, url) in redirectChain.enumerated() {
                summary += "  \(index + 1). \(url.absoluteString)\n"
            }
        }
        
        return summary
    }
}

// MARK: - URLSession Extension for Redirect Tracking
extension URLSession {
    
    /// إنشاء مهمة مع تتبع الـ redirects
    func downloadTaskWithRedirectTracking(
        with url: URL,
        redirectTracker: RedirectTracker,
        completion: @escaping (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        // بدء تتبع الـ redirects
        redirectTracker.startTracking(request: request)
        
        let task = downloadTask(with: request) { location, response, error in
            // معالجة النتيجة
            completion(location, response, error)
        }
        
        return task
    }
    
    /// إنشاء مهمة data مع تتبع الـ redirects
    func dataTaskWithRedirectTracking(
        with url: URL,
        redirectTracker: RedirectTracker,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        
        // بدء تتبع الـ redirects
        redirectTracker.startTracking(request: request)
        
        let task = dataTask(with: request) { data, response, error in
            // معالجة النتيجة
            completion(data, response, error)
        }
        
        return task
    }
}
