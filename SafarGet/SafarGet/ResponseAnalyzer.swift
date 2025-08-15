import Foundation
import SwiftUI

// MARK: - Response Analyzer - نظام تحليل ذكي للـ HTTP Responses
class ResponseAnalyzer {
    
    // MARK: - Properties
    private let response: URLResponse
    private var redirectChain: [URL] = []
    private var originalRequest: URLRequest?
    private var finalDestination: URL?
    private var originalFilename: String?
    private var detectedMimeType: String?
    private var isActualFile: Bool = false
    
    // توقيعات الملفات المعروفة (Magic Numbers)
    private let fileSignatures: [String: [UInt8]] = [
        "zip": [0x50, 0x4B, 0x03, 0x04],  // ZIP signature
        "pdf": [0x25, 0x50, 0x44, 0x46],  // PDF signature
        "apk": [0x50, 0x4B, 0x03, 0x04],  // APK (same as ZIP)
        "exe": [0x4D, 0x5A],              // Windows executable
        "jpg": [0xFF, 0xD8, 0xFF],        // JPEG
        "png": [0x89, 0x50, 0x4E, 0x47],  // PNG
        "gif": [0x47, 0x49, 0x46],        // GIF
        "mp4": [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70], // MP4
        "mp3": [0x49, 0x44, 0x33],        // MP3
        "rar": [0x52, 0x61, 0x72, 0x21],  // RAR
        "7z": [0x37, 0x7A, 0xBC, 0xAF],   // 7-Zip
        "tar": [0x75, 0x73, 0x74, 0x61, 0x72], // TAR
        "gz": [0x1F, 0x8B],               // GZIP
        "dmg": [0x78, 0x01],              // DMG
        "iso": [0x43, 0x44, 0x30, 0x30, 0x31], // ISO
        "html": [0x3C, 0x21, 0x44, 0x4F, 0x43, 0x54, 0x59, 0x50, 0x45], // HTML
        "xml": [0x3C, 0x3F, 0x78, 0x6D, 0x6C] // XML
    ]
    
    // أنواع MIME القابلة للتحميل
    private let downloadableMimeTypes = [
        "application/octet-stream",
        "application/zip",
        "application/x-zip-compressed",
        "application/pdf",
        "application/x-rar-compressed",
        "application/x-7z-compressed",
        "application/x-tar",
        "application/x-gzip",
        "application/x-bzip2",
        "video/",
        "audio/",
        "image/",
        "application/vnd.android.package-archive",
        "application/x-apple-diskimage",
        "application/x-debian-package",
        "application/x-redhat-package-manager",
        "application/x-msdownload",
        "application/x-executable",
        "application/x-shockwave-flash",
        "application/x-flash-video"
    ]
    
    // MARK: - Initialization
    init(response: URLResponse) {
        self.response = response
        self.finalDestination = response.url
    }
    
    // MARK: - Public Methods
    
    /// تحليل متقدم للـ response وتحديد ما إذا كان ملف قابل للتحميل
    func performPreflightCheck(completion: @escaping (Bool) -> Void) {
        print("🔍 ResponseAnalyzer: Starting preflight check for URL: \(response.url?.absoluteString ?? "unknown")")
        
        // المرحلة 1: فحص URL Pattern
        guard let url = response.url else {
            completion(false)
            return
        }
        
        if !isValidURLPattern(url) {
            print("❌ ResponseAnalyzer: Invalid URL pattern")
            completion(false)
            return
        }
        
        // المرحلة 2: تحليل Headers
        analyzeHeaders { [weak self] shouldContinue in
            guard let _ = self else { return }
            
            if !shouldContinue {
                print("❌ ResponseAnalyzer: Headers analysis failed")
                completion(false)
                return
            }
            
            // المرحلة 3: تحميل جزئي للتحليل العميق
            self?.performDeepAnalysis { [weak self] isDownloadable in
                guard self != nil else { return }
                
                print("✅ ResponseAnalyzer: Deep analysis completed - Downloadable: \(isDownloadable)")
                completion(isDownloadable)
            }
        }
    }
    
    /// استخراج معلومات الملف من الـ response
    func extractFileInfo() -> FileInfo {
        let url = response.url?.absoluteString ?? ""
        let fileName = extractFileName()
        let mimeType = detectedMimeType ?? response.mimeType ?? "application/octet-stream"
        let fileSizeString = (response as? HTTPURLResponse)?.allHeaderFields["Content-Length"] as? String
        let fileSize = Int64(fileSizeString ?? "0") ?? 0
        
        return FileInfo(
            url: url,
            fileName: fileName,
            mimeType: mimeType,
            fileSize: fileSize,
            isActualFile: isActualFile,
            redirectChain: redirectChain
        )
    }
    
