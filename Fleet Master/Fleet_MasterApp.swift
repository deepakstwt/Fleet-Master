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
    @State private var showPermissionRequest = false
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(driverViewModel)
                .environmentObject(maintenanceViewModel)
                .environmentObject(vehicleViewModel)
                .environmentObject(tripViewModel)
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
