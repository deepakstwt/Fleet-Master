import SwiftUI
import Combine
import UIKit

class AppStateManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoggedIn = false
    @Published var isLoading = true
    
    // MARK: - Private Properties
    
    private let supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Always start with loading = true
        isLoading = true
        
        // Immediately check for reinstallation before any session checks
        if detectAndHandleReinstallation() {
            // If reinstallation detected, we've already reset the login state
            // Set loading to false to show login screen
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.isLoading = false
            }
        } else {
            // Only check for existing session if no reinstallation detected
            checkSession()
        }
        
        // Setup notification handling for app state changes
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Detects if app has been reinstalled and handles clearing credentials
    /// Returns true if reinstallation was detected and handled
    func detectAndHandleReinstallation() -> Bool {
        // Check for app reinstallation
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let previousAppVersion = UserDefaults.standard.string(forKey: "appInstallationVersion")
        let isReinstalled = previousAppVersion != nil && previousAppVersion != currentAppVersion
        
        print("AppStateManager - Current app version: \(currentAppVersion)")
        print("AppStateManager - Previous app version: \(previousAppVersion ?? "none")")
        print("AppStateManager - Is app reinstalled: \(isReinstalled)")
        
        if isReinstalled {
            // App has been reinstalled, force logout immediately
            print("AppStateManager - App reinstallation detected, forcing logout")
            
            // Synchronously clear keychain to ensure it happens before any session checks
            supabaseManager.clearKeychainDataSync()
            
            // Clear any auth state in UserDefaults
            let pendingOTPKey = "pendingOTPVerification"
            let otpEmailKey = "otpEmailAddress"
            UserDefaults.standard.removeObject(forKey: pendingOTPKey)
            UserDefaults.standard.removeObject(forKey: otpEmailKey)
            
            // Update the stored version
            UserDefaults.standard.set(currentAppVersion, forKey: "appInstallationVersion")
            UserDefaults.standard.synchronize()
            
            // Also launch an async task to ensure proper signout from server
            Task {
                do {
                    try await supabaseManager.signOutAndClearKeychain()
                } catch {
                    print("Error during reinstall signout: \(error)")
                }
            }
            
            return true
        }
        
        return false
    }
    
    /// Checks if there's an active session and updates the isLoggedIn state
    func checkSession() {
        isLoading = true
        
        Task {
            do {
                if (try await supabaseManager.getSession()) != nil {
                    // Session exists, but we need to check if OTP verification is pending
                    // This prevents users from bypassing 2FA by closing and reopening the app
                    
                    let pendingOTPKey = "pendingOTPVerification"
                    let isPendingOTP = UserDefaults.standard.bool(forKey: pendingOTPKey)
                    
                    if isPendingOTP {
                        // We have a session but OTP verification is pending
                        // The LoginViewModel will handle showing the OTP screen
                        await MainActor.run {
                            self.isLoggedIn = false
                            self.isLoading = false
                        }
                    } else {
                        // Session exists and no pending OTP
                        await MainActor.run {
                            self.isLoggedIn = true
                            self.isLoading = false
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoggedIn = false
                        self.isLoading = false
                    }
                }
            } catch {
                print("Session check failed: \(error)")
                await MainActor.run {
                    self.isLoggedIn = false
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Signs out the current user
    func signOut() {
        isLoading = true
        
        Task {
            do {
                try await supabaseManager.signOutAndClearKeychain()
                
                await MainActor.run {
                    self.isLoggedIn = false
                    self.isLoading = false
                }
            } catch {
                print("Sign out failed: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up notification handlers for app state changes
    private func setupNotifications() {
        // Handle app returning from background
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                // Set loading to true immediately
                DispatchQueue.main.async {
                    self?.isLoading = true
                }
                // Then check session
                self?.checkSession()
            }
            .store(in: &cancellables)
        
        // Handle app going to background
//        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
//            .sink { [weak self] _ in
//                // This is a good place to perform cleanup if needed
//            }
//            .store(in: &cancellables)
    }
} 
