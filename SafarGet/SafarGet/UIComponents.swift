import SwiftUI

// MARK: - Real Time Speed Display (مع الأنيميشن القديم)
struct RealTimeSpeedDisplay: View {
    @ObservedObject var item: DownloadItem
    let maxSpeed: Double
    let isActive: Bool
    
    @State private var currentSpeed: Double = 0
    @State private var displaySpeedMB: Double = 0
    @State private var displaySpeedKB: Int = 0
    @State private var speedLevel: SpeedLevel = .starting
    @State private var remainingTime: String = "--:--"
    @State private var isInitializing = true
    @State private var smoothedDisplaySpeed: Double = 0
    @State private var lastUpdateTime: Date = Date()
    @State private var updateCooldown: Bool = false
    
    // تحديث سلس وسريع
    private let updateInterval: TimeInterval = 0.2
    private let smoothingFactor: Double = 0.3
    
    enum SpeedLevel {
        case slow, medium, fast, excellent, noConnection, starting
        
        var color: Color {
            switch self {
            case .slow: return .red
            case .medium: return .orange
            case .fast: return .green
            case .excellent: return .purple
            case .noConnection: return .gray
            case .starting: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .slow: return "speedometer"
            case .medium: return "gauge.medium"
            case .fast: return "gauge.high"
            case .excellent: return "flame.fill"
            case .noConnection: return "wifi.slash"
            case .starting: return "arrow.down.circle"
            }
        }
        
        var status: String {
            switch self {
            case .slow: return "Slow"
            case .medium: return "Medium"
            case .fast: return "Fast"
            case .excellent: return "Excellent"
            case .noConnection: return "No Connection"
            case .starting: return "Starting"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Speed Icon with animation
            ZStack {
                Circle()
                    .fill(speedLevel.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(speedLevel.color.opacity(speedLevel == .starting ? 0.5 : 0), lineWidth: 2)
                            .scaleEffect(speedLevel == .starting ? 1.3 : 1.0)
                            .opacity(speedLevel == .starting ? 0 : 1)
                            .animation(
                                speedLevel == .starting 
                                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                                : .easeInOut(duration: 0.3),
                                value: speedLevel == .starting
                            )
                    )
                
                Image(systemName: speedLevel.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(speedLevel.color)
                    .scaleEffect(speedLevel == .starting ? 1.0 : 1.1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: speedLevel)
            }
            
            // Speed & Time Display
            VStack(alignment: .leading, spacing: 1) {
                // السرعة
                HStack(spacing: 2) {
                    Group {
                        if !isActive {
                            Text("Paused")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        } else if currentSpeed > 0 {
                            // عرض السرعة بشكل سلس
                            Text(String(format: "%.2f", displaySpeedMB))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(speedLevel.color)
                                .animation(.easeInOut(duration: 0.2), value: displaySpeedMB)
                            
                            Text("MB/s")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(speedLevel.color.opacity(0.8))
                        } else if item.instantSpeed > 0 {
                            // استخدم السرعة من item إذا لم تكن هناك سرعة من RealTimeSpeedTracker
                            let mbPerSecond = item.instantSpeed / (1024 * 1024)
                            Text(String(format: "%.2f", mbPerSecond))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(speedLevel.color)
                                .animation(.easeInOut(duration: 0.2), value: mbPerSecond)
                            
                            Text("MB/s")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(speedLevel.color.opacity(0.8))
                        } else if item.downloadSpeed.contains("Downloading") {
                            // إذا كانت الحالة "Downloading" ولكن لا توجد سرعة، استخدم سرعة افتراضية
                            Text("0.00")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(speedLevel.color)
                            
                            Text("MB/s")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(speedLevel.color.opacity(0.8))
                        } else {
                            // عرض حالة الاتصال
                            Text(item.downloadSpeed)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // الوقت المتبقي
                if remainingTime != "--:--" && remainingTime != "00:00" && !isInitializing {
                    Text(remainingTime)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                        .animation(.easeInOut(duration: 0.3), value: remainingTime)
                } else {
                    Text(speedLevel.status)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(speedLevel.color.opacity(0.8))
                }
            }
            
            // Speed Bars with smooth animation
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index < getSpeedBars() ? speedLevel.color : Color.gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat(8 + index * 2))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: getSpeedBars())
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(speedLevel.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(speedLevel.color.opacity(0.3), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.3), value: speedLevel)
        )
        .onAppear {
            startSpeedTracking()
        }
        .onChange(of: isActive) { active in
            if !active {
                speedLevel = .noConnection
                currentSpeed = 0
                displaySpeedMB = 0
                displaySpeedKB = 0
                remainingTime = "--:--"
            } else {
                startSpeedTracking()
            }
        }
        .onChange(of: item.status) { _ in
            if item.status == .downloading {
                startSpeedTracking()
            }
        }
        .onChange(of: item.downloadSpeed) { _ in
            // ✅ إصلاح: تحديث فوري عند تغيير الحالة
            DispatchQueue.main.async {
                updateRealTimeSpeed()
            }
        }
        .onChange(of: item.instantSpeed) { _ in
            // ✅ إصلاح: تحديث فوري عند تغيير السرعة
            DispatchQueue.main.async {
                updateRealTimeSpeed()
            }
        }
        // التحديث السلس والمستمر - مرة واحدة فقط
        .onReceive(Timer.publish(every: updateInterval, on: .main, in: .common).autoconnect()) { _ in
            if isActive && !updateCooldown {
                updateRealTimeSpeed()
            }
        }
    }
    
    private func startSpeedTracking() {
        isInitializing = true
        speedLevel = .starting
        
        // إعادة تعيين RealTimeSpeedTracker
        RealTimeSpeedTracker.shared.reset(for: item.id)
        
        // ✅ إصلاح: تحديث فوري
        DispatchQueue.main.async {
            updateRealTimeSpeed()
        }
        
        // تقليل وقت الانتظار الابتدائي - أسرع استجابة
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // إذا وصل progress أو السرعة، أخرج من isInitializing فوراً
            if item.progress > 0.01 || currentSpeed > 0 || !item.downloadSpeed.contains("Connecting") {
                isInitializing = false
                updateRealTimeSpeed()
            }
        }
        
        // فحص دوري أسرع
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isInitializing || currentSpeed > 0 {
                timer.invalidate()
                return
            }
            
            if item.downloadSpeed != "Connecting..." && 
               item.downloadSpeed != "Starting..." &&
               item.downloadSpeed != "Resuming..." {
                isInitializing = false
                updateRealTimeSpeed()
                timer.invalidate()
            }
        }
    }
    
