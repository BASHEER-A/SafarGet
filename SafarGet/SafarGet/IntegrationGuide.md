# 🔧 دليل دمج Smart Download Interceptor مع SafarGet

## 📋 الخطوات المطلوبة للدمج:

### 1️⃣ إضافة الملفات للمشروع:
```bash
# تأكد من أن الملفات موجودة في مجلد SafarGet
SmartDownloadInterceptor.swift
EnhancedDownloadManager.swift
```

### 2️⃣ تعديل ViewModel.swift:
أضف في بداية الملف:
```swift
// إضافة import إذا لزم الأمر
import WebKit

// إضافة متغير للـ Enhanced Download Manager
private var enhancedDownloadManager: EnhancedDownloadManager?

// في init() أضف:
override init() {
    super.init()
    // ... الكود الحالي ...
    
    // إضافة Enhanced Download Manager
    enhancedDownloadManager = EnhancedDownloadManager(viewModel: self)
}
```

### 3️⃣ تعديل ContentView.swift:
أضف في بداية الملف:
```swift
// إضافة متغير للـ WebView المحسن
@State private var enhancedWebView: WKWebView?

// في body أضف:
var body: some View {
    // ... الكود الحالي ...
    
    // إضافة WebView محسن إذا لزم الأمر
    if let webView = enhancedWebView {
        WebViewRepresentable(webView: webView)
            .frame(width: 0, height: 0) // مخفي
    }
}

// إضافة WebViewRepresentable
struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // لا حاجة للتحديث
    }
}
```

### 4️⃣ تعديل App.swift:
أضف في MainAppDelegate:
```swift
// إضافة متغير للـ Enhanced Download Manager
private var enhancedDownloadManager: EnhancedDownloadManager?

// في applicationDidFinishLaunching أضف:
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... الكود الحالي ...
    
    // إضافة Enhanced Download Manager
    enhancedDownloadManager = EnhancedDownloadManager(viewModel: viewModel)
}
```

### 5️⃣ تعديل WebSocketServer.swift:
أضف في handleDownloadRequest:
```swift
private func handleDownloadRequest(_ json: [String: Any], from connection: WebSocketConnection) {
    // ... الكود الحالي ...
    
    // إضافة معالجة محسنة
    if let url = json["url"] as? String {
        let fileName = json["fileName"] as? String ?? extractFileName(from: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let viewModel = self.viewModel else { return }
            
            // استخدام الطريقة المحسنة
            viewModel.addEnhancedDownload(
                url: url,
                filename: fileName,
                source: "websocket_enhanced"
            )
        }
    }
}
```

### 6️⃣ تعديل NativeMessagingHost.swift:
أضف في handleDownloadRequest:
```swift
private func handleDownloadRequest(_ message: [String: Any]) {
    // ... الكود الحالي ...
    
    DispatchQueue.main.async { [weak self] in
        guard let self = self, let viewModel = self.viewModel else {
            self?.sendError("ViewModel not available")
            return
        }
        
        // استخدام الطريقة المحسنة
        viewModel.addEnhancedDownload(
            url: url,
            filename: fileName,
            source: "native_messaging_enhanced"
        )
        
        self.sendResponse([
            "type": "downloadAccepted",
            "url": url,
            "fileName": fileName,
            "status": "success"
        ])
    }
}
```

## 🔧 التعديلات الاختيارية:

### 1️⃣ إضافة WebView للتصفح المباشر:
```swift
// في ContentView أضف:
@State private var showEnhancedBrowser = false

// إضافة زر للتصفح المحسن
Button("Enhanced Browser") {
    showEnhancedBrowser = true
}
.sheet(isPresented: $showEnhancedBrowser) {
    EnhancedBrowserView()
}

// إنشاء EnhancedBrowserView
struct EnhancedBrowserView: View {
    @StateObject private var viewModel = DownloadManagerViewModel()
    @State private var webView: WKWebView?
    
    var body: some View {
        VStack {
            if let webView = webView {
                WebViewRepresentable(webView: webView)
            } else {
                Text("Loading enhanced browser...")
            }
        }
        .onAppear {
            let downloadManager = EnhancedDownloadManager(viewModel: viewModel)
            webView = downloadManager.createEnhancedWebView()
            
            // تحميل صفحة افتراضية
            if let url = URL(string: "https://example.com") {
                downloadManager.loadURL(url, in: webView!)
            }
        }
    }
}
```

