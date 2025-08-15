import Foundation
import WebKit
import UniformTypeIdentifiers

// MARK: - Universal Download Detector - النظام الشامل لاكتشاف التحميلات
class UniversalDownloadDetector: NSObject {
    
    // MARK: - Properties
    private weak var viewModel: DownloadManagerViewModel?
    private var webView: WKWebView?
    private var redirectTracker: RedirectTracker?
    private var responseAnalyzer: ResponseAnalyzer?
    private var crashLog: [DownloadCrashLog] = []
    private var isVerboseMode: Bool = false
    
    // قائمة MIME Types القابلة للتحميل
    private let downloadableMimeTypes: [String] = [
        // Archives
        "application/zip", "application/x-zip", "application/x-zip-compressed",
        "application/x-rar-compressed", "application/x-7z-compressed",
        "application/x-tar", "application/x-gzip", "application/x-bzip2",
        "application/x-xz", "application/x-lzma",
        
        // Documents
        "application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "text/plain", "text/csv", "application/rtf",
        
        // Executables
        "application/vnd.android.package-archive", "application/x-apple-diskimage",
        "application/x-debian-package", "application/x-redhat-package-manager",
        "application/x-msdownload", "application/x-executable", "application/x-shockwave-flash",
        "application/x-flash-video", "application/x-msi", "application/x-java-archive",
        
        // Media
        "video/", "audio/", "image/",
        
        // Other
        "application/octet-stream", "application/x-binary", "application/x-download"
    ]
    
    // امتدادات الملفات المعروفة
    private let fileExtensions: [String] = [
        // Archives
        "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "lzma",
        
        // Documents
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf",
        
        // Executables
        "exe", "msi", "dmg", "pkg", "deb", "rpm", "jar", "war", "apk", "ipa",
        
        // Media
        "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "m4v", "3gp",
        "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma",
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "webp",
        
        // Other
        "iso", "img", "bin", "torrent", "ipsw"
    ]
    
    // كلمات مفتاحية في URL
    private let downloadKeywords: [String] = [
        "/download", "/dl/", "/get/", "/fetch/", "/export", "/save", "/attachment",
        "download=", "file=", "export=", "get=", "/files/", "/uploads/", "/media/"
    ]
    
    // MARK: - Initialization
    init(viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        super.init()
        setupUniversalDetector()
    }
    
    // MARK: - Setup
    private func setupUniversalDetector() {
        redirectTracker = RedirectTracker()
        print("🚀 UniversalDownloadDetector: Initialized with comprehensive detection")
    }
    
    // MARK: - Public Methods
    
    /// بدء الاكتشاف الشامل للتحميلات
    func startUniversalDetection() -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // حقن JavaScript الشامل
        let script = WKUserScript(
            source: universalInterceptorJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)
        
        // إضافة معالجات JavaScript
        config.userContentController.add(self, name: "universalDownloadDetected")
        config.userContentController.add(self, name: "blobDownloadDetected")
        config.userContentController.add(self, name: "xhrDownloadDetected")
        config.userContentController.add(self, name: "fetchDownloadDetected")
        config.userContentController.add(self, name: "serviceWorkerDetected")
        config.userContentController.add(self, name: "metaRefreshDetected")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        webView?.uiDelegate = self
        