    // MARK: - Private Methods
    
    /// فحص صحة نمط URL
    private func isValidURLPattern(_ url: URL) -> Bool {
        // فحص Scheme
        guard let scheme = url.scheme, ["http", "https", "ftp", "ftps"].contains(scheme.lowercased()) else {
            return false
        }
        
        // فحص Host
        guard url.host != nil else { return false }
        
        // فحص امتدادات الملفات المعروفة
        let fileExtensions = [
            ".zip", ".rar", ".7z", ".tar", ".gz", ".exe", ".dmg", ".pkg", ".deb", ".rpm",
            ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".mp4", ".avi", ".mkv", ".mov", ".wmv",
            ".mp3", ".wav", ".flac", ".aac", ".m4a", ".jpg", ".jpeg", ".png", ".gif", ".bmp",
            ".iso", ".img", ".bin", ".ipsw", ".apk", ".ipa"
        ]
        
        let path = url.path.lowercased()
        return fileExtensions.contains { path.hasSuffix($0) } || shouldMonitorForContentDisposition(url)
    }
    
    /// تحليل Headers
    private func analyzeHeaders(completion: @escaping (Bool) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(false)
            return
        }
        
        print("🔍 ResponseAnalyzer: Analyzing headers...")
        
        // فحص Content-Type
        if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
            detectedMimeType = contentType
            print("📋 ResponseAnalyzer: Content-Type: \(contentType)")
            
