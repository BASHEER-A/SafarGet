import Foundation
import SwiftUI
import WebKit
import AppKit

// MARK: - Universal Download Example - مثال على استخدام النظام الشامل
struct UniversalDownloadExample: View {
    
    // MARK: - Properties
    @State private var universalDetector: UniversalDownloadDetector?
    @State private var webView: WKWebView?
    @State private var viewModel: DownloadManagerViewModel!
    @State private var isVerboseMode = false
    @State private var statusText = "🚀 Universal Download Detector Ready"
    
    // MARK: - UI Elements
    @State private var showCrashLog = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // Status Label
            Text(statusText)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .padding()
            
            // Verbose Mode Toggle
            HStack {
                Text("Verbose Mode")
                Toggle("", isOn: $isVerboseMode)
                    .onChange(of: isVerboseMode) { newValue in
                        verboseSwitchChanged(newValue)
                    }
            }
            .padding(.horizontal)
            
            // Crash Log Button
            Button("View Crash Log") {
                showCrashLog = true
            }
            .buttonStyle(.borderedProminent)
            
            // WebView
            if let webView = webView {
                WebViewRepresentable(webView: webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Loading WebView...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            setupUniversalDetector()
        }
        .alert("Crash Log", isPresented: $showCrashLog) {
            Button("OK") { }
        } message: {
            let crashLog = universalDetector?.getCrashLog() ?? []
            if crashLog.isEmpty {
                Text("No crash log entries found")
            } else {
                Text("Found \(crashLog.count) entries")
            }
        }
    }
    
    private func setupUniversalDetector() {
        // إنشاء ViewModel
        viewModel = DownloadManagerViewModel()
        
        // إنشاء المعترض الشامل
        universalDetector = UniversalDownloadDetector(viewModel: viewModel)
        
        // بدء الاكتشاف
        webView = universalDetector?.startUniversalDetection()
        
        if let webView = webView {
            // تحميل صفحة تجريبية
            loadTestPage(webView: webView)
        }
    }
    
    // MARK: - Actions
    private func verboseSwitchChanged(_ isOn: Bool) {
        if isOn {
            universalDetector?.enableVerboseMode()
            statusText = "🔍 Verbose Mode Enabled"
        } else {
            statusText = "🚀 Universal Download Detector Ready"
        }
    }
    