        return webView!
    }
    
    /// تفعيل وضع التصحيح
    func enableVerboseMode() {
        isVerboseMode = true
        print("🔍 UniversalDownloadDetector: Verbose mode enabled")
    }
    
    /// الحصول على سجل التصادمات
    func getCrashLog() -> [DownloadCrashLog] {
        return crashLog
    }
    
    // MARK: - Private Methods
    
    private func shouldInterceptAsDownload(request: URLRequest) -> Bool {
        let url = request.url?.absoluteString ?? ""
        
        // فحص URL للامتدادات
        for ext in fileExtensions {
            if url.lowercased().contains(".\(ext)") {
                return true
            }
        }
        
        // فحص URL للكلمات المفتاحية
        for keyword in downloadKeywords {
            if url.lowercased().contains(keyword) {
                return true
            }
        }
        
        // فحص Content-Type
        if let contentType = request.allHTTPHeaderFields?["Content-Type"] as? String {
            for type in downloadableMimeTypes {
                if contentType.contains(type) {
                    return true
                }
            }
        }
        
        // فحص Content-Disposition
        if let contentDisposition = request.allHTTPHeaderFields?["Content-Disposition"] as? String {
            if contentDisposition.contains("attachment") {
                return true
            }
        }
        
        return false
    }
    
    private func startUniversalDownload(from request: URLRequest) {
        guard let url = request.url else { return }
        
        let downloadTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleDownloadError(error: error, url: url)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.handleDownloadError(error: NSError(domain: "UniversalDownloadDetector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]), url: url)
                return
            }
            
            self.extractFinalURLAndDownload(from: httpResponse, originalRequest: url)
        }
        
        downloadTask.resume()
    }
    
    private func extractFinalURLAndDownload(from response: HTTPURLResponse, originalRequest: URL) {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1
        config.timeoutIntervalForRequest = 30
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: originalRequest)
        request.httpMethod = "HEAD"
        request.setValue("SafarGet/1.0", forHTTPHeaderField: "User-Agent")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let finalResponse = response as? HTTPURLResponse,
                   let finalURL = finalResponse.url {
                    
                    if self?.isVerboseMode == true {
                        print("✅ UniversalDownloadDetector: Final URL extracted: \(finalURL)")
                    }
                    
                    let filename = self?.extractFilename(from: finalResponse) ?? finalURL.lastPathComponent
                    self?.startActualDownload(url: finalURL, filename: filename)
                    
                } else if let originalURL = response?.url {
                    if self?.isVerboseMode == true {
                        print("⚠️ UniversalDownloadDetector: Using original URL as fallback: \(originalURL)")
                    }
                    self?.startActualDownload(url: originalURL, filename: originalURL.lastPathComponent)
                }
            }
        }
        
        task.resume()
    }
    
    private func extractFilename(from response: HTTPURLResponse) -> String? {
        if let contentDisposition = response.allHeaderFields["Content-Disposition"] as? String {
            let patterns = [
                "filename\\*=UTF-8''([^;\\n]+)",
                "filename=\"([^\"]+)\"",
                "filename=([^;\\n]+)"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: contentDisposition, 
                                               range: NSRange(contentDisposition.startIndex..., in: contentDisposition)) {
                    
                    let range = Range(match.range(at: 1), in: contentDisposition)!
                    var filename = String(contentDisposition[range])
                    
                    filename = filename.removingPercentEncoding ?? filename
                    filename = filename.replacingOccurrences(of: "\"", with: "")
                    
                    return filename
                }
            }
        }
        return nil
    }
    
    private func startActualDownload(url: URL, filename: String) {
        if isVerboseMode {
            print("✅ UniversalDownloadDetector: Starting actual download:")
            print("   URL: \(url)")
            print("   Filename: \(filename)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                print("❌ UniversalDownloadDetector: ViewModel not available")
                return
            }
            
            let fileType = self.determineFileType(from: url.absoluteString)
            
            viewModel.addDownloadEnhanced(
                url: url.absoluteString,
                fileName: filename,
                fileType: fileType,
                savePath: "~/Downloads",
                chunks: 16,
                cookiesPath: nil
            )
            
            if self.isVerboseMode {
                print("✅ UniversalDownloadDetector: Download added to queue successfully")
            }
        }
    }
    
    private func performFullDownload(request: URLRequest) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        let task = session.downloadTask(with: request) { [weak self] location, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               let finalURL = httpResponse.url {
                
                let filename = self?.extractFilename(from: httpResponse) ?? 
                              finalURL.lastPathComponent
                
                DispatchQueue.main.async {
                    self?.startActualDownload(url: finalURL, filename: filename)
                }
            }
        }
        
        task.resume()
    }
    
    private func determineFileType(from urlString: String) -> DownloadItem.FileType {
        let url = urlString.lowercased()
        
        if url.contains(".mp4") || url.contains(".avi") || url.contains(".mkv") || 
           url.contains(".mov") || url.contains(".wmv") || url.contains(".flv") {
            return .video
        } else if url.contains(".mp3") || url.contains(".wav") || url.contains(".flac") || 
                  url.contains(".aac") || url.contains(".ogg") {
            return .audio
        } else if url.contains(".pdf") || url.contains(".doc") || url.contains(".docx") || 
                  url.contains(".xls") || url.contains(".xlsx") || url.contains(".ppt") || 
                  url.contains(".pptx") || url.contains(".txt") {
            return .document
        } else if url.contains(".exe") || url.contains(".dmg") || url.contains(".pkg") || 
                  url.contains(".deb") || url.contains(".rpm") || url.contains(".msi") || 
                  url.contains(".jar") || url.contains(".war") {
            return .executable
        } else if url.contains(".torrent") {
            return .torrent
        } else {
            return .other
        }
    }
    
    private func handleDownloadError(error: Error, url: URL) {
        let crashLogEntry = DownloadCrashLog(
            originalURL: url.absoluteString,
            headers: [:], // Headers are not directly available here
            reason: error.localizedDescription,
            timestamp: Date(),
            source: "UniversalDownloadDetector"
        )
        crashLog.append(crashLogEntry)
        if isVerboseMode {
            print("❌ UniversalDownloadDetector: Download failed with error: \(error.localizedDescription) for URL: \(url.absoluteString)")
        }
    }
    
    // MARK: - JavaScript Universal Interceptor
    private var universalInterceptorJS: String {
        // قراءة JavaScript من الملف
        if let path = Bundle.main.path(forResource: "universal-interceptor", ofType: "js"),
           let jsContent = try? String(contentsOfFile: path) {
            return jsContent
        }
        
        // Fallback إلى JavaScript مضمن
        return """
        (function() {
            console.log('🚀 SafarGet: Universal Download Interceptor loaded');
            
            // Basic interceptor for testing
            document.addEventListener('click', function(e) {
                const target = e.target.closest('a');
                if (target && target.href) {
                    const url = target.href.toLowerCase();
                    if (url.includes('.zip') || url.includes('.pdf') || url.includes('.mp4') || url.includes('/download')) {
                        console.log('🔗 SafarGet: Intercepted download link:', target.href);
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.universalDownloadDetected) {
                            window.webkit.messageHandlers.universalDownloadDetected.postMessage({
                                type: 'link_click',
                                data: {
                                    url: target.href,
                                    filename: target.download || '',
                                    method: 'GET'
                                },
                                timestamp: Date.now(),
                                source: window.location.href
                            });
                        }
                    }
                }
            }, true);
            
            console.log('✅ SafarGet: Basic interceptor loaded');
        })();
        """
    }
    
    // MARK: - Advanced Popup Interceptor JavaScript
    private var advancedPopupInterceptorJS: String {
        // قراءة JavaScript من الملف
        if let path = Bundle.main.path(forResource: "advanced-interceptor", ofType: "js"),
           let jsContent = try? String(contentsOfFile: path) {
            return jsContent
        }
        
        // Fallback إلى JavaScript مضمن
        return """
        (function() {
            console.log('🪟 SafarGet: Advanced Popup Interceptor loaded');
            
            // اعتراض جميع النقرات على الروابط
            document.addEventListener('click', function(e) {
                const target = e.target.closest('a, button, [onclick]');
                if (target) {
                    console.log('🖱️ SafarGet: Click detected on:', target.tagName, target.textContent);
                    
                    // استخراج URL من الروابط
                    if (target.href) {
                        analyzeAndReportLink(target.href, 'direct_link', target.textContent);
                    }
                    
                    // استخراج URL من onclick
                    if (target.onclick || target.getAttribute('onclick')) {
                        const onclickContent = target.onclick ? target.onclick.toString() : target.getAttribute('onclick');
                        extractURLsFromOnClick(onclickContent, target.textContent);
                    }
                    
                    // استخراج URL من data attributes
                    const dataUrl = target.getAttribute('data-url') || target.getAttribute('data-href') || target.getAttribute('data-link');
                    if (dataUrl) {
                        analyzeAndReportLink(dataUrl, 'data_attribute', target.textContent);
                    }
                }
            }, true);
            
            // اعتراض window.open
            const originalWindowOpen = window.open;
            window.open = function(url, name, features) {
                console.log('🪟 SafarGet: window.open intercepted:', url);
                if (url) {
                    analyzeAndReportLink(url, 'window_open', 'Popup Window');
                }
                return originalWindowOpen.call(this, url, name, features);
            };
            
            // اعتراض location.href changes
            const originalLocationHref = Object.getOwnPropertyDescriptor(Location.prototype, 'href');
            Object.defineProperty(location, 'href', {
                set: function(url) {
                    console.log('🪟 SafarGet: location.href change intercepted:', url);
                    analyzeAndReportLink(url, 'location_href', 'Page Navigation');
                    return originalLocationHref.set.call(this, url);
                },
                get: originalLocationHref.get
            });
            
            // تحليل الصفحة عند التحميل
            function analyzePage() {
                console.log('🔍 SafarGet: Analyzing page for download links...');
                
                // البحث عن جميع الروابط
                const links = document.querySelectorAll('a[href]');
                links.forEach(function(link) {
                    const url = link.href;
                    const text = link.textContent.trim();
                    
                    if (isDownloadLink(url, text)) {
                        analyzeAndReportLink(url, 'page_analysis', text);
                    }
                });
                
                // البحث عن أزرار التحميل
                const buttons = document.querySelectorAll('button, input[type="button"], .btn, .download-btn, [class*="download"]');
                buttons.forEach(function(btn) {
                    const text = btn.textContent.trim();
                    if (isDownloadButton(text)) {
                        console.log('🔘 SafarGet: Download button found:', text);
                        
                        // محاولة استخراج URL من الزر
                        const dataUrl = btn.getAttribute('data-url') || btn.getAttribute('data-href');
                        if (dataUrl) {
                            analyzeAndReportLink(dataUrl, 'button_data', text);
                        }
                    }
                });
                
                // البحث عن iframes
                const iframes = document.querySelectorAll('iframe[src]');
                iframes.forEach(function(iframe) {
                    const src = iframe.src;
                    console.log('🖼️ SafarGet: iframe found:', src);
                    analyzeAndReportLink(src, 'iframe', 'iframe content');
                });
                
                // البحث عن scripts
                const scripts = document.querySelectorAll('script');
                scripts.forEach(function(script) {
                    const content = script.textContent || script.innerHTML;
                    if (content.includes('download') || content.includes('file') || content.includes('url')) {
                        console.log('📜 SafarGet: Script with download content found');
                        extractURLsFromScript(content);
                    }
                });
            }
            
            // فحص ما إذا كان الرابط رابط تحميل
            function isDownloadLink(url, text) {
                const urlLower = url.toLowerCase();
                const textLower = text.toLowerCase();
                
                // فحص امتدادات الملفات
                const extensions = ['.zip', '.rar', '.7z', '.pdf', '.doc', '.docx', '.mp4', '.avi', '.mkv', '.mp3', '.wav'];
                for (const ext of extensions) {
                    if (urlLower.includes(ext)) return true;
                }
                
                // فحص كلمات مفتاحية في URL
                const urlKeywords = ['/download', '/dl/', '/get/', '/file/', '/attachment', 'download=', 'file='];
                for (const keyword of urlKeywords) {
                    if (urlLower.includes(keyword)) return true;
                }
                
                // فحص كلمات مفتاحية في النص
                const textKeywords = ['تحميل', 'نزل', 'download', 'تحميل مباشر', 'رابط مباشر'];
                for (const keyword of textKeywords) {
                    if (textLower.includes(keyword)) return true;
                }
                
                return false;
            }
            
            // فحص ما إذا كان الزر زر تحميل
            function isDownloadButton(text) {
                const textLower = text.toLowerCase();
                const keywords = ['تحميل', 'نزل', 'download', 'تحميل مباشر', 'رابط مباشر', 'حفظ', 'save'];
                return keywords.some(keyword => textLower.includes(keyword));
            }
            
            // استخراج URLs من onclick
            function extractURLsFromOnClick(onclickContent, buttonText) {
                if (!onclickContent) return;
                
                console.log('🔍 SafarGet: Analyzing onclick content:', onclickContent);
                
                // البحث عن URLs في onclick
                const urlPatterns = [
                    /['"`](https?:\\/\\/[^'"`]+)['"`]/g,
                    /window\\.open\\(['"`]([^'"`]+)['"`]\\)/g,
                    /location\\.href\\s*=\\s*['"`]([^'"`]+)['"`]/g
                ];
                
                for (const pattern of urlPatterns) {
                    let match;
                    while ((match = pattern.exec(onclickContent)) !== null) {
                        const url = match[1];
                        console.log('🔗 SafarGet: URL found in onclick:', url);
                        analyzeAndReportLink(url, 'onclick', buttonText);
                    }
                }
            }
            
            // استخراج URLs من scripts
            function extractURLsFromScript(scriptContent) {
                const urlPatterns = [
                    /['"`](https?:\\/\\/[^'"`]+\\.(?:zip|rar|7z|pdf|doc|docx|mp4|avi|mkv|mp3|wav))['"`]/g,
                    /['"`](https?:\\/\\/[^'"`]*\\/download[^'"`]*)['"`]/g,
                    /['"`](https?:\\/\\/[^'"`]*\\/dl\\/[^'"`]*)['"`]/g
                ];
                
                for (const pattern of urlPatterns) {
                    let match;
                    while ((match = pattern.exec(scriptContent)) !== null) {
                        const url = match[1];
                        console.log('🔗 SafarGet: URL found in script:', url);
                        analyzeAndReportLink(url, 'script', 'script content');
                    }
                }
            }
            
            // تحليل وإرسال الرابط
            function analyzeAndReportLink(url, source, text) {
                console.log('🔗 SafarGet: Analyzing link:', url, 'from:', source);
                
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.popupDownloadDetected) {
                    window.webkit.messageHandlers.popupDownloadDetected.postMessage({
                        type: 'popup_link',
                        data: {
                            url: url,
                            source: source,
                            text: text,
                            timestamp: Date.now()
                        }
                    });
                }
            }
            
            // تشغيل التحليل عند تحميل الصفحة
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', analyzePage);
            } else {
                analyzePage();
            }
            
            // تشغيل التحليل كل 2 ثانية للتأكد من اكتشاف جميع الروابط
            setInterval(analyzePage, 2000);
            
            console.log('✅ SafarGet: Advanced Popup Interceptor loaded successfully');
        })();
        """
    }
}

