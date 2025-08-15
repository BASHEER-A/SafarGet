import Foundation
import WebKit

// MARK: - Enhanced Download Manager
class EnhancedDownloadManager: NSObject {
    
    private weak var viewModel: DownloadManagerViewModel?
    private var downloadInterceptors: [String: SmartDownloadInterceptor] = [:]
    
    init(viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    // MARK: - إنشاء WebView محسن مع اعتراض التحميلات
    func createEnhancedWebView(for url: URL? = nil) -> WKWebView {
        let interceptor = SmartDownloadInterceptor(viewModel: viewModel!)
        let webView = interceptor.setupWebView()
        
        // حفظ المرجع للـ interceptor
        if let urlString = url?.absoluteString {
            downloadInterceptors[urlString] = interceptor
        }
        
        return webView
    }
    
    // MARK: - تحميل URL مع اعتراض التحميلات
    func loadURL(_ url: URL, in webView: WKWebView) {
        print("🌐 SafarGet: Loading URL with enhanced download interception: \(url)")
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    // MARK: - تنظيف الموارد
    func cleanup() {
        downloadInterceptors.removeAll()
        print("🧹 SafarGet: Enhanced Download Manager cleaned up")
    }
    
    // MARK: - إضافة تحميل محسن
    func addEnhancedDownload(url: String, filename: String? = nil, source: String = "enhanced_interceptor") {
        guard let viewModel = viewModel else {
            print("❌ SafarGet: ViewModel not available for enhanced download")
            return
        }
        
        let finalFilename = filename ?? extractFileName(from: url)
        let fileType = determineFileType(from: url)
        
        print("🚀 SafarGet: Adding enhanced download:")
        print("   URL: \(url)")
        print("   Filename: \(finalFilename)")
        print("   Type: \(fileType)")
        print("   Source: \(source)")
        
        viewModel.addDownloadEnhanced(
            url: url,
            fileName: finalFilename,
            fileType: fileType,
            savePath: "~/Downloads",
            chunks: 16,
            cookiesPath: nil
        )
    }
    
    // MARK: - استخراج اسم الملف
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "download" }
        
        let fileName = url.lastPathComponent
        
        // إذا كان اسم الملف فارغاً أو غير صالح
        if fileName.isEmpty || fileName == "/" {
            // محاولة استخراج من query parameters
            if let components = URLComponents(string: urlString),
               let queryItems = components.queryItems {
                
                for item in queryItems {
                    if item.name.lowercased().contains("file") || 
                       item.name.lowercased().contains("name") {
                        if let value = item.value, !value.isEmpty {
                            return value
                        }
                    }
                }
            }
            
            // استخدام اسم افتراضي بناءً على نوع الملف
            let fileType = determineFileType(from: urlString)
            switch fileType {
            case .video:
                return "video.mp4"
            case .audio:
                return "audio.mp3"
            case .document:
                return "document.pdf"
            case .executable:
                return "program.exe"
            case .torrent:
                return "file.torrent"
            default:
                return "download"
            }
        }
        
        return fileName
    }
    
    // MARK: - تحديد نوع الملف
    private func determineFileType(from urlString: String) -> DownloadItem.FileType {
        let url = urlString.lowercased()
        
        // فحص امتدادات الفيديو
        let videoExtensions = [".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".3gp"]
        for ext in videoExtensions {
            if url.contains(ext) {
                return .video
            }
        }
        
        // فحص امتدادات الصوت
        let audioExtensions = [".mp3", ".wav", ".flac", ".aac", ".ogg", ".m4a", ".wma"]
        for ext in audioExtensions {
            if url.contains(ext) {
                return .audio
            }
        }
        
        // فحص امتدادات المستندات
        let documentExtensions = [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".rtf"]
        for ext in documentExtensions {
            if url.contains(ext) {
                return .document
            }
        }
        
        // فحص امتدادات البرامج
        let programExtensions = [".exe", ".dmg", ".pkg", ".deb", ".rpm", ".msi", ".jar", ".war", ".apk"]
        for ext in programExtensions {
            if url.contains(ext) {
                return .executable
            }
        }
        
        // فحص امتدادات الأرشيف
        let archiveExtensions = [".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz"]
        for ext in archiveExtensions {
            if url.contains(ext) {
                return .other
            }
        }
        
        // فحص امتدادات الصور
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".svg", ".webp"]
        for ext in imageExtensions {
            if url.contains(ext) {
                return .other
            }
        }
        
        // فحص امتدادات التورنت
        if url.contains(".torrent") {
            return .torrent
        }
        
        // فحص كلمات مفتاحية في URL
        let downloadKeywords = ["/download", "download=", "attachment", "/file/", "/get/", "/export", "/save"]
        for keyword in downloadKeywords {
            if url.contains(keyword) {
                return .other
            }
        }
        
        return .other
    }
}

// MARK: - Extension للـ ViewModel
extension DownloadManagerViewModel {
    
    // إضافة تحميل محسن مع معالجة أفضل
    func addEnhancedDownload(url: String, filename: String? = nil, source: String = "enhanced") {
        let finalFilename = filename ?? extractFileName(from: url)
        let fileType = determineFileType(from: url)
        
        print("🚀 SafarGet: Adding enhanced download via ViewModel:")
        print("   URL: \(url)")
        print("   Filename: \(finalFilename)")
        print("   Type: \(fileType)")
        print("   Source: \(source)")
        
        addDownloadEnhanced(
            url: url,
            fileName: finalFilename,
            fileType: fileType,
            savePath: "~/Downloads",
            chunks: 16,
            cookiesPath: nil
        )
    }
    
    // استخراج اسم الملف محسن
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "download" }
        
        let fileName = url.lastPathComponent
        
        if fileName.isEmpty || fileName == "/" {
            if let components = URLComponents(string: urlString),
               let queryItems = components.queryItems {
                
                for item in queryItems {
                    if item.name.lowercased().contains("file") || 
                       item.name.lowercased().contains("name") {
                        if let value = item.value, !value.isEmpty {
                            return value
                        }
                    }
                }
            }
            
            let fileType = determineFileType(from: urlString)
            switch fileType {
            case .video:
                return "video.mp4"
            case .audio:
                return "audio.mp3"
            case .document:
                return "document.pdf"
            case .executable:
                return "program.exe"
            case .torrent:
                return "file.torrent"
            default:
                return "download"
            }
        }
        
        return fileName
    }
    
    // تحديد نوع الملف محسن
    private func determineFileType(from urlString: String) -> DownloadItem.FileType {
        let url = urlString.lowercased()
        
        let videoExtensions = [".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".3gp"]
        for ext in videoExtensions {
            if url.contains(ext) {
                return .video
            }
        }
        
        let audioExtensions = [".mp3", ".wav", ".flac", ".aac", ".ogg", ".m4a", ".wma"]
        for ext in audioExtensions {
            if url.contains(ext) {
                return .audio
            }
        }
        
        let documentExtensions = [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".rtf"]
        for ext in documentExtensions {
            if url.contains(ext) {
                return .document
            }
        }
        
        let programExtensions = [".exe", ".dmg", ".pkg", ".deb", ".rpm", ".msi", ".jar", ".war", ".apk"]
        for ext in programExtensions {
            if url.contains(ext) {
                return .executable
            }
        }
        
        if url.contains(".torrent") {
            return .torrent
        }
        
        return .other
    }
}
