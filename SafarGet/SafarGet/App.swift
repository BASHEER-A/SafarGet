//
//  App.swift
//  SafarGet
//
//  Created by Your Name on 24/07/2025.
//

import SwiftUI
import AppKit

class MainAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ SafarGet started successfully")
        
        // تهيئة اللغة
        setupLanguage()
        
        // إعداد قائمة Apple Menu
        setupAppleMenu()
        
        // تهيئة مدير تنظيف العمليات
        _ = ProcessCleanupManager.shared
        
        // بدء مراقبة الذاكرة والـ CPU
        MemoryManager.shared.startAutoMemoryManagement()
        
        // تنظيم الملفات المؤقتة عند بدء التطبيق
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.cleanupTempFilesOnStartup()
        }
        
        // Pre-warm yt-dlp لتحسين سرعة التحميل
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.prewarmYtDlp()
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 SafarGet is terminating, cleaning up processes...")
        
        // إيقاف مراقبة CPU
        MemoryManager.shared.stopCPUMonitoring()
        
        // تنظيف شامل للعمليات عند إغلاق التطبيق
        ProcessCleanupManager.shared.cleanupOnAppTermination()
        
        print("✅ SafarGet termination cleanup completed")
    }
    
    // MARK: - Missing Methods
    
    private func cleanupTempFilesOnStartup() {
        print("🧹 Cleaning temp files on startup...")
        
        let downloadsPath = NSString(string: "~/Downloads").expandingTildeInPath
        let fileManager = FileManager.default
        
        // حذف جميع الملفات المؤقتة من مجلد Downloads
        let tempExtensions = [".temp", ".aria2", ".downloading", ".part", ".tmp"]
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: downloadsPath)
            var deletedCount = 0
            
            for file in files {
                for ext in tempExtensions {
                    if file.hasSuffix(ext) || file.hasPrefix(".") && file.hasSuffix(ext) {
                        let filePath = "\(downloadsPath)/\(file)"
                        try fileManager.removeItem(atPath: filePath)
                        print("🗑️ Deleted temp file on startup: \(file)")
                        deletedCount += 1
                        break
                    }
                }
            }
            
            // حذف مجلد .safarget_temp إذا كان موجوداً
            let safargetTempPath = "\(downloadsPath)/.safarget_temp"
            if fileManager.fileExists(atPath: safargetTempPath) {
                try fileManager.removeItem(atPath: safargetTempPath)
                print("🗑️ Deleted .safarget_temp directory on startup")
                deletedCount += 1
            }
            
            if deletedCount > 0 {
                print("✅ Cleaned up \(deletedCount) temp files/directories on startup")
            }
            
        } catch {
            print("⚠️ Failed to cleanup temp files on startup: \(error)")
        }
    }
    
    private func prewarmYtDlp() {
        print("🔥 Pre-warming yt-dlp for faster downloads...")
        
        // الحصول على مسار yt-dlp من Resources
        guard let bundlePath = Bundle.main.resourcePath else {
            print("⚠️ Could not get bundle resource path")
            return
        }
        
        let ytDlpPath = "\(bundlePath)/yt-dlp"
        let ytDlpPythonPath = "\(bundlePath)/yt-dlp.py"
        
        // التحقق من وجود yt-dlp
        let fileManager = FileManager.default
        let executablePath = fileManager.fileExists(atPath: ytDlpPath) ? ytDlpPath : ytDlpPythonPath
        
        guard fileManager.fileExists(atPath: executablePath) else {
            print("⚠️ yt-dlp not found at: \(executablePath)")
            return
        }
        
        // جعل الملف قابل للتنفيذ
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath)
            print("✅ Set executable permissions for yt-dlp")
        } catch {
            print("⚠️ Failed to set executable permissions: \(error)")
        }
        
        // تشغيل yt-dlp مع أمر بسيط لـ pre-warm
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--version"]
        
        // إعداد بيئة العمل
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = bundlePath
        process.environment = environment
        
        // إعداد pipe للـ output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ yt-dlp pre-warmed successfully")
                
                // تشغيل أمر إضافي لتحسين الأداء
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.runAdditionalPrewarm(executablePath: executablePath, bundlePath: bundlePath)
                }
            } else {
                print("⚠️ yt-dlp pre-warm failed with status: \(process.terminationStatus)")
            }
        } catch {
            print("⚠️ Failed to run yt-dlp pre-warm: \(error)")
        }
    }
    
    private func runAdditionalPrewarm(executablePath: String, bundlePath: String) {
        print("🔥 Running additional yt-dlp pre-warm optimizations...")
        
        // تشغيل yt-dlp مع extractor info لتحسين الأداء
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--list-extractors"]
        
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = bundlePath
        process.environment = environment
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ yt-dlp extractors pre-loaded successfully")
            }
        } catch {
            print("⚠️ Additional pre-warm failed: \(error)")
        }
    }
    
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        if url.scheme == "safarget" {
            handleSafarGetURL(url)
        } else {
            NotificationCenter.default.post(name: .newDownload, object: nil, userInfo: ["url": urlString])
        }
    }
    
    @objc func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "About SafarGet"
        alert.informativeText = "SafarGet v1.0\n\nA powerful download manager for macOS with YouTube support.\n\n© 2025 SafarGet Team"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func newDownload() {
        NotificationCenter.default.post(name: Notification.Name("ShowAddDownload"), object: nil)
    }
    
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "SafarGet Help"
        alert.informativeText = "To use SafarGet:\n\n1. Add downloads using the + button\n2. Use the Safari extension for YouTube downloads\n3. Monitor progress in the main window\n4. Pause/resume downloads as needed"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func setupLanguage() {
        // تحميل تفضيل اللغة المحفوظ
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            let languageCode: String
            switch savedLanguage {
            case "English":
                languageCode = "en"
            case "العربية":
                languageCode = "ar"
            case "Français":
                languageCode = "fr"
            default:
                languageCode = "en"
            }
            
            // تطبيق اللغة
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            print("🌍 Language set to: \(savedLanguage) (\(languageCode))")
        } else {
            // إذا لم تكن هناك لغة محفوظة، اكتشف لغة النظام
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            print("🌍 System language detected: \(systemLanguage)")
        }
    }
    
    private func setupAppleMenu() {
        // إزالة القائمة الافتراضية وإنشاء قائمة مخصصة
        NSApp.mainMenu = nil
        
        let mainMenu = NSMenu()
        
        // قائمة SafarGet (Apple Menu)
        let safarGetMenu = NSMenu()
        let safarGetMenuItem = NSMenuItem(title: "SafarGet", action: nil, keyEquivalent: "")
        safarGetMenuItem.submenu = safarGetMenu
        
        // About SafarGet
        let aboutItem = NSMenuItem(title: "About SafarGet", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        safarGetMenu.addItem(aboutItem)
        
        safarGetMenu.addItem(NSMenuItem.separator())
        
        // Hide SafarGet
        let hideItem = NSMenuItem(title: "Hide SafarGet", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        safarGetMenu.addItem(hideItem)
        
        // Hide Others
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        safarGetMenu.addItem(hideOthersItem)
        
        // Show All
        let showAllItem = NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        safarGetMenu.addItem(showAllItem)
        
        safarGetMenu.addItem(NSMenuItem.separator())
        
        // Quit SafarGet
        let quitItem = NSMenuItem(title: "Quit SafarGet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        safarGetMenu.addItem(quitItem)
        
        mainMenu.addItem(safarGetMenuItem)
        
        // قائمة File
        let fileMenu = NSMenu()
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        
        let newItem = NSMenuItem(title: "New Download", action: #selector(newDownload), keyEquivalent: "n")
        newItem.target = self
        fileMenu.addItem(newItem)
        
        mainMenu.addItem(fileMenuItem)
        
        // قائمة Help
        let helpMenu = NSMenu()
        let helpMenuItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        
        let helpItem = NSMenuItem(title: "SafarGet Help", action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
        helpMenu.addItem(helpItem)
        
        mainMenu.addItem(helpMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    private func handleSafarGetURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        // معالجة الأوامر المختلفة
        if components.host == "open" {
            // مجرد فتح التطبيق بدون أي إجراء
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            return
        }
        
        // معالجة تحميلات YouTube
        if components.host == "youtube" {
            guard let queryItems = components.queryItems else { return }
            
            var params: [String: String] = [:]
            for item in queryItems {
                params[item.name] = item.value
            }
            
            if let videoURL = params["url"],
               let title = params["title"],
               let quality = params["quality"] {
                
                // إرسال البيانات إلى ViewModel
                NotificationCenter.default.post(
                    name: .youtubeDownloadRequest,
                    object: nil,
                    userInfo: [
                        "url": videoURL,
                        "title": title,
                        "quality": quality,
                        "source": "safari_extension"
                    ]
                )
            }
            return
        }
        
        // معالجة التحميلات العادية
        guard let queryItems = components.queryItems else { return }
        
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        
        if let downloadURL = params["url"] {
            let fileName = params["fileName"] ?? extractFileName(from: downloadURL)
            
            // إرسال البيانات إلى ViewModel
            NotificationCenter.default.post(
                name: .newDownload,
                object: nil,
                userInfo: [
                    "url": downloadURL,
                    "fileName": fileName,
                    "source": "browser_extension"
                ]
            )
        }
    }
    
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "download" }
        let fileName = url.lastPathComponent
        return fileName.isEmpty ? "download" : fileName
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when window closes, let user quit via menu
        return false
    }
    
    // MARK: - Enhanced Force Stop All Background Processes
    private func forceStopAllBackgroundProcesses() {
        print("🛑 Force stopping all background processes (enhanced)...")
        
        // المرحلة 1: تنظيف العمليات عبر ProcessCleanupManager
        ProcessCleanupManager.shared.forceStopAllBackgroundProcesses()
        
        // المرحلة 2: تنظيف إضافي للعمليات المتبقية
        let additionalCleanupCommands = [
            "pkill -9 -f 'SafarGet'",
            "pkill -9 -f 'download'",
            "pkill -9 -f 'youtube'",
            "killall -9 python 2>/dev/null || true",
            "killall -9 python3 2>/dev/null || true"
        ]
        
        for command in additionalCleanupCommands {
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = ["-c", command]
            
            do {
                try process.run()
                process.waitUntilExit()
                print("✅ Additional cleanup command executed: \(command)")
            } catch {
                print("⚠️ Additional cleanup command failed: \(command) - \(error)")
            }
        }
        
        // المرحلة 3: تنظيف الملفات المؤقتة
        cleanupTempFilesOnStartup()
        
        print("✅ Enhanced force cleanup completed")
    }
}

@main
struct SafarGet: App {
    @NSApplicationDelegateAdaptor(MainAppDelegate.self) var appDelegate
    
    init() {
        // Initialize SafarGet app
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 620, minHeight: 530)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Safari Extension Status...") {
                    showSafariExtensionStatus()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            
            CommandGroup(replacing: .help) {
                Button("Safari Extension Help") {
                    showSafariExtensionStatus()
                }
                
                Button("Open Safari Extensions") {
                    openSafariExtensionsDirectly()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }
    }
    
    private func showSafariExtensionStatus() {
        // Force show Safari Extension Status
        UserDefaults.standard.set(true, forKey: "ForceShowExtensionStatus")
        
        // Post notification to trigger status check
        NotificationCenter.default.post(name: Notification.Name("ShowSafariExtensionStatus"), object: nil)
    }
    
    private func openSafariExtensionsDirectly() {
        // فتح Safari Extensions Preferences مباشرة
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preferences.extensions")!)
    }
}

extension NSWindow {
    open override func awakeFromNib() {
        super.awakeFromNib()
        self.isOpaque = true
        self.backgroundColor = NSColor.windowBackgroundColor
        self.titlebarAppearsTransparent = false
        self.titleVisibility = .visible
    }
}

// Extension to handle windowResizability compatibility
extension Scene {
    func applyWindowResizability() -> some Scene {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            return self.windowResizability(.contentSize)
        } else {
            return self
        }
        #else
        return self
        #endif
    }
}