// MARK: - WKNavigationDelegate
extension UniversalDownloadDetector: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let request = navigationAction.request
        
        if shouldInterceptAsDownload(request: request) {
            if isVerboseMode {
                print("🚫 UniversalDownloadDetector: Cancelling navigation for download: \(request.url?.absoluteString ?? "")")
            }
            decisionHandler(.cancel)
            startUniversalDownload(from: request)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
        let response = navigationResponse.response
        
        if let httpResponse = response as? HTTPURLResponse {
            
            // فحص Content-Disposition
            if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
               contentDisposition.contains("attachment") {
                
                if isVerboseMode {
                    print("📎 UniversalDownloadDetector: Content-Disposition attachment detected")
                }
                decisionHandler(.cancel)
                extractFinalURLAndDownload(from: httpResponse, originalRequest: navigationResponse.response.url!)
                return
            }
            
            // فحص Content-Type
            if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                for type in downloadableMimeTypes {
                    if contentType.contains(type) {
                        if isVerboseMode {
                            print("📄 UniversalDownloadDetector: Downloadable Content-Type detected: \(contentType)")
                        }
                        decisionHandler(.cancel)
                        extractFinalURLAndDownload(from: httpResponse, originalRequest: response.url!)
                        return
                    }
                }
            }
            
            // فحص URL للامتدادات
            if let url = response.url?.absoluteString {
                for ext in fileExtensions {
                    if url.lowercased().contains(".\(ext)") {
                        if isVerboseMode {
                            print("🔗 UniversalDownloadDetector: Downloadable extension detected: .\(ext)")
                        }
                        decisionHandler(.cancel)
                        extractFinalURLAndDownload(from: httpResponse, originalRequest: response.url!)
                        return
                    }
                }
            }
        }
        
        decisionHandler(.allow)
    }
}

