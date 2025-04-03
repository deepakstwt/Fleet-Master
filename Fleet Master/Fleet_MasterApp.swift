//
//  Fleet_MasterApp.swift
//  Fleet Master
//
//  Created by Kushagra Kulshrestha on 18/03/25.
//

import SwiftUI
import Security

@main
struct Fleet_MasterApp: App {
    // Create view models at the app level to maintain state
    @StateObject private var driverViewModel = DriverViewModel()
    @StateObject private var maintenanceViewModel = MaintenanceViewModel()
    @StateObject private var vehicleViewModel = VehicleViewModel()
    @StateObject private var tripViewModel = TripViewModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var appStateManager = AppStateManager()
    @State private var showPermissionRequest = false
    
    // Initialize Supabase when the app loads
    init() {
        // Configure Supabase by accessing the shared instance
        // This will ensure it's initialized before it's used
        let supabaseManager = SupabaseManager.shared
        
        // Register default values for UserDefaults
        let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1.0"
        
        // Only set default values if they don't exist yet
        let defaults = UserDefaults.standard
        
        // Check if this is the first time the app is installed
        let isFirstInstall = defaults.object(forKey: "appPreviouslyLaunched") == nil
        
        if isFirstInstall {
            // First time app installation detected
            // Clear any potentially leftover keychain data from previous installations
            supabaseManager.clearKeychainDataSync()
            
            // Also make sure no auth state is preserved
            clearAuthStateInUserDefaults()
            
            // Force immediate session clearing
            Task {
                do {
                    try await supabaseManager.signOut()
                } catch {
                    // Error signing out on first install
                }
            }
        }
        
        if defaults.object(forKey: "appPreviouslyLaunched") == nil {
            defaults.set(false, forKey: "appPreviouslyLaunched")
        }
        
        if defaults.object(forKey: "appInstallationVersion") == nil {
            defaults.set(currentAppVersion, forKey: "appInstallationVersion")
        }
        
        defaults.synchronize()
    }
    
    // Clear all authentication state in UserDefaults
    private func clearAuthStateInUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Clear authentication state keys
        defaults.removeObject(forKey: "pendingOTPVerification")
        defaults.removeObject(forKey: "otpEmailAddress")
        defaults.removeObject(forKey: "authState")
        
        // Clear any keys with login completion status
        for key in defaults.dictionaryRepresentation().keys {
            if key.starts(with: "firstLoginCompleted_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        defaults.synchronize()
        // All auth state removed from UserDefaults
    }
    
    var body: some Scene {
        WindowGroup {
            // Show splash screen while loading, then LoginView or MainView based on authentication state
            if appStateManager.isLoading {
                SplashScreenView()
            } else if appStateManager.isLoggedIn {
                MainView()
                    .environmentObject(driverViewModel)
                    .environmentObject(maintenanceViewModel)
                    .environmentObject(vehicleViewModel)
                    .environmentObject(tripViewModel)
                    .environmentObject(appStateManager)
                    .onAppear {
                        locationManager.requestWhenInUseAuthorization()
                    }
            } else {
                LoginView()
                    .environmentObject(driverViewModel)
                    .environmentObject(maintenanceViewModel)
                    .environmentObject(vehicleViewModel)
                    .environmentObject(tripViewModel)
                    .environmentObject(appStateManager)
                    .onAppear {
                        // Request location permissions when the app launches
                        locationManager.requestWhenInUseAuthorization()
                    }
                    .sheet(isPresented: $showPermissionRequest) {
                        MapPermissionView()
                    }
            }
        }
    }
}
