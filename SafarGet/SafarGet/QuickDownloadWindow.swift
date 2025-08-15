import SwiftUI
import AppKit

// MARK: - File Category Enum
enum FileCategory: String, CaseIterable {
    case autoDetect = "All"
    case video = "Video"
    case music = "Music"
    case document = "Document"
    case archive = "Archive"
    case application = "Application"
    case image = "Image"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .autoDetect: return "wand.and.stars"
        case .video: return "play.fill"
        case .music: return "music.note"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .application: return "app"
        case .image: return "photo.fill"
        case .other: return "arrow.down.circle"
        }
    }
}

// MARK: - Quick Download Window Controller
class QuickDownloadWindowController: NSWindowController {
    static let shared = QuickDownloadWindowController()
    private var viewModel: DownloadManagerViewModel?
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        window.title = "Add Download"
        window.isMovable = true
    }
    
    func show(with viewModel: DownloadManagerViewModel) {
        self.viewModel = viewModel
        guard let window = window else { return }
        
        let contentView = QuickDownloadView(viewModel: viewModel) {
            self.close()
        }
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.level = .floating
    }
}

// MARK: - Quick Download View
struct QuickDownloadView: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var urlText = ""
    @State private var fileName = ""
    @State private var savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    @State private var availableSpace: String = ""
    @State private var selectedCategory: FileCategory = .autoDetect
    @State private var chunks: Int = 8
    @State private var isAnimating = false
    
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // File preview + Name
            filePreviewSection
            
            // URL input
            urlInputSection
            
            // Category + Save To
            categoryAndSaveSection
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Buttons and Threads Selector Together
            actionSection
        }
        .padding(24)
        .frame(width: 520)
        .background(liquidGlassBackground)
        .scaleEffect(isAnimating ? 1.0 : 0.95)
        .opacity(isAnimating ? 1.0 : 0)
        .onAppear {
            setupInitialData()
            updateAvailableDiskSpace()
            animateAppearance()
        }
        .onChange(of: urlText) { _ in
            updateFileDetails()
        }
    }
    
    private var filePreviewSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // File Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.6),
                            Color.purple.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: iconName(for: urlText))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                        
                        if let ext = URL(string: urlText)?.pathExtension.uppercased() {
                            Text(ext)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            TextField("File name", text: $fileName)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(true)
                .foregroundColor(.black)
            
            if !sizeString().isEmpty {
                Text(sizeString())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .frame(alignment: .trailing)
            }
        }
    }
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
            
            TextField("https://example.com/file.mp4", text: $urlText)
                .textFieldStyle(LiquidGlassTextFieldStyle())
                .font(.system(size: 13, weight: .bold))
        }
    }
    
    private var categoryAndSaveSection: some View {
        HStack(alignment: .top, spacing: 32) {
            // Category Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                
                Menu {
                    ForEach(FileCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                if selectedCategory == category {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedCategory.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(selectedCategory.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(liquidGlassButton)
                    .cornerRadius(6)
                }
                .frame(width: 140)
                .menuStyle(.borderlessButton)
            }
            
            // Save To Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Save To")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                
                HStack(spacing: 6) {
                    TextField("Save Path", text: $savePath)
                        .textFieldStyle(LiquidGlassTextFieldStyle())
                        .font(.system(size: 13, weight: .bold))
                        .frame(minWidth: 200)
                    
                    Button(action: selectDirectory) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.black)
                            .padding(6)
                            .background(liquidGlassButton)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Available: \(availableSpace)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
            }
        }
    }
    
    private var actionSection: some View {
        HStack {
            // Threads Selector - Simplified structure
            threadsSelector
            
            Spacer()
            
            // Cancel Button
            cancelButton
            
            // Download Button
            downloadButton
        }
    }
    






private var threadsSelector: some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("Threads")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.primary.opacity(0.7))
            .padding(.leading, 2)
        
        HStack(spacing: 6) {
            ForEach([8, 16, 32], id: \.self) { threadCount in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        chunks = threadCount
                    }
                }) {
                    Text("\(threadCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(chunks == threadCount ? .white : Color.primary.opacity(0.8))
                        .frame(width: 40, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(chunks == threadCount ? Color.accentColor : Color.clear)
                                .shadow(color: chunks == threadCount ? Color.accentColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.1))
                .blur(radius: 0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}

    



    private var cancelButton: some View {
    Button(action: onClose) {
        Text("Cancel")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.gray.opacity(0.8))
            .frame(minWidth: 100)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.windowBackgroundColor).opacity(0.5))
                    .blur(radius: 0.5)
            )
    }
    .buttonStyle(PlainButtonStyle())
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
    )
}