// MARK: - WKScriptMessageHandler
extension UniversalDownloadDetector: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        
        guard let dict = message.body as? [String: Any] else { return }
        
        switch message.name {
        case "universalDownloadDetected":
            handleUniversalDownload(dict)
            
        case "blobDownloadDetected":
            handleBlobDownload(dict)
            
        case "xhrDownloadDetected":
            handleXHRDownload(dict)
            
        case "fetchDownloadDetected":
            handleFetchDownload(dict)
            
        case "serviceWorkerDetected":
            handleServiceWorkerDownload(dict)
            
        case "metaRefreshDetected":
            handleMetaRefreshDownload(dict)
            
        case "popupDownloadDetected":
            handlePopupDownload(dict)
            
        case "popupLinkExtracted":
            handlePopupLinkExtracted(dict)
            
        case "DOWNLOAD_INTERCEPTED":
            handleAdvancedDownloadInterception(dict)
            
        default:
            break
        }
    }
    
    private func handleUniversalDownload(_ info: [String: Any]) {
        guard let type = info["type"] as? String,
              let data = info["data"] as? [String: Any],
              let urlString = data["url"] as? String,
              let url = URL(string: urlString) else { return }
        
        if isVerboseMode {
            print("🎯 UniversalDownloadDetector: \(type) download detected: \(url)")
        }
        
        var request = URLRequest(url: url)
        
        if let method = data["method"] as? String {
            request.httpMethod = method
        }
        
        startUniversalDownload(from: request)
    }
    
    private func handleBlobDownload(_ info: [String: Any]) {
        // معالجة Blob downloads
        if let blobUrl = info["blobUrl"] as? String {
            if isVerboseMode {
                print("💾 UniversalDownloadDetector: Blob download detected: \(blobUrl)")
            }
            // يمكن إضافة معالجة خاصة للـ Blob downloads هنا
        }
    }
    
    private func handleXHRDownload(_ info: [String: Any]) {
        // معالجة XHR downloads
        if let urlString = info["url"] as? String,
           let url = URL(string: urlString) {
            if isVerboseMode {
                print("📡 UniversalDownloadDetector: XHR download detected: \(url)")
            }
            startUniversalDownload(from: URLRequest(url: url))
        }
    }
    
    private func handleFetchDownload(_ info: [String: Any]) {
        // معالجة Fetch downloads
        if let urlString = info["url"] as? String,
           let url = URL(string: urlString) {
            if isVerboseMode {
                print("🌐 UniversalDownloadDetector: Fetch download detected: \(url)")
            }
            startUniversalDownload(from: URLRequest(url: url))
        }
    }
    
    private func handleServiceWorkerDownload(_ info: [String: Any]) {
        // معالجة Service Worker downloads
        if let urlString = info["url"] as? String,
           let url = URL(string: urlString) {
            if isVerboseMode {
                print("🔧 UniversalDownloadDetector: Service Worker download detected: \(url)")
            }
            startUniversalDownload(from: URLRequest(url: url))
        }
    }
    
    private func handleMetaRefreshDownload(_ info: [String: Any]) {
        // معالجة Meta Refresh downloads
        if let urlString = info["url"] as? String,
           let url = URL(string: urlString) {
            if isVerboseMode {
                print("🔄 UniversalDownloadDetector: Meta refresh download detected: \(url)")
            }
            startUniversalDownload(from: URLRequest(url: url))
        }
    }
    
    private func handlePopupDownload(_ info: [String: Any]) {
        // معالجة الصفحات المنبثقة
        guard let type = info["type"] as? String,
              let data = info["data"] as? [String: Any],
              let urlString = data["url"] as? String,
              let url = URL(string: urlString) else { return }
        
        if isVerboseMode {
            print("🪟 UniversalDownloadDetector: Popup download detected:")
            print("   Type: \(type)")
            print("   URL: \(urlString)")
            print("   Source: \(data["source"] as? String ?? "unknown")")
            print("   Text: \(data["text"] as? String ?? "unknown")")
        }
        
        // محاولة التحميل المباشر
        startUniversalDownload(from: URLRequest(url: url))
    }
    
    private func handlePopupLinkExtracted(_ info: [String: Any]) {
        // معالجة الروابط المستخرجة من الصفحات المنبثقة
        guard let data = info["data"] as? [String: Any],
              let urlString = data["url"] as? String,
              let url = URL(string: urlString) else { return }
        
        if isVerboseMode {
            print("🔗 UniversalDownloadDetector: Popup link extracted: \(urlString)")
        }
        
        // محاولة التحميل المباشر
        startUniversalDownload(from: URLRequest(url: url))
    }
}

