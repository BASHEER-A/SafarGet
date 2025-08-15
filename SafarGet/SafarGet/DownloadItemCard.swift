import SwiftUI
import AppKit

// MARK: - Enhanced Download Item Card (مصلح ومحسن)
struct EnhancedDownloadItemCard: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var viewModel: DownloadManagerViewModel
    
    @State private var isHovered = false
    @State private var showingActions = false
    
    let insertionDelay: Double
    
    init(item: DownloadItem, viewModel: DownloadManagerViewModel, insertionDelay: Double = 0) {
        self.item = item
        self.viewModel = viewModel
        self.insertionDelay = insertionDelay
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(item: item, viewModel: viewModel, isHovered: isHovered)
            if item.status == .downloading || item.status == .paused {
                DownloadProgressView(item: item, viewModel: viewModel)
            }
            ActionsView(item: item, viewModel: viewModel, showingActions: showingActions, isHovered: isHovered)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(isHovered ? 0.15 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.selectedDownloadIDs.contains(item.id)
                                ? Color.blue.opacity(0.6)
                                : item.fileType.color.opacity(isHovered ? 0.4 : 0.2),
                            lineWidth: viewModel.selectedDownloadIDs.contains(item.id) ? 1.4 : 0.7
                        )
                )
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .transition(
            .asymmetric(
                insertion:
                    AnyTransition.scale(scale: 0.9, anchor: .top)
                    .combined(with: .opacity),
                removal:
                    .scale(scale: 0.95).combined(with: .opacity)
            )
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8)
                .delay(insertionDelay),
            value: item.id
        )
        .scaleEffect(
            viewModel.selectedDownloadIDs.contains(item.id) ? 0.986 : 1.0
        )
        .animation(.spring(response: 0.1, dampingFraction: 0.8), value: viewModel.selectedDownloadIDs.contains(item.id))
        .onHover { hovering in
            isHovered = hovering
            showingActions = hovering
        }
        .onTapGesture {
            viewModel.toggleSelection(item.id)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        // مراقبة تغييرات مهمة فقط
        .onChange(of: item.status) { _ in
            // تحديث UI عند تغيير الحالة
        }
        .onChange(of: item.downloadSpeed) { _ in
            // تحديث UI عند تغيير السرعة
        }
        .onChange(of: item.progress) { _ in
            // تحديث UI عند تغيير التقدم
        }
    }
}

