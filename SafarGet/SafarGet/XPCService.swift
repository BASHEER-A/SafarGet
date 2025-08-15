import Foundation
import Network
import AppKit

// MARK: - XPC Service Protocol
@objc protocol SafarGetXPCServiceProtocol {
    func handleDownloadRequest(url: String, headers: [String: String], contentType: String?, completion: @escaping (Bool, String) -> Void)
    func handleVideoStreamRequest(url: String, headers: [String: String], contentType: String?, completion: @escaping (Bool, String) -> Void)
    func handleVideoCaptureRequest(videoData: [String: Any], completion: @escaping (Bool, String) -> Void)
    func ping(completion: @escaping (String) -> Void)
}

// MARK: - XPC Service Implementation
class SafarGetXPCService: NSObject, SafarGetXPCServiceProtocol {
    
    private var viewModel: DownloadManagerViewModel?
    private let queue = DispatchQueue(label: "com.SafarGet.xpc", qos: .userInitiated)
    
    override init() {
        super.init()
        print("🚀 SafarGet XPC Service initialized")
    }
    
    func setViewModel(_ viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
    }
    
    // MARK: - Protocol Methods
    
    @objc func handleDownloadRequest(url: String, headers: [String: String], contentType: String?, completion: @escaping (Bool, String) -> Void) {
        print("📥 XPC: Handling download request for URL: \(url)")
        
        guard let viewModel = viewModel else {
            completion(false, "ViewModel not available")
            return
        }
        
        // استخراج اسم الملف من URL
        let fileName = extractFileName(from: url, contentType: contentType)
        
        // تحديد نوع الملف
        let fileType = determineFileType(from: url, contentType: contentType)
        
        queue.async {
            DispatchQueue.main.async {
                // إضافة التحميل إلى ViewModel
                viewModel.addDownloadEnhanced(
                    url: url,
                    fileName: fileName,
                    fileType: fileType,
                    savePath: "~/Downloads",
                    chunks: 16,
                    cookiesPath: nil
                )
                
                completion(true, "Download added successfully")
            }
        }
    }
    
    @objc func handleVideoStreamRequest(url: String, headers: [String: String], contentType: String?, completion: @escaping (Bool, String) -> Void) {
        print("🎬 XPC: Handling video stream request for URL: \(url)")
        
        guard let viewModel = viewModel else {
            completion(false, "ViewModel not available")
            return
        }
        
        // استخراج اسم الملف من URL أو استخدام اسم افتراضي
        let fileName = extractVideoFileName(from: url, contentType: contentType)
        
        queue.async {
            DispatchQueue.main.async {
                // إضافة التحميل كفيديو
                viewModel.addDownloadEnhanced(
                    url: url,
                    fileName: fileName,
                    fileType: .video,
                    savePath: "~/Downloads",
                    chunks: 16,
                    cookiesPath: nil
                )
                
                completion(true, "Video download added successfully")
            }
        }
    }
    
    @objc func handleVideoCaptureRequest(videoData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        print("📹 XPC: Handling video capture request")
        
        guard let viewModel = viewModel else {
            completion(false, "ViewModel not available")
            return
        }
        
        // استخراج البيانات من videoData
        guard let url = videoData["url"] as? String else {
            completion(false, "Missing URL in video capture data")
            return
        }
        
        let headers = videoData["headers"] as? [String: String] ?? [:]
        let pageTitle = videoData["pageTitle"] as? String ?? "Video"
        let videoType = videoData["videoType"] as? String ?? "unknown"
        let contentType = videoData["contentType"] as? String
        
        // إنشاء اسم ملف فريد
        let fileName = generateVideoFileName(from: url, pageTitle: pageTitle, videoType: videoType)
        
        queue.async {
            DispatchQueue.main.async {
                // إضافة التحميل مع headers مخصصة
                viewModel.addVideoDownloadWithHeaders(
                    url: url,
                    fileName: fileName,
                    headers: headers,
                    pageTitle: pageTitle,
                    videoType: videoType,
                    contentType: contentType
                )
                
                completion(true, "Video capture processed successfully")
            }
        }
    }
    
    @objc func ping(completion: @escaping (String) -> Void) {
        completion("SafarGet XPC Service is running")
    }
    
    // MARK: - Helper Methods
    
    private func extractFileName(from url: String, contentType: String?) -> String {
        guard let urlObj = URL(string: url) else {
            return generateDefaultFileName(contentType: contentType)
        }
        
        let fileName = urlObj.lastPathComponent
        
        // إذا كان اسم الملف فارغاً أو غير صالح
        if fileName.isEmpty || fileName == "/" {
            return generateDefaultFileName(contentType: contentType)
        }
        
        return fileName
    }
    