    // MARK: - Test Methods
    private func loadTestPage(webView: WKWebView) {
        // صفحة تجريبية تحتوي على روابط تحميل مختلفة
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Universal Download Test</title>
            <style>
                body { font-family: Arial, sans-serif; padding: 20px; }
                .download-link { display: block; margin: 10px 0; padding: 10px; background: #007AFF; color: white; text-decoration: none; border-radius: 5px; }
                .download-link:hover { background: #0056CC; }
                .section { margin: 20px 0; padding: 15px; border: 1px solid #ccc; border-radius: 5px; }
                h2 { color: #333; }
            </style>
        </head>
        <body>
            <h1>🧠 SafarGet Universal Download Test</h1>
            
            <div class="section">
                <h2>1️⃣ Direct Links</h2>
                <a href="https://example.com/file.zip" class="download-link">Direct ZIP Download</a>
                <a href="https://example.com/document.pdf" class="download-link">Direct PDF Download</a>
                <a href="https://example.com/video.mp4" class="download-link">Direct Video Download</a>
            </div>
            
            <div class="section">
                <h2>2️⃣ JavaScript Redirects</h2>
                <button onclick="window.location.href='https://example.com/redirect.zip'" class="download-link">JavaScript Redirect to ZIP</button>
                <button onclick="window.open('https://example.com/popup.pdf')" class="download-link">Window Open PDF</button>
            </div>
            
            <div class="section">
                <h2>3️⃣ Form Submissions</h2>
                <form action="https://example.com/download" method="POST">
                    <input type="hidden" name="file" value="test.zip">
                    <button type="submit" class="download-link">Form Submit Download</button>
                </form>
            </div>
            
            <div class="section">
                <h2>4️⃣ Fetch/XHR Requests</h2>
                <button onclick="testFetch()" class="download-link">Fetch Download</button>
                <button onclick="testXHR()" class="download-link">XHR Download</button>
            </div>
            
            <div class="section">
                <h2>5️⃣ Blob URLs</h2>
                <button onclick="testBlob()" class="download-link">Create Blob Download</button>
            </div>
            
            <div class="section">
                <h2>6️⃣ Data URLs</h2>
                <a href="data:application/pdf;base64,JVBERi0xLjQKJcOkw7zDtsO" class="download-link">Data URL PDF</a>
            </div>
            
            <div class="section">
                <h2>7️⃣ Masked Links</h2>
                <a href="https://example.com/download.php?id=123" class="download-link">Masked Download Link</a>
                <a href="https://example.com/get/file/456" class="download-link">Get File Link</a>
            </div>
            
            <script>
                function testFetch() {
                    fetch('https://example.com/api/download')
                        .then(response => response.blob())
                        .then(blob => {
                            console.log('Fetch download completed');
                        });
                }
                
                function testXHR() {
                    const xhr = new XMLHttpRequest();
                    xhr.open('GET', 'https://example.com/api/download');
                    xhr.send();
                }
                
                function testBlob() {
                    const blob = new Blob(['Test content'], { type: 'text/plain' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = 'test.txt';
                    a.click();
                }
                
                // Service Worker test
                if ('serviceWorker' in navigator) {
                    navigator.serviceWorker.register('/sw.js')
                        .then(registration => {
                            console.log('Service Worker registered');
                        });
                }
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(testHTML, baseURL: nil)
    }
    
    // MARK: - Download Management
    func addTestDownload() {
        let testURLs = [
            "https://example.com/test.zip",
            "https://example.com/document.pdf",
            "https://example.com/video.mp4",
            "https://example.com/audio.mp3"
        ]
        
        for url in testURLs {
            viewModel.addDownloadEnhanced(
                url: url,
                fileName: extractFileName(from: url),
                fileType: determineFileType(from: url),
                savePath: "~/Downloads",
                chunks: 16,
                cookiesPath: nil
            )
        }
    }
    
    private func extractFileName(from url: String) -> String {
        guard let url = URL(string: url) else { return "download" }
        let fileName = url.lastPathComponent
        return fileName.isEmpty ? "download" : fileName
    }
    
    private func determineFileType(from url: String) -> DownloadItem.FileType {
        let url = url.lowercased()
        
        if url.contains(".mp4") || url.contains(".avi") || url.contains(".mkv") {
            return .video
        } else if url.contains(".mp3") || url.contains(".wav") || url.contains(".flac") {
            return .audio
        } else if url.contains(".pdf") || url.contains(".doc") || url.contains(".docx") {
            return .document
        } else if url.contains(".exe") || url.contains(".dmg") || url.contains(".pkg") {
            return .executable
        } else if url.contains(".torrent") {
            return .torrent
        } else {
            return .other
        }
    }
}

// MARK: - WebView Representable
struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }
}

// MARK: - Extension for DownloadManagerViewModel
extension DownloadManagerViewModel {
    
    /// إضافة تحميل تجريبي
    func addTestDownload(url: String, filename: String? = nil) {
        let finalFilename = filename ?? extractFileName(from: url)
        let fileType = determineFileType(from: url)
        
        print("🧪 Test Download Added:")
        print("   URL: \(url)")
        print("   Filename: \(finalFilename)")
        print("   Type: \(fileType)")
        
        addDownloadEnhanced(
            url: url,
            fileName: finalFilename,
            fileType: fileType,
            savePath: "~/Downloads",
            chunks: 16,
            cookiesPath: nil
        )
    }
    
    private func extractFileName(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "download" }
        let fileName = url.lastPathComponent
        return fileName.isEmpty ? "download" : fileName
    }
    
    private func determineFileType(from urlString: String) -> DownloadItem.FileType {
        let url = urlString.lowercased()
        
        if url.contains(".mp4") || url.contains(".avi") || url.contains(".mkv") {
            return .video
        } else if url.contains(".mp3") || url.contains(".wav") || url.contains(".flac") {
            return .audio
        } else if url.contains(".pdf") || url.contains(".doc") || url.contains(".docx") {
            return .document
        } else if url.contains(".exe") || url.contains(".dmg") || url.contains(".pkg") {
            return .executable
        } else if url.contains(".torrent") {
            return .torrent
        } else {
            return .other
        }
    }
}
