import SwiftUI
import AppKit

// MARK: - SafarGet Pro View
struct SafarGetProView: View {
    @StateObject private var proManager = SafarGetProManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var isSigningIn = false
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if proManager.isLoggedIn {
                accountInfoView
            } else {
                loginView
            }
        }
        .frame(width: 500, height: 600)
        .background(backgroundGradient)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                    
                    Text("SafarGet Pro")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Unlock Premium Features")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Account Info View
    private var accountInfoView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // User Info Card
                userInfoCard
                
                // Subscription Info Card
                subscriptionCard
                
                // Features Card
                featuresCard
                
                // Logout Button
                Button(action: { proManager.logout() }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("Logout")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }
    
    // MARK: - User Info Card
    private var userInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(proManager.userName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(proManager.email)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(glassBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Subscription Card
    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
                
                Text("Subscription Details")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(spacing: 12) {
                InfoRow(icon: "calendar.badge.plus", 
                       title: "Start Date", 
                       value: proManager.subscriptionStartDate)
                
                InfoRow(icon: "calendar.badge.exclamationmark", 
                       title: "End Date", 
                       value: proManager.subscriptionEndDate)
                
                InfoRow(icon: "hourglass", 
                       title: "Days Remaining", 
                       value: "\(proManager.remainingDays) days",
                       valueColor: proManager.remainingDays > 30 ? .green : .orange)
                
                InfoRow(icon: "checkmark.seal.fill", 
                       title: "Status", 
                       value: proManager.isActive ? "Active" : "Expired",
                       valueColor: proManager.isActive ? .green : .red)
            }
        }
        .padding(20)
        .background(glassBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Features Card
    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)
                
                Text("Pro Features")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bolt.fill", text: "Unlimited download speed", isActive: true)
                FeatureRow(icon: "square.stack.3d.up.fill", text: "Unlimited concurrent downloads", isActive: true)
                FeatureRow(icon: "clock.arrow.circlepath", text: "Auto-resume downloads", isActive: true)
                FeatureRow(icon: "lock.shield.fill", text: "Priority support", isActive: true)
                FeatureRow(icon: "sparkles", text: "Advanced features", isActive: true)
            }
        }
        .padding(20)
        .background(glassBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Login View
    private var loginView: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .padding(.top, 40)
            
            Text("Sign in to SafarGet Pro")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            // Login Form
            VStack(spacing: 16) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(GlassTextFieldStyle())
                }
                
                // Password Field
                if isSigningIn {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
                
                // Confirm Password Field (for registration)
                if isRegistering {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        SecureField("Create a password", text: $password)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Action Buttons
            VStack(spacing: 12) {
                if isSigningIn || isRegistering {
                    Button(action: performAction) {
                        HStack {
                            Image(systemName: isSigningIn ? "arrow.right.circle.fill" : "person.badge.plus.fill")
                            Text(isSigningIn ? "Sign In" : "Register")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    
                    Button(action: resetForm) {
                        Text("Cancel")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { isSigningIn = true }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Sign In")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    
                    Button(action: { isRegistering = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus.fill")
                            Text("Create Account")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Functions
    private func performAction() {
        guard !email.isEmpty else {
            showError(message: "Please enter your email")
            return
        }
        
        if isSigningIn {
            guard !password.isEmpty else {
                showError(message: "Please enter your password")
                return
            }
            
            // Perform sign in
            proManager.signIn(email: email, password: password) { success, error in
                if success {
                    resetForm()
                } else {
                    showError(message: error ?? "Sign in failed")
                }
            }
        } else if isRegistering {
            guard !password.isEmpty else {
                showError(message: "Please create a password")
                return
            }
            
            guard password == confirmPassword else {
                showError(message: "Passwords do not match")
                return
            }
            
            // Perform registration
            proManager.register(email: email, password: password) { success, error in
                if success {
                    resetForm()
                } else {
                    showError(message: error ?? "Registration failed")
                }
            }
        }
    }
    
    private func resetForm() {
        isSigningIn = false
        isRegistering = false
        email = ""
        password = ""
        confirmPassword = ""
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.purple.opacity(0.3),
                    Color.blue.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glass effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.5)
        }
    }
    
    private var glassBackground: some View {
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
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Helper Views
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .green : .gray)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Glass Text Field Style
struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

// MARK: - SafarGet Pro Manager
class SafarGetProManager: ObservableObject {
    static let shared = SafarGetProManager()
    
    @Published var isLoggedIn = false
    @Published var userName = ""
    @Published var email = ""
    @Published var subscriptionStartDate = ""
    @Published var subscriptionEndDate = ""
    @Published var remainingDays = 0
    @Published var isActive = false
    
    init() {
        loadUserData()
    }
    
    private func loadUserData() {
        // Load from UserDefaults or Keychain
        if let userData = UserDefaults.standard.dictionary(forKey: "SafarGetProUser") {
            isLoggedIn = userData["isLoggedIn"] as? Bool ?? false
            userName = userData["userName"] as? String ?? ""
            email = userData["email"] as? String ?? ""
            subscriptionStartDate = userData["startDate"] as? String ?? ""
            subscriptionEndDate = userData["endDate"] as? String ?? ""
            
            calculateRemainingDays()
        }
    }
    
    private func calculateRemainingDays() {
        // Calculate remaining days from end date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let endDate = formatter.date(from: subscriptionEndDate) {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
            remainingDays = max(0, days)
            isActive = remainingDays > 0
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For demo purposes
            self.isLoggedIn = true
            self.email = email
            self.userName = email.components(separatedBy: "@").first ?? "User"
            self.subscriptionStartDate = self.formatDate(Date())
            self.subscriptionEndDate = self.formatDate(Date().addingTimeInterval(365 * 24 * 60 * 60))
            self.calculateRemainingDays()
            
            self.saveUserData()
            completion(true, nil)
        }
    }
    
    func register(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For demo purposes
            self.isLoggedIn = true
            self.email = email
            self.userName = email.components(separatedBy: "@").first ?? "User"
            self.subscriptionStartDate = self.formatDate(Date())
            self.subscriptionEndDate = self.formatDate(Date().addingTimeInterval(30 * 24 * 60 * 60)) // 30 days trial
            self.calculateRemainingDays()
            
            self.saveUserData()
            completion(true, nil)
        }
    }
    
    func logout() {
        isLoggedIn = false
        userName = ""
        email = ""
        subscriptionStartDate = ""
        subscriptionEndDate = ""
        remainingDays = 0
        isActive = false
        
        UserDefaults.standard.removeObject(forKey: "SafarGetProUser")
    }
    
    private func saveUserData() {
        let userData: [String: Any] = [
            "isLoggedIn": isLoggedIn,
            "userName": userName,
            "email": email,
            "startDate": subscriptionStartDate,
            "endDate": subscriptionEndDate
        ]
        
        UserDefaults.standard.set(userData, forKey: "SafarGetProUser")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