### 2️⃣ إضافة إعدادات للاعتراض:
```swift
// في AppSettings أضف:
struct AppSettings: Codable {
    // ... الكود الحالي ...
    var enableSmartInterception: Bool = true
    var interceptAllDownloads: Bool = true
    var followRedirects: Bool = true
    var extractFilenames: Bool = true
}
```

### 3️⃣ إضافة إحصائيات:
```swift
// في ViewModel أضف:
class DownloadManagerViewModel: ObservableObject {
    // ... الكود الحالي ...
    
    @Published var interceptionStats = InterceptionStats()
    
    struct InterceptionStats {
        var totalIntercepted: Int = 0
        var successfulExtractions: Int = 0
        var redirectsFollowed: Int = 0
        var errors: Int = 0
    }
    
    func updateInterceptionStats(type: String) {
        DispatchQueue.main.async {
            switch type {
            case "intercepted":
                self.interceptionStats.totalIntercepted += 1
            case "extracted":
                self.interceptionStats.successfulExtractions += 1
            case "redirect":
                self.interceptionStats.redirectsFollowed += 1
            case "error":
                self.interceptionStats.errors += 1
            default:
                break
            }
        }
    }
}
```

## 🧪 اختبار التكامل:

### 1️⃣ اختبار التحميلات العادية:
```swift
// في ViewModel أضف دالة اختبار
func testEnhancedDownload() {
    let testURLs = [
        "https://example.com/file.zip",
        "https://example.com/video.mp4",
        "https://example.com/document.pdf"
    ]
    
    for url in testURLs {
        addEnhancedDownload(url: url, source: "test")
    }
}
```

### 2️⃣ اختبار الاعتراض:
```swift
// في ContentView أضف زر اختبار
Button("Test Enhanced Interception") {
    viewModel.testEnhancedDownload()
}
```

## 📊 مراقبة الأداء:

### 1️⃣ إضافة Logging:
```swift
// في SmartDownloadInterceptor أضف:
private func logInterception(type: String, url: String) {
    print("🎯 SafarGet Enhanced: \(type) - \(url)")
    
    // إرسال إحصائيات للـ ViewModel
    DispatchQueue.main.async {
        self.viewModel?.updateInterceptionStats(type: "intercepted")
    }
}
```

### 2️⃣ إضافة Metrics:
```swift
// في ViewModel أضف:
@Published var performanceMetrics = PerformanceMetrics()

struct PerformanceMetrics {
    var averageExtractionTime: TimeInterval = 0
    var totalProcessingTime: TimeInterval = 0
    var successRate: Double = 0
}
```

## ✅ التحقق من التكامل:

### 1️⃣ فحص الملفات:
```bash
# تأكد من وجود الملفات
ls -la SmartDownloadInterceptor.swift
ls -la EnhancedDownloadManager.swift
```

### 2️⃣ فحص Compilation:
```bash
# بناء المشروع
xcodebuild -project SafarGet.xcodeproj -scheme SafarGet build
```

### 3️⃣ فحص Runtime:
```bash
# تشغيل التطبيق ومراقبة Logs
# يجب أن تظهر رسائل:
# 🚀 SafarGet: Smart Download Interceptor loaded
# ✅ SafarGet: Smart Download Interceptor fully loaded
```

## 🎯 النتيجة المتوقعة:

بعد التكامل، ستحصل على:
- ✅ اعتراض شامل لكل التحميلات
- ✅ استخراج الرابط النهائي الحقيقي
- ✅ تحديد نوع الملف تلقائياً
- ✅ أداء محسن وموثوقية عالية
- ✅ دعم كل أنواع الملفات
- ✅ مراقبة وإحصائيات شاملة

---
*هذا الدليل يضمن التكامل السلس للحل الجديد مع التطبيق الحالي*
