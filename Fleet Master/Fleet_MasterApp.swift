//
//  Fleet_MasterApp.swift
//  Fleet Master
//
//  Created by Kushagra Kulshrestha on 18/03/25.
//

import SwiftUI

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
        _ = SupabaseManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            // Show LoginView or MainView based on authentication state
            if appStateManager.isLoggedIn {
                MainView()
                    .environmentObject(driverViewModel)
                    .environmentObject(maintenanceViewModel)
                    .environmentObject(vehicleViewModel)
                    .environmentObject(tripViewModel)
                    .environmentObject(appStateManager)
                    .onAppear {
                        locationManager.requestLocationPermission()
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
                        locationManager.requestLocationPermission()
                    }
                    .sheet(isPresented: $showPermissionRequest) {
                        MapPermissionView()
                    }
            }
        }
    }
}
