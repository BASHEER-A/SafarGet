import WebKit
import UniformTypeIdentifiers
import Foundation

// MARK: - Smart Download Interceptor
class SmartDownloadInterceptor: NSObject {
    
    private var webView: WKWebView!
    private weak var viewModel: DownloadManagerViewModel?
    
    init(viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    // MARK: - إعداد WKWebView مع اعتراض كامل
    func setupWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // حقن JavaScript لاعتراض كل شيء
        let script = WKUserScript(
            source: downloadInterceptorJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(script)
        
        // معالجات JavaScript
        config.userContentController.add(self, name: "downloadDetected")
        config.userContentController.add(self, name: "blobDownload")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        return webView
    }
    
    // MARK: - JavaScript للاعتراض الشامل
    private var downloadInterceptorJS: String {
        """
        (function() {
            console.log('🚀 SafarGet: Smart Download Interceptor loaded');
            
            // اعتراض النقرات على الروابط
            document.addEventListener('click', function(e) {
                let target = e.target;
                while(target && target.tagName !== 'A') {
                    target = target.parentElement;
                }
                
                if(target && target.href) {
                    if(target.download || 
                       target.href.match(/\\.(zip|apk|exe|dmg|pdf|doc|xls|ppt|rar|7z|tar|gz|mp3|mp4|avi|mkv|iso|img|deb|rpm|pkg|msi|jar|war)$/i) ||
                       target.href.includes('/download') ||
                       target.href.includes('download=') ||
                       target.href.includes('mirror.tejas101k')) {
                        e.preventDefault();
                        e.stopPropagation();
                        console.log('🔗 SafarGet: Intercepted link click:', target.href);
                        window.webkit.messageHandlers.downloadDetected.postMessage({
                            url: target.href,
                            filename: target.download || '',
                            type: 'link',
                            source: window.location.href
                        });
                        return false;
                    }
                }
            }, true);
            
            // اعتراض window.open
            const originalOpen = window.open;
            window.open = function(url, target, features) {
                if(url && (url.includes('/download') || 
                          url.match(/\\.(zip|apk|exe|dmg|pdf|doc|xls|ppt|rar|7z|tar|gz|mp3|mp4|avi|mkv|iso|img|deb|rpm|pkg|msi|jar|war)$/i) ||
                          url.includes('mirror.tejas101k'))) {
                    console.log('🪟 SafarGet: Intercepted window.open:', url);
                    window.webkit.messageHandlers.downloadDetected.postMessage({
                        url: url,
                        type: 'window.open',
                        source: window.location.href
                    });
                    return { close: function() {}, focus: function() {} };
                }
                return originalOpen.call(this, url, target, features);
            };
            
            // اعتراض location changes
            const originalLocationHref = Object.getOwnPropertyDescriptor(window.location, 'href');
            Object.defineProperty(window.location, 'href', {
                get: function() {
                    return originalLocationHref.get.call(this);
                },
                set: function(value) {
                    if(value && (value.includes('/download') || 
                                value.match(/\\.(zip|apk|exe|dmg|pdf|doc|xls|ppt|rar|7z|tar|gz|mp3|mp4|avi|mkv|iso|img|deb|rpm|pkg|msi|jar|war)$/i) ||
                                value.includes('mirror.tejas101k'))) {
                        console.log('📍 SafarGet: Intercepted location.href:', value);
                        window.webkit.messageHandlers.downloadDetected.postMessage({
                            url: value,
                            type: 'location.href',
                            source: window.location.href
                        });
                        return;
                    }
                    return originalLocationHref.set.call(this, value);
                }
            });
            
            console.log('✅ SafarGet: Smart Download Interceptor fully loaded');
        })();
        """
    }
}

// MARK: - معالجة Navigation
extension SmartDownloadInterceptor: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let request = navigationAction.request
        
        if navigationAction.navigationType == .linkActivated ||
           navigationAction.navigationType == .formSubmitted ||
           navigationAction.navigationType == .other {
            
            if shouldInterceptAsDownload(request: request) {
                print("🚫 SafarGet: Cancelling navigation for download: \(request.url?.absoluteString ?? "")")
                decisionHandler(.cancel)
                startSmartDownload(from: request)
                return
            }
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
                
                print("📎 SafarGet: Content-Disposition attachment detected")
                decisionHandler(.cancel)
                extractFinalURLAndDownload(from: httpResponse, originalRequest: navigationResponse.response.url!)
                return
            }
            
            // فحص Content-Type
            if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
                let downloadableTypes = [
                    "application/zip", "application/x-zip",
                    "application/octet-stream",
                    "application/pdf",
                    "application/vnd.android.package-archive",
                    "application/x-msdownload",
                    "application/x-apple-diskimage",
                    "video/", "audio/"
                ]
                
