import SwiftUI
import UniformTypeIdentifiers


// MARK: - Torrent Files Sheet
struct TorrentFilesSheet: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var savePath = "~/Downloads"
    @State private var torrentStatus: TorrentStatus = .new
    @State private var existingDownload: DownloadItem? = nil
    @State private var startDownloadingWhenAdded = true
    @State private var dontShowDialogAgain = false
    @State private var availableDiskSpace: Int64 = 0
    @State private var totalDiskSpace: Int64 = 0
    @Environment(\.dismiss) var dismiss

    enum TorrentStatus {
        case new
        case complete(size: Int64)
        case incomplete(downloaded: Int64, total: Int64)
        case existingDownload(item: DownloadItem)

        var isComplete: Bool { if case .complete = self { return true }; return false }
        var isIncomplete: Bool { if case .incomplete = self { return true }; return false }
        var isNew: Bool { if case .new = self { return true }; return false }
    }

    // Helper functions
    private func getSelectedFilesCount() -> Int {
        return viewModel.currentTorrentFiles.filter { $0.isSelected }.count
    }
    
    private func getSelectedFilesSize() -> Int64 {
        return viewModel.currentTorrentFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    private func getTotalFilesSize() -> Int64 {
        return viewModel.currentTorrentFiles.reduce(0) { $0 + $1.size }
    }
    
    private func getDiskSpacePercentage() -> Double {
        guard totalDiskSpace > 0 else { return 0 }
        return Double(availableDiskSpace) / Double(totalDiskSpace) * 100
    }
    
    private func getHasEnoughSpace() -> Bool {
        return availableDiskSpace > getSelectedFilesSize()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Add New Torrent")
                .font(.title2)
                .padding(.top, 8)
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    TorrentInfoCard(
                        torrentInfo: viewModel.currentTorrentInfo ?? DownloadManagerViewModel.TorrentInfo(
                            name: URL(fileURLWithPath: viewModel.pendingTorrentURL).deletingPathExtension().lastPathComponent,
                            peersCount: 0,
                            seedsCount: 0,
                            totalSize: getTotalFilesSize(),
                            filesCount: viewModel.currentTorrentFiles.count
                        ),
                        formatFileSize: viewModel.formatFileSize
                    )
                    DiskSpaceInfoView(
                        availableSpace: availableDiskSpace,
                        totalSpace: totalDiskSpace,
                        percentage: getDiskSpacePercentage(),
                        hasEnoughSpace: getHasEnoughSpace(),
                        formatFileSize: viewModel.formatFileSize
                    )
                    TorrentFilesTableView(
                        files: $viewModel.currentTorrentFiles,
                        selectedCount: getSelectedFilesCount(),
                        selectedSize: getSelectedFilesSize(),
                        totalSize: getTotalFilesSize(),
                        isComplete: torrentStatus.isComplete,
                        formatFileSize: viewModel.formatFileSize
                    )
                    DownloadLocationView(
                        savePath: $savePath,
                        onSavePathChange: {
                            checkTorrentStatus()
                            updateDiskSpace()
                        }
                    )
                    TorrentOptionsView(
                        startDownloading: $startDownloadingWhenAdded,
                        dontShowAgain: $dontShowDialogAgain
                    )
                }
                .padding(20)
            }
            Divider()
            TorrentActionButtons(
                torrentStatus: torrentStatus,
                hasSelectedFiles: !viewModel.currentTorrentFiles.filter { $0.isSelected }.isEmpty,
                hasEnoughSpace: getHasEnoughSpace(),
                onCancel: { dismiss() },
                onAction: { action in
                    handleAction(action)
                }
            )
        }
        .frame(width: 500, height: 620)
        .onAppear {
            checkTorrentStatus()
            updateDiskSpace()
            if torrentStatus.isNew {
                for i in 0..<viewModel.currentTorrentFiles.count {
                    viewModel.currentTorrentFiles[i].isSelected = true
                }
            }
        }
    }

    private func handleAction(_ action: TorrentAction) {
        switch action {
        case .resume(let item):
            viewModel.resumeDownload(item)
            dismiss()
        case .add, .redownload:
            // Fixed: Added the missing 'resume' parameter
            viewModel.startTorrentDownloadProcess(
                url: viewModel.pendingTorrentURL,
                savePath: savePath,
                resume: false, // Added missing parameter
                forceNew: true
            )
            dismiss()
        case .start(let isResume):
            // Fixed: Added the missing 'resume' parameter
            viewModel.startTorrentDownloadProcess(
                url: viewModel.pendingTorrentURL,
                savePath: savePath,
                resume: isResume, // Added missing parameter
                forceNew: true
            )
            dismiss()
        }
    }

    private func checkTorrentStatus() {
        if let existing = viewModel.downloads.first(where: {
            $0.url == viewModel.pendingTorrentURL && $0.savePath == savePath
        }) {
            torrentStatus = .existingDownload(item: existing)
            existingDownload = existing
            return
        }
        let result = viewModel.checkExistingTorrent(url: viewModel.pendingTorrentURL, savePath: savePath)
        switch result {
        case .complete(let size): torrentStatus = .complete(size: size)
        case .incomplete(let downloaded, let total): torrentStatus = .incomplete(downloaded: downloaded, total: total)
        case .notExists: torrentStatus = .new
        }
    }

    private func updateDiskSpace() {
        let expandedPath = NSString(string: savePath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        do {
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            availableDiskSpace = Int64(values.volumeAvailableCapacity ?? 0)
            totalDiskSpace = Int64(values.volumeTotalCapacity ?? 0)
        } catch {
            availableDiskSpace = 100 * 1024 * 1024 * 1024
            totalDiskSpace = 500 * 1024 * 1024 * 1024
        }
    }
}