// MARK: - WKUIDelegate
extension UniversalDownloadDetector: WKUIDelegate {
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        // اعتراض جميع النوافذ المنبثقة لتحليلها
        if isVerboseMode {
            print("🪟 UniversalDownloadDetector: Popup window detected: \(navigationAction.request.url?.absoluteString ?? "")")
        }
        
        // إنشاء WebView جديد لتحليل المحتوى
        let popupWebView = WKWebView(frame: .zero, configuration: configuration)
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self
        
        // حقن JavaScript متقدم لاستخراج الروابط
        let advancedScript = WKUserScript(
            source: advancedPopupInterceptorJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        popupWebView.configuration.userContentController.addUserScript(advancedScript)
        popupWebView.configuration.userContentController.add(self, name: "popupDownloadDetected")
        popupWebView.configuration.userContentController.add(self, name: "popupLinkExtracted")
        popupWebView.configuration.userContentController.add(self, name: "DOWNLOAD_INTERCEPTED")
        
        // تحميل الصفحة المنبثقة
        popupWebView.load(navigationAction.request)
        
        return popupWebView
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // تحليل الصفحة بعد اكتمال التحميل
        analyzePopupPage(webView)
    }
    
    private func analyzePopupPage(_ webView: WKWebView) {
        // تحليل متقدم للصفحة المنبثقة
        let analysisScript = """
        (function() {
            var downloadLinks = [];
            
            // البحث عن روابط التحميل المباشرة
            var links = document.querySelectorAll('a[href*="download"], a[href*="dl"], a[href*="get"], a[href*="file"]');
            links.forEach(function(link) {
                downloadLinks.push({
                    url: link.href,
                    text: link.textContent.trim(),
                    type: 'direct_link'
                });
            });
            
            // البحث عن أزرار التحميل
            var buttons = document.querySelectorAll('button, input[type="button"], .btn, .download-btn');
            buttons.forEach(function(btn) {
                if (btn.textContent.toLowerCase().includes('download') || 
                    btn.textContent.toLowerCase().includes('تحميل') ||
                    btn.textContent.toLowerCase().includes('نزل')) {
                    downloadLinks.push({
                        url: btn.getAttribute('data-url') || btn.getAttribute('onclick'),
                        text: btn.textContent.trim(),
                        type: 'download_button'
                    });
                }
            });
            
            // البحث عن iframes
            var iframes = document.querySelectorAll('iframe');
            iframes.forEach(function(iframe) {
                downloadLinks.push({
                    url: iframe.src,
                    text: 'iframe content',
                    type: 'iframe'
                });
            });
            
            // البحث عن scripts
            var scripts = document.querySelectorAll('script');
            scripts.forEach(function(script) {
                var content = script.textContent || script.innerHTML;
                if (content.includes('download') || content.includes('file') || content.includes('url')) {
                    downloadLinks.push({
                        url: content,
                        text: 'script content',
                        type: 'script'
                    });
                }
            });
            
            return downloadLinks;
        })();
        """
        
        webView.evaluateJavaScript(analysisScript) { [weak self] result, error in
            if let links = result as? [[String: Any]] {
                self?.processPopupLinks(links)
            }
        }
    }
    
