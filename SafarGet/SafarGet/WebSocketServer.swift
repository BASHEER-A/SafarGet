import Foundation
import Network
import AppKit

// MARK: - WebSocket Server
class SafarGetWebSocketServer {
    private var listener: NWListener?
    private var connections: Set<WebSocketConnection> = []
    private weak var viewModel: DownloadManagerViewModel?
    private let queue = DispatchQueue(label: "com.SafarGet.websocket", qos: .background)
    
    init(viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
    }
    
    func start(port: UInt16 = 8765) {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        // إعداد WebSocket
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ WebSocket server listening on port \(port)")
                case .failed(let error):
                    print("❌ WebSocket server failed: \(error)")
                    // Attempt to restart only if the error is recoverable, or after a delay
                    // For now, just log and don't auto-restart immediately to avoid loops
                    // self?.restart() // Removed immediate restart to prevent loops
                case .cancelled:
                    print("ℹ️ WebSocket server cancelled")
                default:
                    break
                }
            }
            
            listener?.start(queue: queue)
        } catch {
            print("❌ Failed to start WebSocket server: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        connections.forEach { $0.close() }
        connections.removeAll()
        print("🛑 WebSocket server stopped")
    }
    
    // Removed restart() to prevent infinite loops on persistent errors
    // private func restart() {
    //     stop()
    //     DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
    //         self?.start()
    //     }
    // }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let wsConnection = WebSocketConnection(connection: connection, server: self)
        connections.insert(wsConnection)
        wsConnection.start()
        print("🔗 New WebSocket connection established (total connections: \(connections.count))")
    }
    
    func handleMessage(_ message: Data, from connection: WebSocketConnection) {
        guard let messageString = String(data: message, encoding: .utf8) else {
            print("❌ Failed to decode message as string")
            return
        }
        
        print("📨 Received message: \(messageString)")
        
        do {
            if let json = try JSONSerialization.jsonObject(with: message) as? [String: Any],
               let type = json["type"] as? String {
                
                print("📋 Message type: \(type)")
                
                switch type {
                case "download":
                    handleDownloadRequest(json, from: connection)
                case "openApp":
                    handleOpenAppRequest(from: connection)
                case "extractQualities":
                    print("🎬 Handling extractQualities request")
                    // استخدام الطريقة المبسطة السريعة مع قائمة محسّنة
                    handleExtractQualitiesOptimized(json, from: connection)
                case "downloadYouTube":
                    handleYouTubeDownload(json, from: connection)
                case "videoCapture":
                    handleVideoCaptureRequest(json, from: connection)
                case "ping":
                    connection.send(data: try JSONSerialization.data(withJSONObject: ["type": "pong"]))
                default:
                    print("❓ Unknown message type: \(type)")
                }
            }
        } catch {
            print("❌ Error parsing message: \(error)")
            connection.send(data: createErrorResponse("Error parsing message: \(error.localizedDescription)"))
        }
    }
    
    private func handleDownloadRequest(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let url = data["url"] as? String,
              let fileName = data["fileName"] as? String else {
            connection.send(data: createErrorResponse("Invalid download data"))
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let _ = self.viewModel else { 
                connection.send(data: self?.createErrorResponse("ViewModel not available") ?? Data())
                return 
            }
            
            // إرسال إشعار إلى ViewModel لمعالجة طلب التحميل
            NotificationCenter.default.post(
                name: .newDownload,
                object: nil,
                userInfo: [
                    "url": url,
                    "fileName": fileName,
                    "source": "websocket"
                ]
            )
            
            // إرسال رد نجاح
            let response: [String: Any] = [
                "type": "downloadAccepted",
                "url": url,
                "fileName": fileName,
                "status": "processing_by_app"
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                connection.send(data: responseData)
            }
        }
    }
    
    private func handleOpenAppRequest(from connection: WebSocketConnection) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            
            let response: [String: Any] = [
                "type": "appOpened",
                "status": "success"
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                connection.send(data: responseData)
            }
        }
    }
    
    // MARK: - YouTube Quality Optimization
    private func optimizeYouTubeQuality(_ quality: String) -> String {
        let q = quality.lowercased()
        func fmt(_ h: Int) -> String {
            return "bestvideo[height<=\(h)][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]"
        }
        switch q {
        case "4k", "2160p", "uhd": return fmt(2160)
        case "1440p", "2k": return fmt(1440)
        case "1080p", "full hd", "fhd": return fmt(1080)
        case "720p", "hd": return fmt(720)
        case "480p": return fmt(480)
        case "360p": return fmt(360)
        case "240p": return fmt(240)
        case "144p": return fmt(144)
        case "best", "أفضل جودة", "meilleure qualité":
            return "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best"
        case "worst", "أسوأ جودة", "pire qualité":
            return "worst"
        default:
            return quality
        }
    }
    
    // طريقة محسّنة لاستخراج الجودات بشكل سريع
    private func handleExtractQualitiesOptimized(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let url = data["url"] as? String,
              let requestId = data["requestId"] as? String else {
            connection.send(data: createErrorResponse("Invalid request data"))
            return
        }
        
        print("🎬 Extracting qualities (optimized) for: \(url)")
        
        // إرسال رد فوري
        let ackResponse: [String: Any] = [
            "type": "extractionStarted",
            "requestId": requestId,
            "status": "processing"
        ]
        if let ackData = try? JSONSerialization.data(withJSONObject: ackResponse) {
            connection.send(data: ackData)
        }
        
        // قائمة محسّنة من الجودات الشائعة
        DispatchQueue.global(qos: .userInitiated).async {
            let standardQualities: [[String: Any]] = [
                [
                    "format_id": "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best",
                    "resolution": "Best Quality (up to 1080p)",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestvideo[height=1080][ext=mp4]+bestaudio[ext=m4a]/best[height=1080][ext=mp4]/22",
                    "resolution": "1080p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestvideo[height=720][ext=mp4]+bestaudio[ext=m4a]/best[height=720]",
                    "resolution": "720p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestvideo[height=480][ext=mp4]+bestaudio[ext=m4a]/best[height=480][ext=mp4]/135+140",
                    "resolution": "480p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestvideo[height=360][ext=mp4]+bestaudio[ext=m4a]/best[height=360]",
                    "resolution": "360p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestvideo[height=240][ext=mp4]+bestaudio[ext=m4a]/best[height=240][ext=mp4]/133+140",
                    "resolution": "240p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "bestaudio[ext=m4a]/bestaudio",
                    "resolution": "Audio Only",
                    "ext": "mp3",
                    "filesize": 0,
                    "has_video": false,
                    "has_audio": true,
                    "audioOnly": true
                ]
            ]
            
            print("✅ Returning \(standardQualities.count) optimized qualities")
            
            let response: [String: Any] = [
                "type": "youtubeQualities",
                "requestId": requestId,
                "qualities": standardQualities
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                DispatchQueue.main.async {
                    connection.send(data: responseData)
                }
            }
        }
    }
    
    // طريقة مبسطة وسريعة لاستخراج الجودات
    private func handleExtractQualitiesSimplified(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let url = data["url"] as? String,
              let requestId = data["requestId"] as? String else {
            connection.send(data: createErrorResponse("Invalid request data"))
            return
        }
        
        print("🎬 Extracting qualities (simplified) for: \(url)")
        
        // إرسال رد فوري
        let ackResponse: [String: Any] = [
            "type": "extractionStarted",
            "requestId": requestId,
            "status": "processing"
        ]
        if let ackData = try? JSONSerialization.data(withJSONObject: ackResponse) {
            connection.send(data: ackData)
        }
        
        // إرسال قائمة جودات محددة مسبقاً
        DispatchQueue.global(qos: .userInitiated).async {
            // قائمة الجودات الشائعة في YouTube
            let standardQualities: [[String: Any]] = [
                [
                    "format_id": "best",
                    "resolution": "Best Quality",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "137+140",
                    "resolution": "1080p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "136+140",
                    "resolution": "720p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "135+140",
                    "resolution": "480p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ],
                [
                    "format_id": "134+140",
                    "resolution": "360p",
                    "ext": "mp4",
                    "filesize": 0,
                    "has_video": true,
                    "has_audio": true
                ]
            ]
            
            print("✅ Returning \(standardQualities.count) standard qualities")
            
            let response: [String: Any] = [
                "type": "youtubeQualities",
                "requestId": requestId,
                "qualities": standardQualities
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                DispatchQueue.main.async {
                    connection.send(data: responseData)
                }
            }
        }
    }
    
    private func handleExtractQualities(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let url = data["url"] as? String,
              let requestId = data["requestId"] as? String else {
            connection.send(data: createErrorResponse("Invalid request data"))
            return
        }
        
        print("🎬 Extracting qualities for: \(url)")
        
        // إرسال رد فوري للتأكيد
        let ackResponse: [String: Any] = [
            "type": "extractionStarted",
            "requestId": requestId,
            "status": "processing"
        ]
        if let ackData = try? JSONSerialization.data(withJSONObject: ackResponse) {
            connection.send(data: ackData)
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let _ = self.viewModel else { 
                self?.sendQualitiesError(connection: connection, requestId: requestId, error: "ViewModel not available")
                return 
            }
            
            let process = Process()
            
            // البحث عن yt-dlp في bundle التطبيق أولاً
            var bundledYtDlpPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) ?? ""
            if !FileManager.default.fileExists(atPath: bundledYtDlpPath) {
                // البحث في Resources مباشرة (للتوافق مع الإعداد السابق)
                bundledYtDlpPath = Bundle.main.path(forResource: "yt-dlp", ofType: nil) ?? ""
            }
            
            let possiblePaths = [
                bundledYtDlpPath,  // المسار من Bundle أولاً
                viewModel?.settings.ytDlpPath ?? "/usr/local/bin/yt-dlp",
                "/opt/homebrew/bin/yt-dlp",
                "/usr/local/bin/yt-dlp",
                "/usr/bin/yt-dlp"
            ]
            
            var finalPath: String?
            print("🔍 Searching for yt-dlp in the following paths:")
            for path in possiblePaths {
                print("  - Checking: \(path)")
                if FileManager.default.fileExists(atPath: path) {
                    print("  ✅ Found at: \(path)")
                    
                    // التحقق من أن الملف قابل للتنفيذ
                    var isExecutable = false
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                       let permissions = attributes[.posixPermissions] as? NSNumber {
                        // التحقق من وجود صلاحية التنفيذ
                        isExecutable = (permissions.intValue & 0o111) != 0
                    }
                    
                    if isExecutable {
                        finalPath = path
                        break
                    } else {
                        print("  ⚠️ File exists but is not executable. Attempting to copy to writable location.")
                        // محاولة نسخ الملف إلى موقع قابل للكتابة
                        if let supportDir = getSupportDirectory() {
                            let writablePath = (supportDir as NSString).appendingPathComponent("yt-dlp")
                            
                            if !FileManager.default.fileExists(atPath: writablePath) {
                                do {
                                    try FileManager.default.copyItem(atPath: path, toPath: writablePath)
                                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                                    print("  ✅ Copied yt-dlp to writable location: \(writablePath)")
                                    finalPath = writablePath
                                    break
                                } catch {
                                    print("  ❌ Failed to copy yt-dlp to writable location: \(error)")
                                }
                            } else {
                                // الملف موجود بالفعل، تأكد من صلاحياته
                                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: writablePath)
                                finalPath = writablePath
                                break
                            }
                        } else {
                            print("  ❌ Could not determine support directory")
                        }
                    }
                }
            }
            
            guard let executablePath = finalPath else {
                print("❌ yt-dlp not found in any of the expected paths")
                self.sendQualitiesError(connection: connection, requestId: requestId, error: "yt-dlp not found. Please ensure it's included in the app bundle or installed correctly.")
                return
            }
            
            print("✅ Using yt-dlp from: \(executablePath)")
            
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = [
                "-F",           // قائمة التنسيقات بشكل مختصر
                "--no-warnings",
                "--no-playlist",
                url
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                
                // قراءة الأخطاء أولاً
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if !errorData.isEmpty, let errorString = String(data: errorData, encoding: .utf8) {
                    print("⚠️ yt-dlp stderr: \(errorString)")
                }
                
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    print("❌ yt-dlp failed with status: \(process.terminationStatus)")
                    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                        self.sendQualitiesError(connection: connection, requestId: requestId, error: "Error: \(errorString)")
                    } else {
                        self.sendQualitiesError(connection: connection, requestId: requestId, error: "Failed to extract video information. Status: \(process.terminationStatus)")
                    }
                    return
                }
                
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    print("❌ yt-dlp failed with status: \(process.terminationStatus)")
                    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                        self.sendQualitiesError(connection: connection, requestId: requestId, error: "Error: \(errorString)")
                    } else {
                        self.sendQualitiesError(connection: connection, requestId: requestId, error: "Failed to extract video information")
                    }
                    return
                }
                
                // معالجة الناتج المنسق
                if let output = String(data: data, encoding: .utf8) {
                    print("📊 Parsing format list output")
                    
                    var qualities: [[String: Any]] = []
                    let lines = output.components(separatedBy: .newlines)
                    
                    // قاموس لتخزين أفضل جودة لكل دقة
                    var bestFormats: [String: [String: Any]] = [:]
                    
                    for line in lines {
                        // تخطي الأسطر غير المفيدة
                        if line.isEmpty || line.contains("format code") || line.contains("[info]") {
                            continue
                        }
                        
                        // البحث عن التنسيقات
                        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if components.count >= 3 {
                            let formatId = components[0]
                            
                            // استخراج معلومات الجودة
                            var resolution: String? = nil
                            var hasVideo = false
                            var hasAudio = false
                            var filesize: Int64 = 0
                            
                            // البحث عن الدقة
                            for res in ["2160p", "1440p", "1080p", "720p", "480p", "360p", "240p", "144p"] {
                                if line.contains(res) {
                                    resolution = res
                                    break
                                }
                            }
                            
                            // التحقق من وجود فيديو وصوت
                            if line.contains("video only") {
                                hasVideo = true
                                hasAudio = false
                            } else if line.contains("audio only") {
                                hasVideo = false
                                hasAudio = true
                            } else if line.contains("mp4") && !line.contains("video only") && !line.contains("audio only") {
                                // تنسيق mp4 عادي يحتوي على فيديو وصوت
                                hasVideo = true
                                hasAudio = true
                            }
                            
                            // البحث عن حجم الملف
                            if let sizeMatch = line.range(of: #"\d+\.?\d*[KMG]iB"#, options: .regularExpression) {
                                let sizeStr = String(line[sizeMatch])
                                filesize = self.parseFileSize(sizeStr)
                            }
                            
                            // إضافة التنسيقات المدمجة (فيديو + صوت)
                            if let res = resolution, hasVideo && hasAudio {
                                let quality: [String: Any] = [
                                    "format_id": formatId,
                                    "resolution": res,
                                    "ext": "mp4",
                                    "filesize": filesize,
                                    "has_video": true,
                                    "has_audio": true
                                ]
                                
                                // الاحتفاظ بأفضل جودة لكل دقة
                                if let existing = bestFormats[res] {
                                    let existingSize = existing["filesize"] as? Int64 ?? 0
                                    if filesize > existingSize {
                                        bestFormats[res] = quality
                                    }
                                } else {
                                    bestFormats[res] = quality
                                }
                            }
                        }
                    }
                    
                    // تحويل القاموس إلى مصفوفة
                    qualities = Array(bestFormats.values)
                    
                    // إذا لم نجد تنسيقات مدمجة، نبحث عن أفضل تنسيقات منفصلة
                    if qualities.isEmpty {
                        print("⚠️ No combined formats found, creating combined format IDs")
                        
                        // البحث عن أفضل تنسيقات الفيديو
                        var videoFormats: [String: String] = [:]
                        var audioFormat = "140" // m4a audio format
                        
                        for line in lines {
                            if line.contains("audio only") && line.contains("m4a") {
                                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                                if !components.isEmpty {
                                    audioFormat = components[0]
                                }
                            } else if line.contains("video only") {
                                for res in ["1080p", "720p", "480p", "360p", "240p"] {
                                    if line.contains(res) && videoFormats[res] == nil {
                                        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                                        if !components.isEmpty {
                                            videoFormats[res] = components[0]
                                        }
                                    }
                                }
                            }
                        }
                        
                        // إنشاء تنسيقات مدمجة
                        for (res, videoId) in videoFormats {
                            qualities.append([
                                "format_id": "\(videoId)+\(audioFormat)",
                                "resolution": res,
                                "ext": "mp4",
                                "filesize": 0,
                                "has_video": true,
                                "has_audio": true
                            ])
                        }
                    }
                    
                    // إضافة خيار أفضل جودة
                    qualities.insert([
                        "format_id": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
                        "resolution": "Best Quality",
                        "ext": "mp4",
                        "filesize": 0,
                        "has_video": true,
                        "has_audio": true
                    ], at: 0)
                    
                    // ترتيب الجودات
                    qualities.sort { (a, b) -> Bool in
                        let resA = a["resolution"] as? String ?? ""
                        let resB = b["resolution"] as? String ?? ""
                        
                        if resA == "Best Quality" { return true }
                        if resB == "Best Quality" { return false }
                        
                        let getOrder = { (res: String) -> Int in
                            switch res {
                            case "2160p": return 2160
                            case "1440p": return 1440
                            case "1080p": return 1080
                            case "720p": return 720
                            case "480p": return 480
                            case "360p": return 360
                            case "240p": return 240
                            case "144p": return 144
                            default: return 0
                            }
                        }
                        
                        return getOrder(resA) > getOrder(resB)
                    }
                    
                    print("✅ Found \(qualities.count) qualities")
                    
                    // إضافة خيار الصوت فقط
                    qualities.append([
                        "format_id": "bestaudio[ext=m4a]/bestaudio",
                        "resolution": "Audio Only",
                        "ext": "mp3",
                        "filesize": 0,
                        "has_video": false,
                        "has_audio": true,
                        "audioOnly": true
                    ])
                    
                    let response: [String: Any] = [
                        "type": "youtubeQualities",
                        "requestId": requestId,
                        "qualities": qualities
                    ]
                    
                    if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                        DispatchQueue.main.async {
                            connection.send(data: responseData)
                        }
                    }
                } else {
                    print("❌ Failed to read yt-dlp output")
                    self.sendQualitiesError(connection: connection, requestId: requestId, error: "Failed to parse video information")
                }
            } catch {
                print("❌ Process error: \(error)")
                self.sendQualitiesError(connection: connection, requestId: requestId, error: "Failed to run yt-dlp: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleYouTubeDownload(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let url = data["url"] as? String,
              let quality = data["quality"] as? String,
              let title = data["title"] as? String else {
            connection.send(data: createErrorResponse("Invalid YouTube download data"))
            return
        }
        
        let headers = data["headers"] as? [String: String] ?? [:]
        
        // تحسين الجودة المختارة
        let optimizedQuality = optimizeYouTubeQuality(quality)
        print("🎬 Quality optimization: '\(quality)' -> '\(optimizedQuality)'")
        
        // طباعة تفصيلية للـ headers المستلمة
        print("📋 Headers received from WebSocket:")
        for (key, value) in headers {
            if key.lowercased() == "cookie" {
                print("  \(key): \(String(value.prefix(50)))...")
            } else {
                print("  \(key): \(value)")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let _ = self.viewModel else {
                connection.send(data: self?.createErrorResponse("ViewModel not available") ?? Data())
                return
            }
            
            // إرسال إشعار إلى ViewModel لمعالجة طلب تحميل YouTube
            NotificationCenter.default.post(
                name: .youtubeDownloadRequest,
                object: nil,
                userInfo: [
                    "url": url,
                    "title": title,
                    "quality": optimizedQuality,
                    "headers": headers,
                    "source": "websocket"
                ]
            )
            
            let response: [String: Any] = [
                "type": "youtubeDownloadStarted",
                "status": "processing_by_app",
                "title": title
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                connection.send(data: responseData)
            }
        }
    }
    
    private func handleVideoCaptureRequest(_ data: [String: Any], from connection: WebSocketConnection) {
        guard let videoData = data["data"] as? [String: Any] else {
            connection.send(data: createErrorResponse("Invalid video capture data"))
            return
        }
        
        guard let url = videoData["url"] as? String else {
            connection.send(data: createErrorResponse("Missing URL in video capture data"))
            return
        }
        
        let headers = videoData["headers"] as? [String: String] ?? [:]
        let pageTitle = videoData["pageTitle"] as? String ?? "Video"
        let videoType = videoData["videoType"] as? String ?? "unknown"
        let contentType = videoData["contentType"] as? String
        
        print("📹 Video capture request received: \(pageTitle)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else {
                connection.send(data: self?.createErrorResponse("ViewModel not available") ?? Data())
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
            
            // إرسال رد نجاح
            let response: [String: Any] = [
                "type": "videoCaptureAccepted",
                "url": url,
                "fileName": fileName,
                "status": "processing_with_headers"
            ]
            
            if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                connection.send(data: responseData)
            }
        }
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
    
    private func getSupportDirectory() -> String? {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "SafarGet"
        let appSupportDir = appSupportURL?.appendingPathComponent(appName)
        
        if let supportDir = appSupportDir?.path {
            // إنشاء المجلد إذا لم يكن موجوداً
            if !fileManager.fileExists(atPath: supportDir) {
                do {
                    try fileManager.createDirectory(atPath: supportDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("❌ Failed to create support directory: \(error)")
                    return nil
                }
            }
            return supportDir
        }
        
        return nil
    }
    
    private func sendQualitiesError(connection: WebSocketConnection, requestId: String, error: String) {
        let response: [String: Any] = [
            "type": "youtubeQualities",
            "requestId": requestId,
            "error": error,
            "qualities": []
        ]
        
        if let responseData = try? JSONSerialization.data(withJSONObject: response) {
            DispatchQueue.main.async {
                connection.send(data: responseData)
            }
        }
    }
    
    private func createErrorResponse(_ message: String) -> Data {
        let error = ["type": "error", "message": message]
        return (try? JSONSerialization.data(withJSONObject: error)) ?? Data()
    }

    func removeConnection(_ connection: WebSocketConnection) {
        connections.remove(connection)
        print("🛑 WebSocket client disconnected (active connections: \(connections.count))")
    }
    
    private func parseFileSize(_ sizeStr: String) -> Int64 {
        let cleanStr = sizeStr.replacingOccurrences(of: "iB", with: "")
        let components = cleanStr.components(separatedBy: CharacterSet.letters)
        guard let valueStr = components.first,
              let value = Double(valueStr) else { return 0 }
        
        let multiplier: Double
        if sizeStr.contains("G") {
            multiplier = 1024 * 1024 * 1024
        } else if sizeStr.contains("M") {
            multiplier = 1024 * 1024
        } else if sizeStr.contains("K") {
            multiplier = 1024
        } else {
            multiplier = 1
        }
        
        return Int64(value * multiplier)
    }
}

// MARK: - WebSocket Connection
class WebSocketConnection: Hashable {
    private let connection: NWConnection
    private weak var server: SafarGetWebSocketServer?
    private let queue = DispatchQueue(label: "com.SafarGet.ws.connection")
    
    init(connection: NWConnection, server: SafarGetWebSocketServer) {
        self.connection = connection
        self.server = server
    }
    
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ WebSocket client connected")
                self?.receiveMessage()
            case .failed(let error):
                print("❌ WebSocket connection failed: \(error)")
                self?.close()
            case .cancelled:
                print("ℹ️ WebSocket connection cancelled")
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveMessage() {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.server?.handleMessage(data, from: self!)
            }
            
            if error == nil {
                self?.receiveMessage()
            } else {
                print("❌ Receive error: \(error!)")
                self?.close()
            }
        }
    }
    
    func send(data: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "WebSocket", metadata: [metadata])
        
        connection.send(content: data, contentContext: context, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    func close() {
        connection.cancel()
        server?.removeConnection(self)
    }
    
    static func == (lhs: WebSocketConnection, rhs: WebSocketConnection) -> Bool {
        return lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