// MARK: - Enhanced Torrent Info Card
struct TorrentInfoCard: View {
    let torrentInfo: DownloadManagerViewModel.TorrentInfo
    let formatFileSize: (Int64) -> String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    if torrentInfo.peersCount > 0 || torrentInfo.seedsCount > 0 {
                        Circle()
                            .stroke(Color.green.opacity(0.6), lineWidth: 2)
                            .frame(width: 54, height: 54)
                            .opacity(0.8)
                            .scaleEffect(1.1)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: torrentInfo.peersCount)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(torrentInfo.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                            Text("\(torrentInfo.filesCount) File\(torrentInfo.filesCount == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.purple)
                            Text(formatFileSize(torrentInfo.totalSize))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(torrentInfo.peersCount) Peers")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        if torrentInfo.peersCount > 0 {
                            Text("Connected")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                        } else {
                            Text("Searching...")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(torrentInfo.seedsCount) Seeds")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        
                        if torrentInfo.seedsCount > 0 {
                            Text("Available")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        } else {
                            Text("None found")
                                .font(.system(size: 9))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                HealthIndicator(
                    peersCount: torrentInfo.peersCount,
                    seedsCount: torrentInfo.seedsCount
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Health Indicator
struct HealthIndicator: View {
    let peersCount: Int
    let seedsCount: Int
    
    var healthLevel: HealthLevel {
        let total = peersCount + seedsCount
        
        if total == 0 { return .poor }
        else if total < 5 { return .fair }
        else if total < 20 { return .good }
        else { return .excellent }
    }
    
    enum HealthLevel {
        case poor, fair, good, excellent
        
        var color: Color {
            switch self {
            case .poor: return .red
            case .fair: return .orange
            case .good: return .yellow
            case .excellent: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .poor: return "exclamationmark.triangle.fill"
            case .fair: return "minus.circle.fill"
            case .good: return "checkmark.circle.fill"
            case .excellent: return "star.fill"
            }
        }
        
        var description: String {
            switch self {
            case .poor: return "Poor"
            case .fair: return "Fair"
            case .good: return "Good"
            case .excellent: return "Excellent"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: healthLevel.icon)
                .font(.system(size: 10))
                .foregroundColor(healthLevel.color)
            
            Text(healthLevel.description)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(healthLevel.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(healthLevel.color.opacity(0.15))
        .cornerRadius(12)
    }
}

struct DiskSpaceInfoView: View {
    let availableSpace: Int64
    let totalSpace: Int64
    let percentage: Double
    let hasEnoughSpace: Bool
    let formatFileSize: (Int64) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("Disk Space")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Text("\(formatFileSize(availableSpace)) available of \(formatFileSize(totalSpace))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.separatorColor).opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(percentage > 20 ? Color.blue : Color.orange)
                        .frame(width: geometry.size.width * (1 - percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
            
            if !hasEnoughSpace {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Not enough disk space for selected files")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(10)
    }
}

struct TorrentFilesTableView: View {
    @Binding var files: [DownloadManagerViewModel.TorrentFile]
    let selectedCount: Int
    let selectedSize: Int64
    let totalSize: Int64
    let isComplete: Bool
    let formatFileSize: (Int64) -> String
    
    var body: some View {
        VStack(spacing: 0) {
            TorrentFilesHeader(
                filesCount: files.count,
                allSelected: selectedCount == files.count,
                onSelectAll: { selectAll in
                    for i in 0..<files.count {
                        files[i].isSelected = selectAll
                    }
                }
            )
            
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                        TorrentFileRowView(
                            file: file,
                            index: index,
                            totalSize: totalSize,
                            isComplete: isComplete,
                            formatFileSize: formatFileSize,
                            onToggle: {
                                if let fileIndex = files.firstIndex(where: { $0.id == file.id }) {
                                    files[fileIndex].isSelected.toggle()
                                }
                            }
                        )
                        
                        if index < files.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
            .frame(height: 250)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            
            TorrentFilesFooter(
                selectedCount: selectedCount,
                totalCount: files.count,
                selectedSize: selectedSize,
                formatFileSize: formatFileSize,
                onSelectAll: {
                    for i in 0..<files.count {
                        files[i].isSelected = true
                    }
                },
                onSelectNone: {
                    for i in 0..<files.count {
                        files[i].isSelected = false
                    }
                }
            )
        }
        .cornerRadius(8)
    }
}

struct TorrentFilesHeader: View {
    let filesCount: Int
    let allSelected: Bool
    let onSelectAll: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { allSelected },
                    set: { onSelectAll($0) }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .scaleEffect(0.9)
                
                Text("File Name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("(\(filesCount) files)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            
            Text("Size")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .trailing)
                .padding(.trailing, 16)
        }
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct TorrentFileRowView: View {
    let file: DownloadManagerViewModel.TorrentFile
    let index: Int
    let totalSize: Int64
    let isComplete: Bool
    let formatFileSize: (Int64) -> String
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { file.isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .scaleEffect(0.9)
                .disabled(isComplete)
                
                Image(systemName: FileHelper.icon(for: file.name))
                    .font(.system(size: 16))
                    .foregroundColor(FileHelper.color(for: file.name))
                    .frame(width: 24, height: 24)
                    .background(FileHelper.color(for: file.name).opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(file.name)
                    
                    HStack(spacing: 12) {
                        Text(FileHelper.type(for: file.name))
                            .font(.system(size: 11))
                            .foregroundColor(FileHelper.color(for: file.name))
                        
                        if !file.path.isEmpty && file.path != file.name {
                            Text(file.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Text("#\(file.index)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.separatorColor).opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatFileSize(file.size))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(Int(Double(file.size) / Double(totalSize) * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .trailing)
            .padding(.trailing, 16)
        }
        .frame(minHeight: 48)
        .background(
            Group {
                if file.isSelected {
                    Color.accentColor.opacity(0.15)
                } else if index % 2 == 0 {
                    Color(NSColor.controlBackgroundColor).opacity(0.2)
                } else {
                    Color.clear
                }
            }
        )
        .onTapGesture {
            onToggle()
        }
    }
}

struct TorrentFilesFooter: View {
    let selectedCount: Int
    let totalCount: Int
    let selectedSize: Int64
    let formatFileSize: (Int64) -> String
    let onSelectAll: () -> Void
    let onSelectNone: () -> Void
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                
                Text("\(selectedCount) of \(totalCount) file\(selectedCount == 1 ? "" : "s") selected")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: onSelectAll) {
                    Text("Select All")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: onSelectNone) {
                    Text("Select None")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                Text(formatFileSize(selectedSize))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

struct DownloadLocationView: View {
    @Binding var savePath: String
    let onSavePathChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("Download Location")
                    .font(.system(size: 14, weight: .medium))
            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("", text: $savePath)
                        .textFieldStyle(.plain)
                        .disabled(true)
                        .onChange(of: savePath) { _ in
                            onSavePathChange()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                
                Button(action: selectDirectory) {
                    Text("Browse...")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        
        if panel.runModal() == .OK, let url = panel.url {
            savePath = url.path
        }
    }
}

struct TorrentOptionsView: View {
    @Binding var startDownloading: Bool
    @Binding var dontShowAgain: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $startDownloading) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    
                    Text("Start downloading when torrent is added")
                        .font(.system(size: 14))
                }
            }
            .toggleStyle(CheckboxToggleStyle())
            
            Toggle(isOn: $dontShowAgain) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("Don't show this dialog next time I add a torrent")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(CheckboxToggleStyle())
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        .cornerRadius(8)
    }
}

enum TorrentAction {
    case resume(DownloadItem)
    case add
    case redownload
    case start(isResume: Bool)
}

struct TorrentActionButtons: View {
    let torrentStatus: TorrentFilesSheet.TorrentStatus
    let hasSelectedFiles: Bool
    let hasEnoughSpace: Bool
    let onCancel: () -> Void
    let onAction: (TorrentAction) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            
            Button(NSLocalizedString("Cancel", comment: "Cancel button"), action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.escape)
            
            if case .existingDownload(let item) = torrentStatus {
                if item.status == .downloading || item.status == .paused {
                    Button(action: { onAction(.resume(item)) }) {
                        Label(NSLocalizedString("Resume", comment: "Resume download button"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                } else {
                    Button(action: { onAction(.add) }) {
                        Label(NSLocalizedString("Add", comment: "Add download button"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                }
            } else if torrentStatus.isComplete {
                Button(action: { onAction(.redownload) }) {
                    Label(NSLocalizedString("Re-download", comment: "Re-download button"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            } else {
                Button(action: { onAction(.start(isResume: torrentStatus.isIncomplete)) }) {
                    Label(torrentStatus.isIncomplete ? NSLocalizedString("Resume", comment: "Resume download button") : NSLocalizedString("Add", comment: "Add download button"),
                          systemImage: torrentStatus.isIncomplete ? "play.fill" : "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
                .disabled(!hasSelectedFiles || !hasEnoughSpace)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Helpers
struct FileHelper {
    static func icon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov", "wmv":
            return "play.rectangle.fill"
        case "mp3", "wav", "flac", "aac":
            return "music.note"
        case "jpg", "jpeg", "png", "gif", "bmp":
            return "photo"
        case "pdf":
            return "doc.text.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "exe", "dmg", "pkg", "app":
            return "app"
        case "txt", "doc", "docx":
            return "doc.text"
        default:
            return "doc"
        }
    }
    
    static func color(for filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov", "wmv":
            return .purple
        case "mp3", "wav", "flac", "aac":
            return .pink
        case "jpg", "jpeg", "png", "gif", "bmp":
            return .green
        case "pdf":
            return .red
        case "zip", "rar", "7z", "tar", "gz":
            return .orange
        case "exe", "dmg", "pkg", "app":
            return .blue
        default:
            return .secondary
        }
    }
    
    static func type(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm":
            return "Video File"
        case "mp3", "wav", "flac", "aac", "m4a", "ogg":
            return "Audio File"
        case "jpg", "jpeg", "png", "gif", "bmp", "svg", "webp":
            return "Image File"
        case "pdf":
            return "PDF Document"
        case "doc", "docx":
            return "Word Document"
        case "xls", "xlsx":
            return "Excel Spreadsheet"
        case "ppt", "pptx":
            return "PowerPoint"
        case "txt":
            return "Text File"
        case "zip", "rar", "7z", "tar", "gz":
            return "Archive"
        case "exe":
            return "Windows Executable"
        case "dmg":
            return "macOS Disk Image"
        case "pkg":
            return "Package File"
        case "app":
            return "Application"
        case "iso":
            return "Disk Image"
        case "srt", "sub", "ass":
            return "Subtitle File"
        default:
            return ext.isEmpty ? "File" : "\(ext.uppercased()) File"
        }
    }
}

// Enhanced Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                .imageScale(.medium)
                .animation(.easeInOut(duration: 0.1), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
        }
    }
}