    private func updateRealTimeSpeed() {
        // ✅ إصلاح: استخدام البيانات من item مباشرة
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) < 0.1 { // تحديث كل 0.1 ثانية كحد أقصى
            return
        }
        lastUpdateTime = now
        
        // ✅ إصلاح: استخدام السرعة من item مباشرة بدلاً من RealTimeSpeedTracker
        if item.instantSpeed > 0 {
            currentSpeed = item.instantSpeed
            isInitializing = false
            print("✅ Using item.instantSpeed: \(item.instantSpeed)")
        } else if currentSpeed > 0 {
            // احتفظ بالسرعة السابقة فقط إذا لم تكن هناك سرعة جديدة
            print("🔍 Keeping previous speed: \(currentSpeed)")
            isInitializing = false
        }
        
        // ✅ إصلاح: إذا كانت الحالة "Downloading" ولكن لا توجد سرعة، اخرج من حالة التهيئة
        if item.downloadSpeed.contains("Downloading") && isInitializing {
            isInitializing = false
        }
        
        // Smooth the display speed
        let mbPerSecond = currentSpeed / (1024 * 1024)
        
        if smoothedDisplaySpeed == 0 {
            smoothedDisplaySpeed = mbPerSecond
        } else {
            // ✅ إصلاح: تحديث السرعة المعروضة بشكل صحيح
            let speedDiff = abs(mbPerSecond - smoothedDisplaySpeed)
            if speedDiff > 0.01 { // تحديث فقط إذا كان الفرق كبير
                smoothedDisplaySpeed = smoothedDisplaySpeed * (1 - smoothingFactor) + mbPerSecond * smoothingFactor
                print("🔄 Updating display speed: \(smoothedDisplaySpeed) MB/s")
            }
        }
        