    private func extractVideoFileName(from url: String, contentType: String?) -> String {
        guard let urlObj = URL(string: url) else {
            return "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }
        
        let fileName = urlObj.lastPathComponent
        
        // إذا كان اسم الملف فارغاً أو غير صالح
        if fileName.isEmpty || fileName == "/" {
            return "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }
        
        // إضافة امتداد الفيديو إذا لم يكن موجوداً
        if !fileName.contains(".") {
            return "\(fileName).mp4"
        }
        
        return fileName
    }
    
    private func generateDefaultFileName(contentType: String?) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        if let contentType = contentType {
            switch contentType {
            case let type where type.contains("video"):
                return "video_\(timestamp).mp4"
            case let type where type.contains("audio"):
                return "audio_\(timestamp).mp3"
            case let type where type.contains("image"):
                return "image_\(timestamp).jpg"
            case let type where type.contains("application/pdf"):
                return "document_\(timestamp).pdf"
            default:
                return "download_\(timestamp).bin"
            }
        }
        
        return "download_\(timestamp).bin"
    }
    
    private func generateVideoFileName(from url: String, pageTitle: String, videoType: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // تنظيف عنوان الصفحة
        let cleanTitle = sanitizeFileName(pageTitle)
        
        // تحديد امتداد الملف حسب نوع الفيديو
        let fileExtension: String
        switch videoType.lowercased() {
        case "hls":
            fileExtension = "mp4"
        case "dash":
            fileExtension = "mp4"
        case "youtube":
            fileExtension = "mp4"
        case "mp4":
            fileExtension = "mp4"
        case "webm":
            fileExtension = "webm"
        default:
            fileExtension = "mp4"
        }
        
        // إذا كان العنوان فارغاً، استخدم URL
        if cleanTitle.isEmpty {
            if let urlObj = URL(string: url) {
                let urlFileName = urlObj.lastPathComponent
                if !urlFileName.isEmpty && urlFileName != "/" {
                    return urlFileName
                }
            }
            return "video_\(timestamp).\(fileExtension)"
        }
        
        return "\(cleanTitle)_\(timestamp).\(fileExtension)"
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fileName.components(separatedBy: invalidChars).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func determineFileType(from url: String, contentType: String?) -> DownloadItem.FileType {
        let urlLower = url.lowercased()
        
        // فحص امتداد الملف
        if urlLower.contains(".mp4") || urlLower.contains(".avi") || urlLower.contains(".mkv") || 
           urlLower.contains(".mov") || urlLower.contains(".wmv") || urlLower.contains(".webm") {
            return .video
        }
        
        if urlLower.contains(".mp3") || urlLower.contains(".wav") || urlLower.contains(".flac") || 
           urlLower.contains(".aac") || urlLower.contains(".m4a") || urlLower.contains(".ogg") {
            return .audio
        }
        
        if urlLower.contains(".pdf") || urlLower.contains(".doc") || urlLower.contains(".docx") || 
           urlLower.contains(".xls") || urlLower.contains(".xlsx") || urlLower.contains(".ppt") || 
           urlLower.contains(".pptx") || urlLower.contains(".txt") {
            return .document
        }
        
        if urlLower.contains(".exe") || urlLower.contains(".dmg") || urlLower.contains(".pkg") || 
           urlLower.contains(".deb") || urlLower.contains(".rpm") || urlLower.contains(".msi") || 
           urlLower.contains(".apk") || urlLower.contains(".ipa") {
            return .executable
        }
        
        if urlLower.contains(".zip") || urlLower.contains(".rar") || urlLower.contains(".7z") || 
           urlLower.contains(".tar") || urlLower.contains(".gz") || urlLower.contains(".bz2") {
            return .compressed
        }
        
        // فحص Content-Type
        if let contentType = contentType?.lowercased() {
            if contentType.contains("video") {
                return .video
            }
            if contentType.contains("audio") {
                return .audio
            }
            if contentType.contains("image") {
                return .image
            }
            if contentType.contains("application/pdf") {
                return .document
            }
        }
        
        return .other
    }
}

// MARK: - XPC Service Manager
class SafarGetXPCServiceManager: NSObject {
    static let shared = SafarGetXPCServiceManager()
    
    private var service: SafarGetXPCService?
    
    private override init() {
        super.init()
    }
    
    func startService(viewModel: DownloadManagerViewModel) {
        print("🚀 Starting SafarGet XPC Service...")
        
        service = SafarGetXPCService()
        service?.setViewModel(viewModel)
        
        print("✅ SafarGet XPC Service started successfully")
    }
    
    func stopService() {
        service = nil
        print("🛑 SafarGet XPC Service stopped")
    }
    
    func getService() -> SafarGetXPCService? {
        return service
    }
} 