// MARK: - Header View (مصلح ومبسط)
struct HeaderView: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var viewModel: DownloadManagerViewModel
    let isHovered: Bool
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 8) {
            if !viewModel.selectedDownloadIDs.isEmpty || viewModel.selectedDownloadIDs.contains(item.id) {
                Toggle("", isOn: Binding(
                    get: { viewModel.selectedDownloadIDs.contains(item.id) },
                    set: { _ in viewModel.toggleSelection(item.id) }
                ))
                .toggleStyle(.checkbox)
                .scaleEffect(0.63)
                .transition(.scale.combined(with: .opacity))
            }
            
            ZStack {
                Circle()
                    .fill(item.fileType.color.opacity(0.2))
                    .frame(width: 26, height: 26)
                Image(systemName: item.fileType.icon)
                    .font(.system(size: 11.5))
                    .foregroundColor(item.fileType.color)
            }
            
            VStack(alignment: .leading, spacing: 2.5) {
                FileInfoView(item: item, isBitsPerSecond: item.isTorrent, viewModel: viewModel)
                MetadataView(item: item, viewModel: viewModel)
                
                if item.status == .downloading && !networkMonitor.isConnected {
                    ConnectionLostIndicator()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            Spacer()
            
            // مؤشر السرعة المبسط
            if item.status == .downloading {
                RealTimeSpeedDisplay(
                    item: item,
                    maxSpeed: item.maxSpeed,
                    isActive: item.status == .downloading && networkMonitor.isConnected
                )
                .scaleEffect(1.05)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: item.status)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}

// MARK: - File Info View
struct FileInfoView: View {
    @ObservedObject var item: DownloadItem
    let isBitsPerSecond: Bool
    @ObservedObject var viewModel: DownloadManagerViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        HStack {
            Text(item.fileName)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            if item.isYouTubeVideo {
                Label("YouTube", systemImage: "play.tv")
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1.2)
                    .background(.red.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if item.isTorrent {
                Label("Torrent", systemImage: "arrow.down.circle")
                    .font(.system(size: 9))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1.2)
                    .background(.yellow.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            Text(item.status.displayText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(item.status.color)
                .cornerRadius(8)
        }
    }
}

// MARK: - Metadata View
struct MetadataView: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var stableRemainingTime: String = "--:--"

    var body: some View {
        VStack(alignment: .leading, spacing: 2.5) {
            HStack(spacing: 10) {
                if item.fileSize > 0 {
                    Label(viewModel.formatFileSize(item.fileSize), systemImage: "doc.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                if item.status == .downloading {
                    if stableRemainingTime != "--:--" && stableRemainingTime != "00:00" {
                        Label(stableRemainingTime, systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                            .onReceive(Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()) { _ in
                                stableRemainingTime = item.preciseETA
                            }
                    }
                }
                if item.chunks > 1 && !item.isYouTubeVideo && !item.isTorrent {
                    Label("\(item.chunks) threads", systemImage: "square.split.1x2")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
            }
            if item.isTorrent && item.status == .downloading {
                HStack(spacing: 10) {
                    // إظهار Peers دائماً مع قيمة افتراضية "0" إذا كانت فارغة
                    Label("Peers: \(item.peers.isEmpty ? "0" : item.peers)", systemImage: "person.2")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    
                    // إظهار Seeds دائماً مع قيمة افتراضية "0" إذا كانت فارغة
                    Label("Seeds: \(item.seeds.isEmpty ? "0" : item.seeds)", systemImage: "leaf")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    if !item.uploadSpeed.isEmpty && item.uploadSpeed != "0 KB/s" {
                        Label("↑ \(item.uploadSpeed)", systemImage: "arrow.up")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }
                }
            }
        }
    }
}

// MARK: - Connection Lost Indicator
struct ConnectionLostIndicator: View {
    @State private var isBlinking = false
    
    var body: some View {
        HStack(spacing: 3.5) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(.red)
            
            Text(NSLocalizedString("No Internet Connection", comment: "No internet connection status"))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isBlinking ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }
}

// MARK: - Actions View
struct ActionsView: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var viewModel: DownloadManagerViewModel
    let showingActions: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 5) {
            if item.status == .downloading || item.status == .paused || (isHovered && showingActions) {
                if item.status == .downloading {
                    ActionButton(title: NSLocalizedString("Pause", comment: "Pause download button"), icon: "pause.fill", color: .orange) {
                        viewModel.pauseDownload(item)
                    }
                    ActionButton(title: NSLocalizedString("Stop", comment: "Stop download button"), icon: "stop.fill", color: .red) {
                        viewModel.stopDownload(item)
                    }
                } else if item.status == .paused {
                    ActionButton(title: NSLocalizedString("Resume", comment: "Resume download button"), icon: "play.fill", color: .green) {
                        viewModel.resumeDownload(item)
                    }
                    ActionButton(title: NSLocalizedString("Restart", comment: "Restart download button"), icon: "arrow.clockwise", color: .orange) {
                        viewModel.restartDownload(item)
                    }
                } else if item.status == .completed {
                    ActionButton(title: NSLocalizedString("Open", comment: "Open file button"), icon: "folder", color: .orange) {
                        viewModel.openFile(item)
                    }
                    ActionButton(title: NSLocalizedString("Open With", comment: "Open with button"), icon: "square.and.arrow.up", color: .purple) {
                        viewModel.openFileWith(item)
                    }
                    ActionButton(title: NSLocalizedString("Show in Folder", comment: "Show in folder button"), icon: "folder.fill", color: .orange) {
                        viewModel.openFolder(item)
                    }
                } else if item.status == .failed {
                    ActionButton(title: "Retry", icon: "arrow.clockwise", color: .green) {
                        viewModel.restartDownload(item)
                    }
                }
            } else {
                if item.status == .completed {
                    ActionButton(title: NSLocalizedString("Open", comment: "Open file button"), icon: "folder", color: .orange) {
                        viewModel.openFile(item)
                    }
                    ActionButton(title: NSLocalizedString("Open With", comment: "Open with button"), icon: "square.and.arrow.up", color: .green) {
                        viewModel.openFileWith(item)
                    }
                    ActionButton(title: NSLocalizedString("Show in Folder", comment: "Show in folder button"), icon: "folder.fill", color: .orange) {
                        viewModel.openFolder(item)
                    }
                } else if item.status == .failed {
                    ActionButton(title: NSLocalizedString("Retry", comment: "Retry download button"), icon: "arrow.clockwise", color: .green) {
                        viewModel.restartDownload(item)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                if item.status == .completed {
                    Button(action: { viewModel.openFile(item) }) {
                        Label("Open File", systemImage: "folder")
                    }
                    Button(action: { viewModel.openFileWith(item) }) {
                        Label("Open With...", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { viewModel.openFolder(item) }) {
                        Label("Show in Folder", systemImage: "folder.fill")
                    }
                    Divider()
                }
                if item.status != .downloading {
                    Button(action: { viewModel.restartDownload(item) }) {
                        Label("Restart Download", systemImage: "arrow.clockwise")
                    }
                    Divider()
                }
                Button(action: { copyToClipboard(item.url) }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
                Button(action: { copyToClipboard(item.fileName) }) {
                    Label("Copy Filename", systemImage: "doc.on.doc")
                }
                Divider()
                Button(action: { viewModel.deleteDownload(item) }) {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundColor(.red)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14.5))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Download Progress View (مصلح ومبسط)
struct DownloadProgressView: View {
    @ObservedObject var item: DownloadItem
    @ObservedObject var viewModel: DownloadManagerViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var displayProgress: Double = 0
    @State private var stableSpeed: Double = 0
    @State private var stableRemainingTime: String = "--:--"
    @State private var lastProgressUpdate: Date = Date()

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text("\(Int(displayProgress * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if item.fileSize > 0 {
                    Text("\(viewModel.formatFileSize(item.downloadedSize)) / \(viewModel.formatFileSize(item.fileSize))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if item.downloadedSize > 0 {
                    Text("\(viewModel.formatFileSize(item.downloadedSize)) downloaded")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    progressColor(for: displayProgress),
                                    progressColor(for: displayProgress).opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0, min(1, displayProgress)))
                        .animation(.easeInOut(duration: 0.3), value: displayProgress)
                    
                    // Shimmer effect فقط عند التحميل النشط
                    if item.status == .downloading && networkMonitor.isConnected && stableSpeed > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0),
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 35)
                            .offset(x: shimmerOffset(for: geometry.size.width))
                            .animation(
                                .linear(duration: 1.5).repeatForever(autoreverses: false),
                                value: item.status == .downloading && networkMonitor.isConnected && stableSpeed > 0
                            )
                            .mask(
                                RoundedRectangle(cornerRadius: 4)
                                    .frame(width: geometry.size.width * max(0, min(1, displayProgress)))
                            )
                    }
                }
            }
            .frame(height: 6)
            .onAppear {
                displayProgress = item.progress
            }
            .onChange(of: item.progress) { newProgress in
                // ✅ إصلاح: منع التحديثات المتضاربة والقفزات المفاجئة
                let now = Date()
                if now.timeIntervalSince(lastProgressUpdate) < 0.1 { // تحديث كل 0.1 ثانية كحد أقصى
                    return
                }
                lastProgressUpdate = now
                
                // ✅ إصلاح: منع القفزات المفاجئة في النسبة المئوية
                let progressDiff = abs(newProgress - displayProgress)
                let isResuming = item.downloadSpeed.contains("Resuming") || 
                                item.downloadSpeed.contains("Connecting") ||
                                item.downloadSpeed.contains("Starting")
                
                // إذا كان الاستئناف وتغير كبير، تجاهل التحديث
                if isResuming && progressDiff > 0.1 && newProgress > displayProgress {
                    print("⚠️ [UI] Skipping suspicious progress jump: \(Int(displayProgress * 100))% -> \(Int(newProgress * 100))%")
                    return
                }
                
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayProgress = newProgress
                }
            }
            
            if item.status == .downloading {
                HStack(spacing: 2.5) {
                    if stableSpeed > 0 && networkMonitor.isConnected {
                        HStack(spacing: 2.5) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("Avg: \(formatSpeed(stableSpeed))")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }
                    Spacer()
                    if stableRemainingTime != "--:--" && stableRemainingTime != "00:00" {
                        HStack(spacing: 7) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("ETA: \(stableRemainingTime)")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal, 2.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        // تحديث دوري مبسط - مرة واحدة فقط
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if item.status == .downloading {
                updateStableData()
            }
        }
        // مراقبة تغييرات السرعة
        .onChange(of: item.downloadSpeed) { _ in
            updateStableData()
        }
        .onChange(of: item.instantSpeed) { _ in
            updateStableData()
        }
    }
    
    private func updateStableData() {
        // ✅ إصلاح: استخدام البيانات من item مباشرة بدلاً من RealTimeSpeedTracker
        DispatchQueue.main.async {
            // استخدام السرعة من item مباشرة
            stableSpeed = item.instantSpeed
            
            // استخدام الوقت المتبقي من item أو حسابه
            if !item.remainingTime.isEmpty && item.remainingTime != "--:--" {
                stableRemainingTime = item.remainingTime
            } else if item.instantSpeed > 0 && item.fileSize > item.downloadedSize {
                let remaining = item.fileSize - item.downloadedSize
                let seconds = Double(remaining) / item.instantSpeed
                stableRemainingTime = formatTime(seconds)
            } else {
                stableRemainingTime = "--:--"
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds.isInfinite || seconds.isNaN || seconds <= 0 {
            return "--:--"
        }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private func progressColor(for progress: Double) -> Color {
        if progress < 0.25 { return .red }
        else if progress < 0.5 { return .orange }
        else if progress < 0.75 { return .yellow }
        else { return .green }
    }

    private func shimmerOffset(for width: CGFloat) -> CGFloat {
        return width * 0.7
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 KB/s" }
        
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
}

// باقي المكونات تبقى كما هي...
// (FileInfoView, MetadataView, ConnectionLostIndicator, ActionsView)


    private func formatSpeed(_ value: Double, isBitsPerSecond: Bool) -> String {
        let bytesPerSecond = isBitsPerSecond ? value / 8.0 : value
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bytesPerSecond / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
        }
    }





