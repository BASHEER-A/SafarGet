import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AddDownloadSheet: View {
    @ObservedObject var viewModel: DownloadManagerViewModel
    @State private var urlText = ""
    @State private var fileName = ""
    @State private var savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
    @State private var availableSpace: String = ""
    @State private var selectedCategory = "All"
    @State private var chunks: Int = 8

    @Environment(\.dismiss) var dismiss

    let categories = ["All", "Video", "Music", "Document", "Archive", "Application"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // File preview + Name
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: iconName(for: urlText))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.blue)
                            if let ext = URL(string: urlText)?.pathExtension.uppercased() {
                                Text(ext)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )

                TextField("File name", text: $fileName)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(true)

                if !sizeString().isEmpty {
                    Text(sizeString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(alignment: .trailing)
                }
            }
            .onChange(of: urlText) { _ in
                updateFileDetails()
            }

            // URL input
            VStack(alignment: .leading, spacing: 6) {
                Text("URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://example.com/file.zip", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            // Category + Save To
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Save To")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        TextField("Save Path", text: $savePath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(minWidth: 200)

                        Button(action: selectDirectory) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Available: \(availableSpace)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .onAppear(perform: updateAvailableDiskSpace)
                }
            }

            Divider()

            // Buttons and Threads Selector Together
            HStack {
                // Threads Selector
                Picker("Threads", selection: $chunks) {
                    Text("8").tag(8)
                    Text("16").tag(16)
                    Text("32").tag(32)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .padding(.trailing, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .animation(.easeInOut, value: chunks)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Text("Cancel")
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .controlSize(.regular)

                Button(action: {
                    let fileType = viewModel.detectFileType(from: urlText)
                    viewModel.addDownload(
                        url: urlText,
                        fileName: fileName.isEmpty ? "Unknown" : fileName,
                        fileType: fileType,
                        savePath: savePath,
                        chunks: chunks,
                        cookiesPath: nil as String?
                    )
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Text("Download")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(urlText.isEmpty ? Color.gray.opacity(0.4) : Color.green.opacity(0.8))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                .disabled(urlText.isEmpty)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            }
            .cornerRadius(16)
        )
        .onAppear {
            // Pre-fill URL and filename if pending
            if !viewModel.pendingURL.isEmpty {
                urlText = viewModel.pendingURL
                viewModel.pendingURL = "" // Clear it
            }
            if !viewModel.pendingFileName.isEmpty {
                fileName = viewModel.pendingFileName
                viewModel.pendingFileName = "" // Clear it
            }
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
            selectedCategory = "Document"
            return
        }
        
        // Only update filename if it's empty or if it was auto-generated
        if fileName.isEmpty || fileName == URL(string: urlText)?.lastPathComponent {
            fileName = url.lastPathComponent
        }

        let ext = url.pathExtension.lowercased()

        switch ext {
        case "mp4", "mov", "avi":
            selectedCategory = "Video"
        case "mp3", "wav", "aac":
            selectedCategory = "Music"
        case "pdf", "doc", "docx", "txt":
            selectedCategory = "Document"
        case "zip", "rar", "7z":
            selectedCategory = "Archive"
        case "dmg", "exe", "apk":
            selectedCategory = "Application"
        default:
            selectedCategory = "Document"
        }
    }

    private func iconName(for url: String) -> String {
        guard let ext = URL(string: url)?.pathExtension.lowercased() else { return "arrow.down.circle" }

        switch ext {
        case "mp4", "mov", "avi":
            return "play.fill"
        case "mp3", "wav", "aac":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx", "txt":
            return "doc.text"
        case "zip", "rar", "7z":
            return "archivebox"
        case "dmg", "exe", "apk":
            return "app"
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
            availableSpace = "830.12GB"
        }
    }
}

// Helper view for macOS blur effect
struct VisualEffectView: NSViewRepresentable {
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
