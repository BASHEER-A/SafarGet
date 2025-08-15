import Foundation
import AppKit

// MARK: - Native Messaging Host
class SafarGetNativeMessagingHost {
    private var viewModel: DownloadManagerViewModel?
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    
    init(viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        setupPipes()
    }
    
    private func setupPipes() {
        // إعداد stdin/stdout للتواصل مع Chrome
        // لا يمكن تعيين FileHandle.standardInput مباشرة، سنستخدم الطريقة الصحيحة
        startReading()
    }
    
    private func startReading() {
        // قراءة من stdin مباشرة
        let inputHandle = FileHandle.standardInput
        inputHandle.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            
            let data = handle.availableData
            // إيقاف المعالج عند EOF لمنع حلقة CPU عالية عندما لا يكون هناك إدخال
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self.handleMessage(data)
        }
    }
    
    private func handleMessage(_ data: Data) {
        do {
            guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                sendError("Invalid JSON message")
                return
            }
            
            print("📨 Received message: \(message)")
            
            guard let type = message["type"] as? String else {
                sendError("Missing message type")
                return
            }
            
            switch type {
            case "download":
                handleDownloadRequest(message)
            case "videoStream":
                handleVideoStreamRequest(message)
            case "videoCapture":
                handleVideoCaptureRequest(message)
            case "ping":
                sendResponse(["type": "pong", "status": "ok"])
            default:
                sendError("Unknown message type: \(type)")
            }
            
        } catch {
            sendError("Error parsing message: \(error.localizedDescription)")
        }
    }
    
    private func handleDownloadRequest(_ message: [String: Any]) {
        guard let url = message["url"] as? String else {
            sendError("Missing URL in download request")
            return
        }
        
        let contentType = message["contentType"] as? String
        let fileName = message["fileName"] as? String ?? extractFileName(from: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                self?.sendError("ViewModel not available")
                return
            }
            
            let fileType = self.determineFileType(from: url, contentType: contentType)
            
            viewModel.addDownloadEnhanced(
                url: url,
                fileName: fileName,
                fileType: fileType,
                savePath: "~/Downloads",
                chunks: 16,
                cookiesPath: nil
            )
            
            self.sendResponse([
                "type": "downloadAccepted",
                "url": url,
                "fileName": fileName,
                "status": "success"
            ])
        }
    }
    
    private func handleVideoStreamRequest(_ message: [String: Any]) {
        guard let url = message["url"] as? String else {
            sendError("Missing URL in video stream request")
            return
        }
        
        let fileName = message["fileName"] as? String ?? extractVideoFileName(from: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                self?.sendError("ViewModel not available")
                return
            }
            
            viewModel.addDownloadEnhanced(
                url: url,
                fileName: fileName,
                fileType: .video,
                savePath: "~/Downloads",
                chunks: 16,
                cookiesPath: nil
            )
            
            self.sendResponse([
                "type": "videoStreamAccepted",
                "url": url,
                "fileName": fileName,
                "status": "success"
            ])
        }
    }
    
    private func handleVideoCaptureRequest(_ message: [String: Any]) {
        guard let videoData = message["data"] as? [String: Any] else {
            sendError("Missing video data in capture request")
            return
        }
        
        guard let url = videoData["url"] as? String else {
            sendError("Missing URL in video capture data")
            return
        }
        
        let headers = videoData["headers"] as? [String: String] ?? [:]
        let pageTitle = videoData["pageTitle"] as? String ?? "Video"
        let videoType = videoData["videoType"] as? String ?? "unknown"
        let contentType = videoData["contentType"] as? String
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                self?.sendError("ViewModel not available")
                return
            }
            
            // إنشاء اسم ملف فريد
            let fileName = self.generateVideoFileName(from: url, pageTitle: pageTitle, videoType: videoType)
            
            // إضافة التحميل مع headers مخصصة
            viewModel.addVideoDownloadWithHeaders(
                url: url,
                fileName: fileName,
                headers: headers,
                pageTitle: pageTitle,
                videoType: videoType,
                contentType: contentType
            )
            
            self.sendResponse([
                "type": "videoCaptureAccepted",
                "url": url,
                "fileName": fileName,
                "status": "success"
            ])
        }
    }
    
    private func sendResponse(_ response: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            let length = UInt32(data.count)
            
            // إرسال طول الرسالة أولاً (4 bytes)
            let lengthBytes = withUnsafeBytes(of: length.littleEndian) { Data($0) }
            outputPipe.fileHandleForWriting.write(lengthBytes)
            
            // إرسال الرسالة
            outputPipe.fileHandleForWriting.write(data)
            
        } catch {
            sendError("Error sending response: \(error.localizedDescription)")
        }
    }
    
    private func sendError(_ message: String) {
        sendResponse([
            "type": "error",
            "message": message
        ])
    }
    
    // MARK: - Helper Methods
    
    private func extractFileName(from url: String) -> String {
        guard let urlObj = URL(string: url) else {
            return "download_\(Int(Date().timeIntervalSince1970)).bin"
        }
        
        let fileName = urlObj.lastPathComponent
        
        if fileName.isEmpty || fileName == "/" {
            return "download_\(Int(Date().timeIntervalSince1970)).bin"
        }
        
        return fileName
    }
    
    private func extractVideoFileName(from url: String) -> String {
        guard let urlObj = URL(string: url) else {
            return "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }
        
        let fileName = urlObj.lastPathComponent
        
        if fileName.isEmpty || fileName == "/" {
            return "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }
        
        if !fileName.contains(".") {
            return "\(fileName).mp4"
        }
        
        return fileName
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

// MARK: - Native Messaging Host Manager
class SafarGetNativeMessagingHostManager {
    static let shared = SafarGetNativeMessagingHostManager()
    
    private var host: SafarGetNativeMessagingHost?
    
    private init() {}
    
    func startHost(viewModel: DownloadManagerViewModel) {
        print("🚀 Starting SafarGet Native Messaging Host...")
        
        host = SafarGetNativeMessagingHost(viewModel: viewModel)
        
        print("✅ SafarGet Native Messaging Host started successfully")
    }
    
    func stopHost() {
        host = nil
        print("🛑 SafarGet Native Messaging Host stopped")
    }
} 