                for type in downloadableTypes {
                    if contentType.contains(type) {
                        print("��📄 SafarGet: Downloadable Content-Type detected: \(contentType)")
                        decisionHandler(.cancel)
                        extractFinalURLAndDownload(from: httpResponse, originalRequest: response.url!)
                        return
                    }
                }
            }
            
            // فحص URL للامتدادات
            if let url = response.url?.absoluteString {
                let downloadExtensions = ["zip", "apk", "exe", "dmg", "pdf", "doc", "docx", "xls", "xlsx", 
                                         "ppt", "pptx", "rar", "7z", "tar", "gz", "mp3", "mp4", "avi", "mkv", 
                                         "iso", "img", "deb", "rpm", "pkg", "msi", "jar", "war"]
                
                for ext in downloadExtensions {
                    if url.lowercased().contains(".\(ext)") {
                        print("🔗 SafarGet: Downloadable extension detected: .\(ext)")
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

// MARK: - استخراج الرابط النهائي
extension SmartDownloadInterceptor {
    
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
                    
                    print("✅ SafarGet: Final URL extracted: \(finalURL)")
                    
                    let filename = self?.extractFilename(from: finalResponse) ?? finalURL.lastPathComponent
                    self?.startActualDownload(url: finalURL, filename: filename)
                    
                } else if let originalURL = response?.url {
                    print("⚠️ SafarGet: Using original URL as fallback: \(originalURL)")
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
}

// MARK: - URLSession Delegate
extension SmartDownloadInterceptor: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        
        print("🔄 SafarGet: Following redirect: \(request.url?.absoluteString ?? "")")
        completionHandler(request)
    }
    
    @MainActor
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
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

// MARK: - معالجة رسائل JavaScript
extension SmartDownloadInterceptor: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        
        guard let dict = message.body as? [String: Any] else { return }
        
        switch message.name {
        case "downloadDetected":
            if let urlString = dict["url"] as? String,
               let url = URL(string: urlString) {
                handleJSDownload(url: url, info: dict)
            }
            
        case "blobDownload":
            if let blobUrl = dict["blobUrl"] as? String,
               let originalUrl = dict["originalUrl"] as? String {
                handleBlobDownload(blobUrl: blobUrl, originalUrl: originalUrl, info: dict)
            }
            
        default:
            break
        }
    }
    
    private func handleJSDownload(url: URL, info: [String: Any]) {
        print("��🎯 SafarGet: JavaScript download detected: \(url)")
        
        var request = URLRequest(url: url)
        
        if let method = info["method"] as? String {
            request.httpMethod = method
        }
        
        startSmartDownload(from: request)
    }
    
    private func handleBlobDownload(blobUrl: String, originalUrl: String, info: [String: Any]) {
        print("💾 SafarGet: Blob download detected: \(originalUrl)")
        
        webView.evaluateJavaScript("""
            fetch('\(blobUrl)')
                .then(res => res.blob())
                .then(blob => {
                    const reader = new FileReader();
                    reader.onloadend = function() {
                        window.webkit.messageHandlers.blobData.postMessage({
                            data: reader.result,
                            filename: '\(info["filename"] ?? "")',
                            originalUrl: '\(originalUrl)'
                        });
                    };
                    reader.readAsDataURL(blob);
                });
        """)
    }
}

// MARK: - WKUIDelegate
extension SmartDownloadInterceptor: WKUIDelegate {
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        if shouldInterceptAsDownload(request: navigationAction.request) {
            print("🪟 SafarGet: Intercepted popup download: \(navigationAction.request.url?.absoluteString ?? "")")
            startSmartDownload(from: navigationAction.request)
            return nil
        }
        
        webView.load(navigationAction.request)
        return nil
    }
}

// MARK: - الدوال المساعدة
extension SmartDownloadInterceptor {
    
    private func shouldInterceptAsDownload(request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString.lowercased() else { return false }
        
        let downloadIndicators = [
            ".zip", ".apk", ".exe", ".dmg", ".pdf", ".doc", ".docx",
            ".xls", ".xlsx", ".ppt", ".pptx", ".rar", ".7z", ".tar",
            ".gz", ".mp3", ".mp4", ".avi", ".mkv", ".iso", ".img",
            ".deb", ".rpm", ".pkg", ".msi", ".jar", ".war",
            "/download", "download=", "attachment", "/file/",
            "/get/", "/export", "/save", "mirror.tejas101k"
        ]
        
        for indicator in downloadIndicators {
            if url.contains(indicator) {
                return true
            }
        }
        
        return false
    }
    
    private func startSmartDownload(from request: URLRequest) {
        print("🚀 SafarGet: Starting smart download for: \(request.url?.absoluteString ?? "")")
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        var headRequest = request
        headRequest.httpMethod = "HEAD"
        headRequest.setValue("SafarGet/1.0", forHTTPHeaderField: "User-Agent")
        
        let task = session.dataTask(with: headRequest) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self?.extractFinalURLAndDownload(from: httpResponse, 
                                                    originalRequest: request.url!)
                } else {
                    self?.performFullDownload(request: request)
                }
            }
        }
        
        task.resume()
    }
    
    private func startActualDownload(url: URL, filename: String) {
        print("✅ SafarGet: Starting actual download:")
        print("   URL: \(url)")
        print("   Filename: \(filename)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                print("❌ SafarGet: ViewModel not available")
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
            
            print("✅ SafarGet: Download added to queue successfully")
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
}