private var downloadButton: some View {
    Button(action: startDownload) {
        Text("Download")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(minWidth: 120)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 10, x: 0, y: 4)
            )
    }
    .buttonStyle(PlainButtonStyle())
    .opacity(urlText.isEmpty ? 0.5 : 1.0)
    .disabled(urlText.isEmpty)
}












// MARK: - Liquid Glass Styles
private var liquidGlassBackground: some View {
    ZStack {
        // 🌌 خلفية بتدرج ألوان نيون عصري
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.3), // أزرق نيون
                Color(red: 0.8, green: 0.2, blue: 1.0).opacity(0.3), // بنفسجي نيون
                Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.3)  // وردي نيون
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blur(radius: 20) // ضبابية قوية لإحساس الزجاج
        
        // ✨ تأثير زجاجي بعمق
        QuickDownloadVisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .opacity(0.75) // شفافية زجاجية

        // 💎 لمعان ناعم (Light Glow Layer)
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.15),
                Color.clear,
                Color.white.opacity(0.1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.overlay)
        
        // 🌟 إضاءة ناعمة حول الإطار
        RoundedRectangle(cornerRadius: 25)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.7),
                        Color.purple.opacity(0.7),
                        Color.pink.opacity(0.7)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
            .shadow(color: Color.blue.opacity(0.4), radius: 10, x: 0, y: 0)
            .shadow(color: Color.purple.opacity(0.4), radius: 20, x: 0, y: 0)
    }
    .cornerRadius(25) // حواف عصرية ناعمة
    .shadow(
        color: Color.black.opacity(0.4),
        radius: 30,
        x: 0,
        y: 15
    ) // ظل عائم أنيق
}
    private var liquidGlassButton: some View {
        ZStack {
            Color.white.opacity(0.1)
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private var activeLiquidGlassButton: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Color.white.opacity(0.1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var downloadButtonGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.8),
                    Color.blue.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Color.white.opacity(0.1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Functions
    private func setupInitialData() {
        if !viewModel.pendingURL.isEmpty {
            urlText = viewModel.pendingURL
            viewModel.pendingURL = ""
        }
        if !viewModel.pendingFileName.isEmpty {
            fileName = viewModel.pendingFileName
            viewModel.pendingFileName = ""
        }
    }
    
    private func animateAppearance() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isAnimating = true
        }
    }
    
    private func sizeString() -> String {
        if urlText.contains("loyaltyfreemusic.com") {
            return "321.09 MB"
        }
        return ""
    }
    
    private func updateFileDetails() {
        guard let url = URL(string: urlText) else {
            if fileName.isEmpty {
                fileName = ""
            }
            selectedCategory = .document
            return
        }
        
        if fileName.isEmpty || fileName == URL(string: urlText)?.lastPathComponent {
            fileName = url.lastPathComponent
        }
        
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "mp4", "mov", "avi", "mkv", "webm":
            selectedCategory = .video
        case "mp3", "wav", "aac", "flac", "m4a":
            selectedCategory = .music
        case "pdf", "doc", "docx", "txt", "rtf":
            selectedCategory = .document
        case "zip", "rar", "7z", "tar", "gz":
            selectedCategory = .archive
        case "dmg", "exe", "apk", "app":
            selectedCategory = .application
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            selectedCategory = .image
        default:
            selectedCategory = .other
        }
    }
    
    private func iconName(for url: String) -> String {
        guard let ext = URL(string: url)?.pathExtension.lowercased() else { return "arrow.down.circle" }
        
        switch ext {
        case "mp4", "mov", "avi", "mkv", "webm":
            return "play.fill"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx", "txt", "rtf":
            return "doc.text"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox"
        case "dmg", "exe", "apk", "app":
            return "app"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo"
        default:
            return "arrow.down.circle"
        }
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            savePath = url.path
            updateAvailableDiskSpace()
        }
    }
    
    private func updateAvailableDiskSpace() {
        let path = savePath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            let gb = Double(available) / 1_073_741_824
            availableSpace = String(format: "%.2f GB", gb)
        } else {
            availableSpace = "830.12 GB"
        }
    }
    
    private func startDownload() {
        let fileType = selectedCategory == .autoDetect ? 
            viewModel.detectFileType(from: urlText) : 
            DownloadItem.FileType(rawValue: selectedCategory.rawValue) ?? .other
        
        viewModel.addDownload(
            url: urlText,
            fileName: fileName.isEmpty ? "Unknown" : fileName,
            fileType: fileType,
            savePath: savePath,
            chunks: chunks,
            cookiesPath: nil
        )
        
        withAnimation(.easeOut(duration: 0.3)) {
            isAnimating = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onClose()
        }
    }
}

// MARK: - Liquid Glass Text Field Style
struct LiquidGlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Color.white.opacity(0.1)
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(.black)
    }
}

// MARK: - Visual Effect View with unique name
struct QuickDownloadVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
