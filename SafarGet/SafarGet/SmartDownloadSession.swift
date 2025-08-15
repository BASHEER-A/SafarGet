import Foundation

// MARK: - Smart Download Session - نظام التحميل الذكي والمعقد
class SmartDownloadSession: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    // MARK: - Properties
    private var session: URLSession!
    private var redirectTracker: RedirectTracker
    private var responseAnalyzer: ResponseAnalyzer?
    private var currentTask: URLSessionDataTask?
    private var downloadData = Data()
    private var expectedContentLength: Int64 = 0
    private var downloadedBytes: Int64 = 0
    
    // Callbacks
    private var onProgress: ((Double) -> Void)?
    private var onCompletion: ((Result<FileInfo, Error>) -> Void)?
    private var onRedirect: ((URL, URL) -> Void)?
    
    // MARK: - Initialization
    override init() {
        self.redirectTracker = RedirectTracker()
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        print("🚀 SmartDownloadSession: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// بدء تحميل ذكي مع تحليل متقدم
    func startSmartDownload(
        url: URL,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Result<FileInfo, Error>) -> Void,
        onRedirect: @escaping (URL, URL) -> Void
    ) {
        print("🚀 SmartDownloadSession: Starting smart download for: \(url.absoluteString)")
        
        self.onProgress = onProgress
        self.onCompletion = onCompletion
        self.onRedirect = onRedirect
        
        // بدء تتبع الـ redirects
        redirectTracker.reset()
        
        // إنشاء الطلب
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        request.setValue("SafarGet/1.0", forHTTPHeaderField: "User-Agent")
        
        // بدء المهمة
        currentTask = session.dataTask(with: request)
        currentTask?.resume()
    }
    
    /// إيقاف التحميل
    func cancelDownload() {
        print("🛑 SmartDownloadSession: Cancelling download")
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        guard let currentURL = task.currentRequest?.url,
              let newURL = request.url else {
            completionHandler(request)
            return
        }
        
        print("🔄 SmartDownloadSession: Redirect detected from \(currentURL.absoluteString) to \(newURL.absoluteString)")
        
        // تسجيل الـ redirect
        redirectTracker.recordRedirect(from: currentURL, to: newURL, response: response)
        
        // إشعار بالـ redirect
        onRedirect?(currentURL, newURL)
        
        // متابعة الـ redirect
        completionHandler(request)
    }
    
    @MainActor
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        print("🔐 SmartDownloadSession: Authentication challenge received")
        
        // قبول الشهادات الذاتية التوقيع (للاختبار فقط)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: trust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        print("📥 SmartDownloadSession: Received response for: \(response.url?.absoluteString ?? "unknown")")
        
        // إنشاء محلل الـ response
        responseAnalyzer = ResponseAnalyzer(response: response)
        
        // تحليل الـ response
        responseAnalyzer?.performPreflightCheck { [weak self] isDownloadable in
            guard let self = self else { return }
            
            if isDownloadable {
                print("✅ SmartDownloadSession: Response analysis passed - proceeding with download")
                
                // حفظ معلومات الـ response
                self.expectedContentLength = response.expectedContentLength
                self.downloadedBytes = 0
                self.downloadData.removeAll()
                
                completionHandler(.allow)
            } else {
                print("❌ SmartDownloadSession: Response analysis failed - cancelling download")
                completionHandler(.cancel)
                
                // إرجاع خطأ
                DispatchQueue.main.async {
                    self.onCompletion?(.failure(SmartDownloadError.notADownloadableFile))
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // إضافة البيانات المستلمة
        downloadData.append(data)
        downloadedBytes += Int64(data.count)
        
        // حساب التقدم
        if expectedContentLength > 0 {
            let progress = Double(downloadedBytes) / Double(expectedContentLength)
            DispatchQueue.main.async { [weak self] in
                self?.onProgress?(progress)
            }
        }
        
        print("📊 SmartDownloadSession: Received \(data.count) bytes, total: \(downloadedBytes)/\(expectedContentLength)")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if let error = error {
            print("❌ SmartDownloadSession: Download failed with error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(error))
            }
            return
        }
        
        print("✅ SmartDownloadSession: Download completed successfully")
        
        // استخراج معلومات الملف
        guard let responseAnalyzer = responseAnalyzer else {
            DispatchQueue.main.async { [weak self] in
                self?.onCompletion?(.failure(SmartDownloadError.noResponseAnalyzer))
            }
            return
        }
        
        let fileInfo = responseAnalyzer.extractFileInfo()
        
        // تحسين اسم الملف باستخدام معلومات الـ redirects
        let optimizedFileInfo = optimizeFileInfo(fileInfo)
        
        DispatchQueue.main.async { [weak self] in
            self?.onCompletion?(.success(optimizedFileInfo))
        }
    }
    
    // MARK: - Private Methods
    
    /// تحسين معلومات الملف باستخدام بيانات الـ redirects
    private func optimizeFileInfo(_ originalFileInfo: FileInfo) -> FileInfo {
        var optimizedFileInfo = originalFileInfo
        
        // استخدام أفضل اسم ملف من سلسلة الـ redirects
        if let bestFilename = redirectTracker.analyzeRedirectChainForBestFilename() {
            optimizedFileInfo = FileInfo(
                url: originalFileInfo.url,
                fileName: bestFilename,
                mimeType: originalFileInfo.mimeType,
                fileSize: originalFileInfo.fileSize,
                isActualFile: originalFileInfo.isActualFile,
                redirectChain: redirectTracker.getRedirectChain()
            )
            print("📝 SmartDownloadSession: Using optimized filename: \(bestFilename)")
        }
        
        // استخدام أفضل نوع MIME من سلسلة الـ redirects
        if let bestMimeType = redirectTracker.analyzeRedirectChainForBestMimeType() {
            optimizedFileInfo = FileInfo(
                url: optimizedFileInfo.url,
                fileName: optimizedFileInfo.fileName,
                mimeType: bestMimeType,
                fileSize: optimizedFileInfo.fileSize,
                isActualFile: optimizedFileInfo.isActualFile,
                redirectChain: optimizedFileInfo.redirectChain
            )
            print("📝 SmartDownloadSession: Using optimized MIME type: \(bestMimeType)")
        }
        
        // طباعة تقرير الـ redirects
        let report = redirectTracker.generateRedirectReport()
        print("📋 SmartDownloadSession: Redirect Report:\n\(report.summary)")
        
        return optimizedFileInfo
    }
}

// MARK: - Smart Download Error
enum SmartDownloadError: Error, LocalizedError {
    case notADownloadableFile
    case noResponseAnalyzer
    case invalidURL
    case networkError
    case timeoutError
    
    var errorDescription: String? {
        switch self {
        case .notADownloadableFile:
            return "The URL does not point to a downloadable file"
        case .noResponseAnalyzer:
            return "No response analyzer available"
        case .invalidURL:
            return "Invalid URL provided"
        case .networkError:
            return "Network error occurred"
        case .timeoutError:
            return "Download timed out"
        }
    }
}

// MARK: - Smart Download Manager
class SmartDownloadManager {
    
    // MARK: - Properties
    private var downloadSessions: [String: SmartDownloadSession] = [:]
    private let queue = DispatchQueue(label: "com.safarget.smartdownload", qos: .userInitiated)
    
    // MARK: - Singleton
    static let shared = SmartDownloadManager()
    
    private init() {
        print("🚀 SmartDownloadManager: Initialized")
    }
    
    // MARK: - Public Methods
    
    /// بدء تحميل ذكي
    func startSmartDownload(
        url: String,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Result<FileInfo, Error>) -> Void
    ) -> String {
        
        guard let downloadURL = URL(string: url) else {
            onCompletion(.failure(SmartDownloadError.invalidURL))
            return ""
        }
        
        let downloadId = UUID().uuidString
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let session = SmartDownloadSession()
            self.downloadSessions[downloadId] = session
            
            session.startSmartDownload(
                url: downloadURL,
                onProgress: onProgress,
                onCompletion: { [weak self] result in
                    // إزالة الجلسة من القائمة
                    self?.downloadSessions.removeValue(forKey: downloadId)
                    onCompletion(result)
                },
                onRedirect: { fromURL, toURL in
                    print("🔄 SmartDownloadManager: Redirect from \(fromURL.absoluteString) to \(toURL.absoluteString)")
                }
            )
        }
        
        return downloadId
    }
    
    /// إيقاف تحميل معين
    func cancelDownload(downloadId: String) {
        queue.async { [weak self] in
            self?.downloadSessions[downloadId]?.cancelDownload()
            self?.downloadSessions.removeValue(forKey: downloadId)
        }
    }
    
    /// إيقاف جميع التحميلات
    func cancelAllDownloads() {
        queue.async { [weak self] in
            self?.downloadSessions.values.forEach { $0.cancelDownload() }
            self?.downloadSessions.removeAll()
        }
    }
    
    /// الحصول على عدد التحميلات النشطة
    func getActiveDownloadCount() -> Int {
        return downloadSessions.count
    }
}