    private func processPopupLinks(_ links: [[String: Any]]) {
        for link in links {
            if let urlString = link["url"] as? String,
               let url = URL(string: urlString) {
                
                if isVerboseMode {
                    print("🔗 UniversalDownloadDetector: Found popup link: \(urlString)")
                }
                
                // محاولة التحميل المباشر
                startUniversalDownload(from: URLRequest(url: url))
            }
        }
    }
    
    // MARK: - Advanced Download Interception
    private func handleAdvancedDownloadInterception(_ info: [String: Any]) {
        if let data = info["data"] as? [String: Any],
           let urlString = data["url"] as? String,
           let url = URL(string: urlString) {
            
            if isVerboseMode {
                print("🚫 UniversalDownloadDetector: Advanced download intercepted: \(urlString)")
                print("   Source: \(data["source"] as? String ?? "unknown")")
            }
            
            // بدء التحميل المباشر
            startUniversalDownload(from: URLRequest(url: url))
        }
    }
}

// MARK: - URLSession Delegate
extension UniversalDownloadDetector: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        
        if isVerboseMode {
            print("🔄 UniversalDownloadDetector: Following redirect: \(request.url?.absoluteString ?? "")")
        }
        
        // تسجيل الـ redirect
        if let originalURL = task.originalRequest?.url,
           let newURL = request.url {
            redirectTracker?.recordRedirect(from: originalURL, to: newURL, response: response)
        }
        
        completionHandler(request)
    }
    
    @MainActor
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Download Crash Log Model
struct DownloadCrashLog {
    let originalURL: String
    let headers: [String: String]
    let reason: String
    let timestamp: Date
    let source: String
    
    var description: String {
        return """
        Crash Log:
        URL: \(originalURL)
        Reason: \(reason)
        Source: \(source)
        Timestamp: \(timestamp)
        Headers: \(headers)
        """
    }
}