        // Update display values with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            displaySpeedMB = smoothedDisplaySpeed
            displaySpeedKB = Int((smoothedDisplaySpeed - floor(smoothedDisplaySpeed)) * 100)
        }
        
        // Update speed level with smooth transition
        updateSpeedLevel(mbPerSecond: smoothedDisplaySpeed)
        
        // ✅ إصلاح: استخدام البيانات من item مباشرة
        if !item.remainingTime.isEmpty && item.remainingTime != "--:--" {
            remainingTime = item.remainingTime
        } else if item.instantSpeed > 0 && item.fileSize > item.downloadedSize {
            let remaining = item.fileSize - item.downloadedSize
            let seconds = Double(remaining) / item.instantSpeed
            remainingTime = formatTime(seconds)
        } else {
            remainingTime = "--:--"
        }
        
        // إذا حصلنا على سرعة حقيقية، تأكد من الخروج من حالة التهيئة
        if currentSpeed > 0 && isInitializing {
            isInitializing = false
        }
        
        // Debug logging for connection states (reduced frequency)
        if item.downloadSpeed.contains("Connecting") || 
           item.downloadSpeed.contains("Resuming") ||
           item.downloadSpeed.contains("Starting") {
            // Only log every 5 seconds to reduce spam significantly
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) > 5.0 {
                print("🔍 Speed Display - Current: \(currentSpeed), Display: \(smoothedDisplaySpeed), Status: \(item.downloadSpeed)")
                lastUpdateTime = now
            }
        }
    }
    
    private func updateSpeedLevel(mbPerSecond: Double) {
        let newLevel: SpeedLevel
        
        if mbPerSecond == 0 {
            newLevel = isInitializing ? .starting : .slow
        } else if mbPerSecond < 0.5 {
            newLevel = .slow
        } else if mbPerSecond < 2 {
            newLevel = .medium
        } else if mbPerSecond < 10 {
            newLevel = .fast
        } else {
            newLevel = .excellent
        }
        
        if newLevel != speedLevel {
            withAnimation(.easeInOut(duration: 0.3)) {
                speedLevel = newLevel
            }
        }
    }
    
    private func getSpeedBars() -> Int {
        if speedLevel == .noConnection || speedLevel == .starting { return 0 }
        
        let mbPerSecond = smoothedDisplaySpeed
        
        if mbPerSecond < 0.1 { return 1 }
        else if mbPerSecond < 0.5 { return 2 }
        else if mbPerSecond < 2 { return 3 }
        else if mbPerSecond < 5 { return 4 }
        else { return 5 }
    }
    
    // ✅ دالة مساعدة لاستخراج السرعة من النص
    private func extractSpeedFromString(_ speedString: String) -> Double? {
        // البحث عن أرقام في النص
        let patterns = [
            "([0-9.]+)\\s*MB/s",
            "([0-9.]+)\\s*KB/s",
            "([0-9.]+)\\s*B/s"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: speedString.utf16.count)
                if let match = regex.firstMatch(in: speedString, options: [], range: range) {
                    if match.numberOfRanges > 1,
                       let speedRange = Range(match.range(at: 1), in: speedString) {
                        let speedValue = String(speedString[speedRange])
                        if let speed = Double(speedValue) {
                            // تحويل إلى bytes per second
                            if pattern.contains("MB/s") {
                                return speed * 1024 * 1024
                            } else if pattern.contains("KB/s") {
                                return speed * 1024
                            } else {
                                return speed
                            }
                        }
                    }
                }
            }
        }
        
        // إذا كان النص يحتوي على "Slow"، استخدم سرعة افتراضية
        if speedString.contains("Slow") {
            return 1024.0 // 1 KB/s
        }
        
        return nil
    }
    
    // ✅ دالة مساعدة لتنسيق الوقت
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
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isHovered ? color.opacity(0.2) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(isHovered ? 0.6 : 0.3), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Control Button
struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 20, height: 20)
                .background(isHovered ? color.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


