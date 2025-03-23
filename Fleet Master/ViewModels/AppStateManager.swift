import SwiftUI
import Combine
import UIKit

class AppStateManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoggedIn = false
    @Published var isLoading = false
    
    // MARK: - Private Properties
    
    private let supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Check if there's an existing session when the app starts
        checkSession()
        
        // Setup notification handling for app state changes
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Checks if there's an active session and updates the isLoggedIn state
    func checkSession() {
        isLoading = true
        
        Task {
            do {
                if (try await supabaseManager.getSession()) != nil {
                    // Session exists, assume it's valid
                    // Note: In a production app, you should validate the token properly
                    await MainActor.run {
                        self.isLoggedIn = true
                        self.isLoading = false
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
                try await supabaseManager.signOut()
                
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
