import SwiftUI
import Supabase

class LoginViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var email = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var showNewPassword = false
    @Published var showConfirmPassword = false
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var otpDigits = Array(repeating: "", count: 6)
    @Published var focusedOTPDigit = 0
    @Published var resendTimer = 0
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var showTwoFactorAuth = false
    @Published var showPasswordChange = false
    @Published var navigateToMainView = false
    
    // MARK: - Private Properties
    
    private var timer: Timer?
    private let otpLength = 6
    private let resendCooldown = 30 // seconds
    private let supabaseManager = SupabaseManager.shared
    private let userDefaults = UserDefaults.standard
    
    // MARK: - External References
    
    var appStateManager: AppStateManager?
    
    // MARK: - Private Properties (additional)
    
    private var _isFirstLogin = true
    private var userId: String? = nil
    
    // MARK: - Computed Properties
    
    var isFirstLogin: Bool {
        get {
            return _isFirstLogin
        }
        set {
            _isFirstLogin = newValue
            saveFirstLoginState()
        }
    }
    
    var isValidInput: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    var isValidOTP: Bool {
        otpDigits.joined().count == otpLength
    }
    
    var isValidNewPassword: Bool {
        let password = newPassword
        let hasMinLength = password.count >= 8
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecialChar = password.contains(where: { !$0.isLetter && !$0.isNumber })
        
        return hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar && password == confirmPassword
    }
    
    // MARK: - Public Methods
    
    func signOut() {
        isLoading = true
        
        Task {
            do {
                try await supabaseManager.signOut()
                
                await MainActor.run {
                    self.isLoading = false
                    // Clear navigation flags
                    self.navigateToMainView = false
                    self.showPasswordChange = false
                    self.showTwoFactorAuth = false
                    
                    // Clear form fields
                    self.email = ""
                    self.password = ""
                    self.newPassword = ""
                    self.confirmPassword = ""
                    self.otpDigits = Array(repeating: "", count: 6)
                    
                    // Update app state
                    self.appStateManager?.isLoggedIn = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showAlert(message: "Sign out failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func login() {
        guard isValidInput else {
            showAlert(message: "Please enter valid email and password")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // First check if email exists in fleet_manager table
                let isFleetManager = try await checkEmailInFleetManagerTable(email: email)
                
                if !isFleetManager {
                    await MainActor.run {
                        self.isLoading = false
                        self.showAlert(message: "Access denied: This email is not registered as a fleet manager.")
                    }
                    return
                }
                
                // Try to sign in with password first
                _ = try await supabaseManager.signIn(email: email, password: password)
                
                // Check if the user is signed in
                    // Get the user ID and check if it's their first login
                    if let userId = try await supabaseManager.getCurrentUser()?.id {
                        self.userId = userId.uuidString
                        // Check if this is the first login for this user
                        self._isFirstLogin = !userDefaults.bool(forKey: "isFirstLogin_\(userId.uuidString)")
                    
                    await MainActor.run {
                        self.isLoading = false
                        
                        // Check if this is the first login to decide flow
                        if self.isFirstLogin {
                            // First login: proceed with 2FA and then password change
                            self.showTwoFactorAuth = true
                            self.sendOTP()
                        } else {
                            // Not first login: go straight to main view
                            self.appStateManager?.isLoggedIn = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showAlert(message: "Login failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func sendOTP() {
        isLoading = true
        
        Task {
            do {
                try await supabaseManager.sendOTP(email: email)
                
                await MainActor.run {
                    self.isLoading = false
                    self.startResendTimer()
                    self.showAlert(message: "OTP sent to your email")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showAlert(message: "Failed to send OTP: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func resendOTP() {
        guard resendTimer == 0 else { return }
        sendOTP()
    }
    
    func verifyOTP() {
        guard isValidOTP else {
            showAlert(message: "Please enter a valid OTP")
            return
        }
        
        isLoading = true
        
        let otpCode = otpDigits.joined()
        
        Task {
            do {
                _ = try await supabaseManager.verifyOTP(email: email, token: otpCode)
                
                // Check if verification was successful
                    await MainActor.run {
                        self.isLoading = false
                        
                        // For this example, we'll always show password change after successful 2FA
                        // You might want to check if password change is required here in a real app
                        self.showPasswordChange = true
                    }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showAlert(message: "OTP verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func changePassword() {
        guard isValidNewPassword else {
            showAlert(message: "Please ensure all password requirements are met")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await supabaseManager.updatePassword(password: newPassword)
                
                await MainActor.run {
                    self.isLoading = false
                    // Set isFirstLogin to false after successful password change
                    self._isFirstLogin = false
                    self.saveFirstLoginState()
                    // Update app-wide authentication state
                    self.appStateManager?.isLoggedIn = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.showAlert(message: "Failed to change password: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startResendTimer() {
        resendTimer = resendCooldown
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.resendTimer > 0 {
                self.resendTimer -= 1
            } else {
                self.timer?.invalidate()
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func saveFirstLoginState() {
        if let currentUser = userId {
            userDefaults.set(!_isFirstLogin, forKey: "isFirstLogin_\(currentUser)")
        }
    }
    
    /// Check if the provided email exists in the fleet_manager table
    /// - Parameter email: Email to check
    /// - Returns: Boolean indicating if the email exists in the fleet_manager table
    private func checkEmailInFleetManagerTable(email: String) async throws -> Bool {
        do {
            let response = try await supabaseManager.supabase
                .from("fleet_manager")
                .select("email")
                .eq("email", value: email.lowercased())
                .execute()
            
            // Parse the response
            let jsonData = response.data
            
            // Decode to extract the count of matching records
            struct FleetManager: Decodable {
                let email: String
            }
            
            let decoder = JSONDecoder()
            let managers = try decoder.decode([FleetManager].self, from: jsonData)
            
            // If we found at least one record matching the email, return true
            return !managers.isEmpty
        } catch {
            print("Error checking fleet manager email: \(error)")
            throw error
        }
    }
    
    deinit {
        timer?.invalidate()
    }
} 
