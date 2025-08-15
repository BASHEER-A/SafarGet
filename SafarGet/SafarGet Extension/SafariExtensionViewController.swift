import SafariServices

class SafariExtensionViewController: SFSafariExtensionViewController {
    
    static let shared = SafariExtensionViewController()
    
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var connectionIndicator: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredContentSize = NSSize(width: 300, height: 200)
        setupUI()
        checkAppConnection()
    }
    
    func setupUI() {
        // تحديث واجهة المستخدم
        connectionIndicator?.wantsLayer = true
        connectionIndicator?.layer?.cornerRadius = 5
        updateConnectionStatus(isConnected: false)
    }
    
    func checkAppConnection() {
        // التحقق من وجود التطبيق وحالة الاتصال
        if let sharedDefaults = UserDefaults(suiteName: "group.com.safarget.downloads") {
            let lastSync = sharedDefaults.double(forKey: "lastSyncTime")
            let currentTime = Date().timeIntervalSince1970
            
            // إذا كان آخر تزامن قبل أقل من 5 ثواني، نعتبر التطبيق متصل
            let isConnected = (currentTime - lastSync) < 5.0
            updateConnectionStatus(isConnected: isConnected)
        } else {
            updateConnectionStatus(isConnected: false)
        }
        
        // جدولة التحقق التالي
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkAppConnection()
        }
    }
    
    func updateConnectionStatus(isConnected: Bool) {
        DispatchQueue.main.async { [weak self] in
            if isConnected {
                self?.statusLabel?.stringValue = "متصل بـ SafarGet"
                self?.connectionIndicator?.layer?.backgroundColor = NSColor.systemGreen.cgColor
            } else {
                self?.statusLabel?.stringValue = "غير متصل"
                self?.connectionIndicator?.layer?.backgroundColor = NSColor.systemRed.cgColor
            }
        }
    }
    
    @IBAction func openApp(_ sender: Any) {
        if let url = URL(string: "safarget://open") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func openSettings(_ sender: Any) {
        if let url = URL(string: "safarget://settings") {
            NSWorkspace.shared.open(url)
        }
    }
}