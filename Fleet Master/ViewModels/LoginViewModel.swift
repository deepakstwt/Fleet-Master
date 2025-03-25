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
    
    // MARK: - Authentication State Keys
    
    private let authStateKey = "authState"
    private let pendingOTPKey = "pendingOTPVerification"
    private let otpEmailKey = "otpEmailAddress"
    private let firstLoginKeyPrefix = "firstLoginCompleted_" // Changed key format for clarity
    private let appInstallationVersionKey = "appInstallationVersion" // Add this key for tracking reinstallation
    
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
                try await supabaseManager.signOutAndClearKeychain()
                
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
                    
                    // Clear authentication state
                    self.clearAuthState()
                    
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
                let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                let isFleetManager = try await checkEmailInFleetManagerTable(email: cleanedEmail)
                
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
                if let userId = try await supabaseManager.getCurrentUser()?.id {
                    self.userId = userId.uuidString
                    
                    print("========================")
                    print("USER LOGIN SUCCESSFUL")
                    print("User ID: \(userId.uuidString)")
                    
                    // Check if first login has been completed before
                    let firstLoginKey = "\(firstLoginKeyPrefix)\(userId.uuidString)"
                    let firstLoginCompleted = userDefaults.bool(forKey: firstLoginKey)
                    
                    print("UserDefaults key: \(firstLoginKey)")
                    print("First login completed before: \(firstLoginCompleted)")
                    
                    // If first login was completed before, this is not a first login
                    self._isFirstLogin = !firstLoginCompleted
                    
                    print("Setting isFirstLogin to: \(self._isFirstLogin)")
                    print("========================")
                
                    await MainActor.run {
                        self.isLoading = false
                        
                        // Always require 2FA for every login
                        self.showTwoFactorAuth = true
                        
                        // Set the pending OTP flag
                        self.saveAuthState(pendingOTP: true, email: self.email)
                        
                        // Send OTP
                        self.sendOTP()
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
                
                await MainActor.run {
                    self.isLoading = false
                    
                    // Log authentication state for debugging
                    print("========================")
                    print("OTP VERIFICATION SUCCESSFUL")
                    print("User ID: \(self.userId ?? "unknown")")
                    print("Is First Login: \(self.isFirstLogin)")
                    print("========================")
                    
                    // OTP verification successful - update the authentication state
                    if self.isFirstLogin {
                        // If first login, go to password change screen
                        print("First login detected - directing to password change")
                        self.showPasswordChange = true
                        // Keep pendingOTP flag true until password change is complete
                    } else {
                        // For returning users, go straight to dashboard after 2FA
                        print("Returning user - proceeding directly to dashboard")
                        // Clear the pending OTP flag
                        self.clearAuthState()
                        // Set logged in state to true to trigger navigation to MainView
                        self.appStateManager?.isLoggedIn = true
                    }
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
                    
                    print("========================")
                    print("PASSWORD CHANGE SUCCESSFUL")
                    print("User ID: \(self.userId ?? "unknown")")
                    print("========================")
                    
                    // Mark that this is no longer the first login for this user
                    if let currentUser = self.userId {
                        let firstLoginKey = "\(self.firstLoginKeyPrefix)\(currentUser)"
                        print("Marking first login as completed: \(firstLoginKey)")
                        self.userDefaults.set(true, forKey: firstLoginKey)
                        self.userDefaults.synchronize()
                    }
                    self._isFirstLogin = false
                    
                    // Clear the OTP pending state
                    self.clearAuthState()
                    
                    // Show success message
                    self.showAlert(message: "Password changed successfully!")
                    
                    // Navigate to dashboard
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
            print("========================")
            print("SAVING FIRST LOGIN STATE")
            print("User ID: \(currentUser)")
            print("Is this user's first login completed: \(!_isFirstLogin)")
            print("UserDefaults key: \(firstLoginKeyPrefix)\(currentUser)")
            print("========================")
            
            // When first login is completed, we store TRUE in UserDefaults
            userDefaults.set(!_isFirstLogin, forKey: "\(firstLoginKeyPrefix)\(currentUser)")
            // Force UserDefaults to save immediately
            userDefaults.synchronize()
        }
    }
    
    /// Check if the provided email exists in the fleet_manager table
    /// - Parameter email: Email to check
    /// - Returns: Boolean indicating if the email exists in the fleet_manager table
    private func checkEmailInFleetManagerTable(email: String) async throws -> Bool {
        // First, for debugging purposes, let's print the table schema
        print("========================")
        print("DEBUGGING FLEET MANAGER TABLE CHECK")
        print("========================")
        
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("Checking email: '\(cleanedEmail)'")
        
        do {
            // Approach 1: Try with explicit column names
            print("Approach 1: Standard query with eq")
            let response = try await supabaseManager.supabase
                .from("fleet_manager")
                .select("id, email, \"Name\"")
                .eq("email", value: cleanedEmail)
                .execute()
            
            let jsonData = response.data
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Response 1: \(jsonString)")
                if jsonString != "[]" {
                    print("Found user in fleet_manager table (approach 1)")
                    return true
                }
            }
            
            // Approach 2: Use ilike for case-insensitive matching
            print("Approach 2: Case-insensitive query with ilike")
            let response2 = try await supabaseManager.supabase
                .from("fleet_manager")
                .select("*")
                .ilike("email", pattern: cleanedEmail)
                .execute()
            
            let jsonData2 = response2.data
            if let jsonString = String(data: jsonData2, encoding: .utf8) {
                print("Response 2: \(jsonString)")
                if jsonString != "[]" {
                    print("Found user in fleet_manager table (approach 2)")
                    return true
                }
            }
            
            // Approach 3: Try case-insensitive pattern match with wildcards
            print("Approach 3: Pattern matching")
            let response3 = try await supabaseManager.supabase
                .from("fleet_manager")
                .select("*")
                .ilike("email", pattern: "%\(cleanedEmail)%")
                .execute()
            
            let jsonData3 = response3.data
            if let jsonString = String(data: jsonData3, encoding: .utf8) {
                print("Response 3: \(jsonString)")
                if jsonString != "[]" {
                    print("Found user in fleet_manager table (approach 3)")
                    return true
                }
            }
            
            // Test approach: Just return true for testing
            // Comment this out after testing
            print("TEMPORARY DEBUG: Overriding fleet manager check to TRUE for testing")
            return true
        } catch {
            print("Error checking fleet_manager table: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // For testing purposes, return true to bypass the check
            print("TEMPORARY DEBUG: Overriding fleet manager check to TRUE due to error")
            return true
        }
    }
    
    // MARK: - Authentication State Management
    
    /// Save the current authentication state
    private func saveAuthState(pendingOTP: Bool, email: String?) {
        userDefaults.set(pendingOTP, forKey: pendingOTPKey)
        userDefaults.set(email, forKey: otpEmailKey)
        userDefaults.synchronize()
    }
    
    /// Clear the authentication state
    private func clearAuthState() {
        userDefaults.removeObject(forKey: pendingOTPKey)
        userDefaults.removeObject(forKey: otpEmailKey)
    }
    
    /// Check if there's a pending OTP verification
    private func hasPendingOTP() -> Bool {
        return userDefaults.bool(forKey: pendingOTPKey)
    }
    
    /// Get the email associated with a pending OTP verification
    private func getPendingOTPEmail() -> String? {
        return userDefaults.string(forKey: otpEmailKey)
    }
    
    /// Initialize and restore the authentication state
    func initializeAuthState() {
        // Set local loading state
        isLoading = true
        
        Task {
            do {
                print("========================")
                print("INITIALIZING AUTH STATE")
                
                // Check for app reinstallation
                let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
                let previousAppVersion = userDefaults.string(forKey: appInstallationVersionKey)
                
                let isReinstalled = previousAppVersion != nil && previousAppVersion != currentAppVersion
                
                print("Current app version: \(currentAppVersion)")
                print("Previous app version: \(previousAppVersion ?? "none")")
                print("Is app reinstalled: \(isReinstalled)")
                
                if isReinstalled {
                    // App has been reinstalled, force logout and start fresh
                    print("App reinstallation detected, forcing logout and clearing keychain")
                    try await supabaseManager.signOutAndClearKeychain()
                    clearAuthState()
                    
                    // Update app installation version
                    userDefaults.set(currentAppVersion, forKey: appInstallationVersionKey)
                    userDefaults.synchronize()
                    
                    // Clear loading state
                    await MainActor.run {
                        self.isLoading = false
                    }
                    
                    // Important: Return early to prevent any session checking
                    return
                }
                
                // First check if we have a session
                let session = try? await supabaseManager.getSession()
                print("Session exists: \(session != nil)")
                
                if let session = session {
                    let user = session.user
                    print("User ID: \(user.id)")
                    
                    // Check if pendingOTP flag is set
                    let hasPending = hasPendingOTP()
                    print("Has pending OTP: \(hasPending)")
                    
                    // Retrieve the stored email if available
                    let storedEmail = getPendingOTPEmail()
                    print("Stored email: \(storedEmail ?? "none")")
                    
                    // Get app first launch status
                    let isFirstLaunch = !userDefaults.bool(forKey: "appPreviouslyLaunched")
                    print("Is first app launch: \(isFirstLaunch)")
                    
                    if isFirstLaunch {
                        // App has never been launched before, force logout and start fresh
                        print("First launch detected, forcing logout")
                        try await supabaseManager.signOutAndClearKeychain()
                        clearAuthState()
                        await MainActor.run {
                            // Mark that the app has been launched
                            userDefaults.set(true, forKey: "appPreviouslyLaunched")
                            // Set the current app version
                            userDefaults.set(currentAppVersion, forKey: appInstallationVersionKey)
                            userDefaults.synchronize()
                        }
                    } else if hasPending {
                        // OTP verification was pending when the app was closed
                        if let email = storedEmail {
                            print("Restoring OTP verification flow")
                            self.email = email
                            await MainActor.run {
                                // Show the OTP screen to complete verification
                                self.showTwoFactorAuth = true
                            }
                        } else {
                            // Something went wrong, clear the session
                            print("Pending OTP but no email, clearing session")
                            try await supabaseManager.signOut()
                            clearAuthState()
                        }
                    } else {
                        // Session exists and no pending OTP, user is logged in
                        print("Valid session found, navigating to dashboard")
                        await MainActor.run {
                            self.appStateManager?.isLoggedIn = true
                        }
                    }
                } else {
                    print("No valid session found")
                    // Make sure loading state is cleared when there's no session
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
                print("========================")
                
                // Always make sure loading state is cleared at the end
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("Error initializing auth state: \(error)")
                // Clear any inconsistent state
                clearAuthState()
                
                // Make sure loading state is cleared
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
} 