            // فحص إذا كان HTML
            if contentType.lowercased().contains("text/html") {
                print("❌ ResponseAnalyzer: HTML content detected")
                completion(false)
                return
            }
        }
        
        // فحص Content-Disposition
        if let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
            print("📋 ResponseAnalyzer: Content-Disposition: \(contentDisposition)")
            
            if contentDisposition.lowercased().contains("attachment") {
                originalFilename = extractFileNameFromContentDisposition(contentDisposition)
                isActualFile = true
                print("✅ ResponseAnalyzer: Attachment detected with filename: \(originalFilename ?? "unknown")")
                completion(true)
                return
            }
        }
        
        // فحص Content-Length
        if let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String,
           let size = Int64(contentLength) {
            print("📋 ResponseAnalyzer: Content-Length: \(size)")
            
            // إذا كان الملف كبير جداً، فهو على الأرجح ملف
            if size > 1024 * 1024 { // أكبر من 1MB
                isActualFile = true
                print("✅ ResponseAnalyzer: Large file detected (\(size) bytes)")
                completion(true)
                return
            }
        }
        
        // فحص Accept-Ranges
        if let acceptRanges = httpResponse.allHeaderFields["Accept-Ranges"] as? String {
            print("📋 ResponseAnalyzer: Accept-Ranges: \(acceptRanges)")
            if acceptRanges.lowercased() == "bytes" {
                isActualFile = true
                print("✅ ResponseAnalyzer: Accept-Ranges: bytes detected")
                completion(true)
                return
            }
        }
        
        // إذا وصلنا هنا، نحتاج تحليل أعمق
        completion(true)
    }
    
    /// تحليل عميق للمحتوى
    private func performDeepAnalysis(completion: @escaping (Bool) -> Void) {
        guard let url = response.url else {
            completion(false)
            return
        }
        
        print("🔍 ResponseAnalyzer: Performing deep analysis...")
        
        // تحميل أول 8KB من الملف للتحليل
        var request = URLRequest(url: url)
        request.setValue("bytes=0-8191", forHTTPHeaderField: "Range")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ ResponseAnalyzer: Deep analysis error: \(error)")
                completion(false)
                return
            }
            
            guard let data = data, data.count > 0 else {
                print("❌ ResponseAnalyzer: No data received for deep analysis")
                completion(false)
                return
            }
            
            // فحص Magic Numbers
            let isActualFile = self.checkMagicNumbers(data)
            
            // فحص المحتوى النصي
            let isTextContent = self.checkTextContent(data)
            
            if isActualFile && !isTextContent {
                self.isActualFile = true
                print("✅ ResponseAnalyzer: Actual file detected via magic numbers")
                completion(true)
            } else if isTextContent {
                print("❌ ResponseAnalyzer: Text content detected (likely HTML/JavaScript)")
                completion(false)
            } else {
                // إذا لم نتمكن من تحديد النوع، نفترض أنه ملف
                self.isActualFile = true
                print("✅ ResponseAnalyzer: Assuming file based on analysis")
                completion(true)
            }
        }.resume()
    }
    
    /// فحص Magic Numbers
    private func checkMagicNumbers(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        
        let bytes = Array(data.prefix(8))
        
        for (fileType, signature) in fileSignatures {
            if Array(bytes.prefix(signature.count)) == Array(signature) {
                print("✅ ResponseAnalyzer: Magic number match for \(fileType)")
                return true
            }
        }
        
        return false
    }
    
    /// فحص المحتوى النصي
    private func checkTextContent(_ data: Data) -> Bool {
        guard let string = String(data: data, encoding: .utf8) else { return false }
        
        let lowercased = string.lowercased()
        
        // فحص HTML tags
        if lowercased.contains("<html") || lowercased.contains("<!doctype") {
            print("❌ ResponseAnalyzer: HTML content detected")
            return true
        }
        
        // فحص JavaScript
        if lowercased.contains("<script") || lowercased.contains("function") {
            print("❌ ResponseAnalyzer: JavaScript content detected")
            return true
        }
        
        // فحص XML
        if lowercased.contains("<?xml") || lowercased.contains("<xml") {
            print("❌ ResponseAnalyzer: XML content detected")
            return true
        }
        
        return false
    }
    
    /// استخراج اسم الملف من Content-Disposition
    private func extractFileNameFromContentDisposition(_ contentDisposition: String) -> String? {
        // البحث عن filename في Content-Disposition header
        let fileNameMatch = contentDisposition.range(of: "filename[^;=\n]*=((['\"]).*?\\2|[^;\n]*)", options: .regularExpression)
        
        if let match = fileNameMatch {
            var fileName = String(contentDisposition[match])
                .replacingOccurrences(of: "filename=", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
            
            // فك ترميز URL encoding
            if let decoded = fileName.removingPercentEncoding {
                fileName = decoded
            }
            
            return fileName
        }
        
        // البحث عن filename* (RFC 5987)
        let fileNameStarMatch = contentDisposition.range(of: "filename\\*[^;=\n]*=([^;\n]*)", options: .regularExpression)
        
        if let match = fileNameStarMatch {
            var fileName = String(contentDisposition[match])
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
        
        return nil
    }
    
    /// استخراج اسم الملف النهائي
    private func extractFileName() -> String {
        // الأولوية للاسم من Content-Disposition
        if let dispositionName = originalFilename {
            return dispositionName
        }
        
        // ثم من URL
        if let url = response.url {
            let fileName = url.lastPathComponent
            if !fileName.isEmpty && fileName != "/" {
                return fileName
            }
        }
        
        // ثم من MIME type
        if let mimeType = detectedMimeType {
            let fileExtension = getExtensionFromMimeType(mimeType)
            return "download.\(fileExtension)"
        }
        
        return "download"
    }
    
    /// الحصول على امتداد الملف من MIME type
    private func getExtensionFromMimeType(_ mimeType: String) -> String {
        let mimeToExtension: [String: String] = [
            "application/zip": "zip",
            "application/x-zip-compressed": "zip",
            "application/pdf": "pdf",
            "application/x-rar-compressed": "rar",
            "application/x-7z-compressed": "7z",
            "application/x-tar": "tar",
            "application/x-gzip": "gz",
            "video/mp4": "mp4",
            "video/avi": "avi",
            "video/mkv": "mkv",
            "video/mov": "mov",
            "audio/mp3": "mp3",
            "audio/wav": "wav",
            "audio/flac": "flac",
            "image/jpeg": "jpg",
            "image/png": "png",
            "image/gif": "gif",
            "application/vnd.android.package-archive": "apk",
            "application/x-apple-diskimage": "dmg",
            "application/x-msdownload": "exe"
        ]
        
        return mimeToExtension[mimeType.lowercased()] ?? "bin"
    }
    
    /// التحقق من المواقع التي تحتاج مراقبة Content-Disposition
    private func shouldMonitorForContentDisposition(_ url: URL) -> Bool {
        let monitoredDomains = [
            "projectinfinity-x.com",
            "mirror.tejas101k.workers.dev",
            "github.com",
            "gitlab.com",
            "sourceforge.net",
            "mediafire.com",
            "mega.nz",
            "dropbox.com",
            "drive.google.com"
        ]
        
        return monitoredDomains.contains { url.host?.contains($0) == true }
    }
}

// MARK: - File Info Model
struct FileInfo {
    let url: String
    let fileName: String
    let mimeType: String
    let fileSize: Int64
    let isActualFile: Bool
    let redirectChain: [URL]
    
    var isDownloadable: Bool {
        return isActualFile && !fileName.isEmpty
    }
}
