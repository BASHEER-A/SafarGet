import SwiftUI
import AppKit
import Combine

// MARK: - Menu Bar Status
class MenuBarStatus: NSObject {
    static let shared = MenuBarStatus()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var viewModel: DownloadManagerViewModel?
    private var updateTimer: Timer?
    private var eventMonitor: EventMonitor?
    
    func setup(with viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            button.imagePosition = .imageLeft
            updateButton()
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        setupPopover()
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover?.isShown == true {
                strongSelf.closePopover()
            }
        }
        
        startUpdating()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 300)
        popover?.behavior = .transient
        popover?.animates = true
    }
    
    private func startUpdating() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateButton()
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadUpdate),
            name: .downloadProgressUpdated,
            object: nil
        )
    }
    
    @objc private func handleDownloadUpdate() {
        DispatchQueue.main.async {
            self.updateButton()
        }
    }
    
    private func updateButton() {
        guard let viewModel = viewModel,
              let button = statusItem?.button else { return }
        
        let activeDownloads = viewModel.downloads.filter { $0.status == .downloading }
        
        if activeDownloads.isEmpty {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            button.title = ""
            return
        }
        
        // ✅ حساب السرعة الفعلية فقط للتحميلات النشطة والحقيقية
        var totalSpeed: Double = 0
        var validDownloadsCount = 0
        
        for download in activeDownloads {
            let currentSpeed = RealTimeSpeedTracker.shared.getInstantSpeed(for: download.id)
            
            // ✅ فلترة القيم غير المنطقية
            if currentSpeed > 0 && currentSpeed < 100_000_000 { // أقل من 100MB/s
                totalSpeed += currentSpeed
                validDownloadsCount += 1
            }
        }
        
        let progress = activeDownloads.reduce(0.0) { $0 + $1.progress } / Double(activeDownloads.count)
        
        button.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
        button.imagePosition = .imageLeft
        
        if totalSpeed > 0 {
            let speedText = formatSpeed(totalSpeed)
            button.title = "\(speedText) • \(Int(progress * 100))%"
        } else {
            button.title = "↓ \(activeDownloads.count) • \(Int(progress * 100))%"
        }
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            popover.isShown ? closePopover() : showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button,
              let viewModel = viewModel else { return }
        
        let contentView = MenuBarPopoverView(viewModel: viewModel) {
            self.closePopover()
        }
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        eventMonitor?.start()
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.1f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Event Monitor (بدون تغيير)
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    public init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}

// MARK: - Menu Bar Popover View (بدون تغيير)
struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    let onClose: () -> Void
    @State private var animateIn = false
    // دالة مساعدة لتنسيق السرعة
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
    var activeDownloads: [DownloadItem] {
        viewModel.downloads.filter { $0.status == .downloading }
    }
    
    var totalSpeed: Double {
        activeDownloads.reduce(0.0) { total, download in
            let speed = RealTimeSpeedTracker.shared.getInstantSpeed(for: download.id)
return speed > 0 && speed < 100_000_000 ? total + speed : total
        }
    }
    
    var averageProgress: Double {
        guard !activeDownloads.isEmpty else { return 0 }
        return activeDownloads.reduce(0.0) { $0 + $1.progress } / Double(activeDownloads.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SafarGet")
                        .font(.system(size: 13, weight: .semibold))
                    
                    if !activeDownloads.isEmpty && totalSpeed > 0 {
                        HStack(spacing: 6) {
                            Text(formatSpeed(totalSpeed))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.green)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(averageProgress * 100))%")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(NSColor.controlBackgroundColor),
                        Color(NSColor.controlBackgroundColor).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 1)
            
            if activeDownloads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("No active downloads")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(activeDownloads.prefix(5).enumerated()), id: \.element.id) { index, download in
                            CompactDownloadItemView(download: download)
                        }
                    }
                    .padding(8)
                }
            }
            
            HStack(spacing: 0) {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    onClose()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11))
                        Text("Show")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if !activeDownloads.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("\(activeDownloads.count) Active")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
        }
        .frame(width: 280, height: activeDownloads.isEmpty ? 200 : 300)
    }
    
}

// MARK: - Compact Download Item View (بدون تغيير)
struct CompactDownloadItemView: View {
    let download: DownloadItem
    @State private var isHovered = false
    @State private var displaySpeed: Double = 0
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: download.fileType.icon)
                    .font(.system(size: 11))
                    .foregroundColor(download.fileType.color)
                
                Text(download.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                
                Spacer()
                
                if download.status == .downloading {
                    HStack(spacing: 3) {
                        if displaySpeed > 0 {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                            
                            Text(formatSpeed(displaySpeed))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // ✅ إصلاح: منع ظهور النسبة المئوية الخاطئة عند الاستئناف
            let isResuming = download.downloadSpeed.contains("Resuming") || 
                            download.downloadSpeed.contains("Connecting") ||
                            download.downloadSpeed.contains("Starting")
            
            let displayProgress = isResuming && download.downloadedSize == 0 ? 
                max(download.progress, 0) : download.progress
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    progressColor(for: displayProgress),
                                    progressColor(for: displayProgress).opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * displayProgress)
                }
            }
            .frame(height: 4)
            
            HStack(spacing: 8) {
                
                Text("\(Int(displayProgress * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(progressColor(for: displayProgress))
                
                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                
                Text(formatFileSize(download.downloadedSize))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                if !download.remainingTime.isEmpty && download.remainingTime != "--:--" {
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(download.remainingTime)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(8)
        .onAppear {
            updateDisplaySpeed()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if download.status == .downloading {
                updateDisplaySpeed()
            }
        }
    }
    
    private func updateDisplaySpeed() {
        displaySpeed = RealTimeSpeedTracker.shared.getInstantSpeed(for: download.id)
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress < 0.25 { return .red }
        else if progress < 0.5 { return .orange }
        else if progress < 0.75 { return .yellow }
        else { return .green }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }
}
