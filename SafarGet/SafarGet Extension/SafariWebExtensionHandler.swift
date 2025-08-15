import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        print("Received message: \(messageName)")
        
        switch messageName {
        case "downloadFile":
            handleDownloadRequest(userInfo: userInfo)
        case "youtubeDownload":
            handleYouTubeDownloadRequest(userInfo: userInfo)
        case "getDownloadStatus":
            // يمكن إضافة ميزة للتحقق من حالة التحميل لاحقاً
            break
        default:
            print("Unknown message: \(messageName)")
        }
        }
    
    // معالجة أوامر Context Menu
    override func contextMenuItemSelected(withCommand command: String, in page: SFSafariPage, userInfo: [String : Any]? = nil) {
        print("Context menu selected: \(command)")
        
        if command == "downloadWithSafarGet" {
            // إرسال رسالة إلى content script
            page.dispatchMessageToScript(withName: "downloadFromContextMenu", userInfo: nil)
        }
    }
    
    private func handleDownloadRequest(userInfo: [String: Any]?) {
        guard let userInfo = userInfo,
              let urlString = userInfo["url"] as? String,
              let fileName = userInfo["fileName"] as? String else {
            print("Invalid download request data")
            return
        }
        
        print("🚀 Smart Download Request:")
        print("   URL: \(urlString)")
        print("   FileName: \(fileName)")
        print("   Detection Method: \(userInfo["detectionMethod"] as? String ?? "unknown")")
        
        // تحليل إضافي للبيانات الذكية
        if let urlPattern = userInfo["urlPattern"] as? [String: Any] {
            print("   URL Pattern Analysis:")
            print("     Has File Extension: \(urlPattern["hasFileExtension"] as? Bool ?? false)")
            print("     Has Filename Param: \(urlPattern["hasFilenameParam"] as? Bool ?? false)")
            print("     Has Suspicious Path: \(urlPattern["hasSuspiciousPath"] as? Bool ?? false)")
        }
        
        if let pageContent = userInfo["pageContent"] as? [String: Any] {
            print("   Page Content Analysis:")
            print("     Title: \(pageContent["title"] as? String ?? "unknown")")
            print("     Body Length: \(pageContent["bodyLength"] as? Int ?? 0)")
            print("     Is Blank Page: \(pageContent["isBlankPage"] as? Bool ?? false)")
        }
        
        // إرسال البيانات إلى التطبيق الرئيسي عبر App Groups مع المعلومات الذكية
        if let sharedDefaults = UserDefaults(suiteName: "group.com.safarget.downloads") {
            var downloads = sharedDefaults.array(forKey: "pendingDownloads") as? [[String: Any]] ?? []
            
            let downloadInfo: [String: Any] = [
                "url": urlString,
                "fileName": fileName,
                "timestamp": Date().timeIntervalSince1970,
                "source": "safari_smart_analysis",
                "detectionMethod": userInfo["detectionMethod"] as? String ?? "smart_analysis",
                "pageUrl": userInfo["pageUrl"] as? String ?? "",
                "userAgent": userInfo["userAgent"] as? String ?? "",
                // معلومات إضافية للتحليل الذكي
                "urlPattern": userInfo["urlPattern"] as? [String: Any] ?? [:],
                "contentType": userInfo["contentType"] as? String ?? "",
                "hasRedirects": userInfo["hasRedirects"] as? Bool ?? false,
                "isIntermediatePage": userInfo["isIntermediatePage"] as? Bool ?? false,
                "pageContent": userInfo["pageContent"] as? [String: Any] ?? [:],
                "smartAnalysisVersion": "1.0" as Any
            ]
            
            downloads.append(downloadInfo)
            sharedDefaults.set(downloads, forKey: "pendingDownloads")
            sharedDefaults.synchronize()
            
            // إرسال إشعار للتطبيق الرئيسي
            sendNotificationToMainApp(downloadInfo: downloadInfo)
        }
    }
    
    // MARK: - Quality Translation Function
    private func translateQualityToYtDlpFormat(_ quality: String) -> String {
        let qualityLower = quality.lowercased()
        
        switch qualityLower {
        case "4k", "2160p", "uhd":
            return "bestvideo[height<=2160][ext=mp4]+bestaudio[ext=m4a]/best[height<=2160][ext=mp4]/best"
        case "1080p", "full hd", "fhd":
            return "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best"
        case "720p", "hd":
            return "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best"
        case "480p":
            return "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best"
        case "360p":
            return "bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/best[height<=360][ext=mp4]/best"
        case "240p":
            return "bestvideo[height<=240][ext=mp4]+bestaudio[ext=m4a]/best[height<=240][ext=mp4]/best"
        case "144p":
            return "bestvideo[height<=144][ext=mp4]+bestaudio[ext=m4a]/best[height<=144][ext=mp4]/best"
        case "best", "أفضل جودة", "meilleure qualité":
            return "best[ext=mp4]/best"
        case "worst", "أسوأ جودة", "pire qualité":
            return "worst[ext=mp4]/worst"
        default:
            // إذا كانت الجودة غير معروفة، استخدم الجودة المحددة كما هي
            return quality
        }
    }
    
    private func handleYouTubeDownloadRequest(userInfo: [String: Any]?) {
        guard let userInfo = userInfo,
              let url = userInfo["url"] as? String,
              let title = userInfo["title"] as? String,
              let quality = userInfo["quality"] as? String else {
            print("Invalid YouTube download request data")
            return
        }
        
        let videoId = userInfo["videoId"] as? String ?? ""
        let qualityLabel = userInfo["qualityLabel"] as? String ?? "Best Quality"
        let audioOnly = userInfo["audioOnly"] as? Bool ?? false
        let type = userInfo["type"] as? String ?? "video"
        
        // تحسين الجودة المختارة
        let optimizedQuality = translateQualityToYtDlpFormat(quality)
        print("🎬 Quality optimization in Safari Extension: '\(quality)' -> '\(optimizedQuality)'")
        
        print("📥 YouTube Download Request:")
        print("   URL: \(url)")
        print("   Title: \(title)")
        print("   Quality: \(quality)")
        print("   Optimized Quality: \(optimizedQuality)")
        print("   Type: \(type)")
        print("   Audio Only: \(audioOnly)")
        
        // إعداد البيانات للتطبيق
        let downloadInfo: [String: Any] = [
            "url": url,
            "fileName": "\(title).mp4",
            "title": title,
            "quality": optimizedQuality,
            "qualityLabel": qualityLabel,
            "videoId": videoId,
            "audioOnly": audioOnly,
            "type": type,
            "isYouTube": true,
            "timestamp": Date().timeIntervalSince1970,
            "source": "safari_youtube"
        ]
        
        // حفظ في App Groups
        if let sharedDefaults = UserDefaults(suiteName: "group.com.safarget.downloads") {
            var downloads = sharedDefaults.array(forKey: "pendingDownloads") as? [[String: Any]] ?? []
            downloads.append(downloadInfo)
            sharedDefaults.set(downloads, forKey: "pendingDownloads")
            sharedDefaults.synchronize()
        }
        
        // فتح التطبيق مع معلومات YouTube
        openAppWithYouTubeDownload(downloadInfo: downloadInfo)
    }
    
    private func openAppWithYouTubeDownload(downloadInfo: [String: Any]) {
        guard let url = downloadInfo["url"] as? String,
              let title = downloadInfo["title"] as? String,
              let quality = downloadInfo["quality"] as? String else { return }
        
        // تحسين الجودة المختارة
        let optimizedQuality = translateQualityToYtDlpFormat(quality)
        
        let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedQuality = optimizedQuality.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let safargoURL = URL(string: "safarget://youtube?url=\(encodedURL)&title=\(encodedTitle)&quality=\(encodedQuality)") {
            NSWorkspace.shared.open(safargoURL)
        }
    }
    
    private func sendNotificationToMainApp(downloadInfo: [String: Any]) {
        // حفظ في App Groups
        if let sharedDefaults = UserDefaults(suiteName: "group.com.safarget.downloads") {
            var downloads = sharedDefaults.array(forKey: "pendingDownloads") as? [[String: Any]] ?? []
            downloads.append(downloadInfo)
            sharedDefaults.set(downloads, forKey: "pendingDownloads")
            sharedDefaults.synchronize()
        }
        
        // استخدام URL Scheme لفتح التطبيق
        if let url = downloadInfo["url"] as? String,
           let fileName = downloadInfo["fileName"] as? String {
            let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            if let safargoURL = URL(string: "safarget://download?url=\(encodedURL)&fileName=\(encodedFileName)") {
                // فتح التطبيق
                NSWorkspace.shared.open(safargoURL)
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        validationHandler(true, "")
    }
    
    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
}
