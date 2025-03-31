import SwiftUI
import MapKit
import CoreLocation

// Note: RouteInformation is defined in Models/Trip.swift

// Wrapper for CLLocationCoordinate2D to make it Equatable
struct LocationWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: LocationWrapper, rhs: LocationWrapper) -> Bool {
        let tolerance: Double = 0.000001
        return abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < tolerance &&
               abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < tolerance
    }
}

struct MapLocation: Identifiable {
    var id = UUID()
    let coordinate: CLLocationCoordinate2D
    var isOrigin: Bool = false
}

struct AddTripView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showRoutePreview = false
    @State private var formProgress: CGFloat = 0.0
    @State private var selectedSection = 0
    @State private var animateGradient = false
    @State private var showVehicleSelector = false
    @State private var showDriverSelector = false
    
    // Location selection states
    @State private var showStartLocationPicker = false
    @State private var showEndLocationPicker = false
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    
    private let sections = ["Trip Details", "Assignment", "Additional Info"]
    private let accentGradient = LinearGradient(
        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Compute qualified drivers based on selected vehicle type
    private var qualifiedDrivers: [Driver] {
        guard let vehicleId = tripViewModel.vehicleId,
              let vehicle = vehicleViewModel.getVehicleById(vehicleId) else {
            return [] // No vehicle selected, no qualified drivers
        }
        
        // Get the required vehicle category based on vehicle type
        let requiredCategory = vehicle.vehicleType.rawValue
        
        // Filter drivers who have the required certification
        return driverViewModel.drivers.filter { driver in
            driver.isActive && 
            driver.isAvailable && 
            driver.vehicleCategories.contains(requiredCategory)
        }
    }
    
    // Animation timing
    @State private var animateTabs = false
    
    var body: some View {
        NavigationStack {
            mainContent
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
                        animateTabs = true
                    }
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        animateGradient = true
                    }
                }
        }
        .preferredColorScheme(colorScheme)
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            
            // Content area with TabView
            ZStack(alignment: .bottom) {
            formContentSection
                
                // Only show floating navigation buttons when not on the first section
                if selectedSection > 0 {
                    floatingBackButton
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .fullScreenCover(isPresented: $showRoutePreview) {
            ZStack {
                // Full-screen map with Apple Maps style
                Color.white.edgesIgnoringSafeArea(.all)
                
                RouteMapFullScreenView(
                    startLocation: tripViewModel.startLocation,
                    endLocation: tripViewModel.endLocation,
                    onDismiss: {
                        showRoutePreview = false
                    },
                    onConfirm: {
                        tripViewModel.addRouteInfoToTrip()
                        showRoutePreview = false
                    }
                )
                .edgesIgnoringSafeArea(.all)
            }
            .ignoresSafeArea(.all)
        }
        .background(
            colorScheme == .dark ?
                Color(.systemBackground) :
                Color(.systemGroupedBackground)
        )
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Progress bar
        ProgressBar(value: formProgress)
                .frame(height: 6)
            .padding(.horizontal)
                .padding(.top, 8)
            
            // Tabs with animation
            sectionTabsView
                .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
    }
    
    private var sectionTabsView: some View {
                        HStack {
            ForEach(0..<sections.count, id: \.self) { index in
                sectionTab(for: index)
                if index < sections.count - 1 { Spacer() }
            }
        }
        .padding(.horizontal)
        .opacity(animateTabs ? 1 : 0)
        .offset(y: animateTabs ? 0 : 10)
    }
    
    private func sectionTab(for index: Int) -> some View {
        VStack(spacing: 8) {
            Text(sections[index])
                .font(.system(size: 14, weight: selectedSection == index ? .bold : .medium))
                .foregroundColor(selectedSection == index ? .primary : .secondary)
            
            ZStack {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                if selectedSection == index {
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]), 
                                startPoint: animateGradient ? .leading : .trailing,
                                endPoint: animateGradient ? .trailing : .leading
                            )
                        )
                        .frame(height: 4)
                        .transition(.scale)
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSection = index
                updateProgress()
            }
        }
    }
    
    private var formContentSection: some View {
        TabView(selection: $selectedSection) {
            tripDetailsSection
                .tag(0)
            
            assignmentSection
                .tag(1)
            
            descriptionSection
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: selectedSection) { _, _ in
            withAnimation(.spring()) {
                updateProgress()
            }
        }
    }
    
    private var tripDetailsSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Animated header card with gradient
                headerCard
                
                // Main form fields with elevation and improved visuals
                VStack(spacing: 24) {
                    // Title field with icon
                    formField(
                        icon: "car.fill",
                        iconColor: .blue,
                        content: {
                    FloatingTextField(title: "Trip Title", text: $tripViewModel.title)
                        .transition(.move(edge: .leading))
                        }
                    )
                    
                    // Location Group
                    VStack(spacing: 0) {
                        Text("ROUTE INFORMATION")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            Divider()
                            .padding(.horizontal, 16)
                        
                        // Start location field
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                            .padding(.leading, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter starting point", text: $tripViewModel.startLocation)
                                    .font(.system(size: 16))
                            }
                            .padding(.vertical, 16)
                            
                            Spacer()
                            
                            Button(action: {
                                showStartLocationPicker = true
                            }) {
                                Image(systemName: "map")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                        }
                        
                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 16)
                        
                        // Route connector
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 2)
                                .padding(.leading, 34)
                            
                            Spacer()
                        }
                        .frame(height: 24)
                        
                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 16)
                        
                        // End location field
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                            }
                            .padding(.leading, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End Location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter destination", text: $tripViewModel.endLocation)
                                    .font(.system(size: 16))
                            }
                            .padding(.vertical, 16)
                            
                            Spacer()
                            
                            Button(action: {
                                showEndLocationPicker = true
                            }) {
                                Image(systemName: "map")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                    )
                    
                    // Route info section (if available) with improved visualization
                    routeInfoSectionCard
                    
                    // Time Selection Group
                    VStack(spacing: 0) {
                        Text("TIME SCHEDULE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // Start time
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                            }
                            .padding(.leading, 16)
                            
                            ModernDatePicker(title: "Scheduled Start", selection: $tripViewModel.scheduledStartTime)
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 12)
                            
                            Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 16)
                        
                        // End time
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "clock.badge.checkmark.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple)
                            }
                            .padding(.leading, 16)
                            
                            ModernDatePicker(title: "Scheduled End", selection: $tripViewModel.scheduledEndTime)
                                .padding(.trailing, 16)
                        }
                        .padding(.vertical, 12)
                        
                        // Show manual distance entry if no route info
                    if tripViewModel.routeInformation == nil {
                            Divider()
                                .padding(.leading, 68)
                                .padding(.trailing, 16)
                            
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "ruler.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange)
                                }
                                .padding(.leading, 16)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Expected Distance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Distance in km", text: Binding<String>(
                                get: { 
                                    if let distance = tripViewModel.distance {
                                        return String(format: "%.1f", distance)
                                    }
                                    return ""
                                },
                                set: { newValue in
                                    tripViewModel.distance = Double(newValue)
                                }
                                    ))
                                    .font(.system(size: 16))
                                .keyboardType(.decimalPad)
                    }
                                .padding(.vertical, 12)
                                
                                Text("km")
                                    .foregroundColor(.secondary)
                                    .padding(.trailing, 16)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                    )
                }
                
                // Continue button
                nextSectionButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .sheet(isPresented: $showStartLocationPicker) {
                LocationSelectionNavigationView(
                    title: "Select Start Location",
                    selectedLocation: $startCoordinate, 
                    address: $tripViewModel.startLocation,
                    onDismiss: {
                        showStartLocationPicker = false
                        // Calculate route if we have both locations
                        if !tripViewModel.startLocation.isEmpty && !tripViewModel.endLocation.isEmpty {
                            tripViewModel.calculateRouteForForm(from: tripViewModel.startLocation, to: tripViewModel.endLocation)
                        }
                    }
                )
            }
            .sheet(isPresented: $showEndLocationPicker) {
                LocationSelectionNavigationView(
                    title: "Select End Location",
                    selectedLocation: $endCoordinate, 
                    address: $tripViewModel.endLocation,
                    onDismiss: {
                        showEndLocationPicker = false
                        // Calculate route if we have both locations
                        if !tripViewModel.startLocation.isEmpty && !tripViewModel.endLocation.isEmpty {
                            tripViewModel.calculateRouteForForm(from: tripViewModel.startLocation, to: tripViewModel.endLocation)
                        }
                    }
                )
            }
        }
    }
    
    private var headerCard: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Schedule New Trip", systemImage: "car.fill")
                        .font(.title2.bold())
                    .foregroundColor(.white)
                    
                Text("Enter the trip details to schedule a new journey")
                        .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
                .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
            )
            .cornerRadius(20)
            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Decorative elements
                                                Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .offset(x: 50, y: 20)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
                .offset(x: 20, y: 50)
        }
        .padding(.top, 16)
    }
    
    private func formField<Content: View>(icon: String, iconColor: Color, content: @escaping () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon with circular background
            ZStack {
                                                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            .padding(.leading, 16)
            
            // Content (typically a text field)
            content()
                .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
                                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private var routeInfoSectionCard: some View {
        Group {
            if tripViewModel.isLoadingRoute {
                loadingRouteCard
            } else if let routeError = tripViewModel.routeError {
                errorRouteCard(message: routeError)
            } else if let routeInfo = tripViewModel.routeInformation {
                successRouteCard(routeInfo: routeInfo)
            } else if !tripViewModel.startLocation.isEmpty && !tripViewModel.endLocation.isEmpty {
                actionRouteCard
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private var loadingRouteCard: some View {
        HStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.3)
                .padding(.leading, 20)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                Text("Calculating Route")
                                                .font(.headline)
                                            
                Text("Estimating distance and travel time...")
                            .font(.caption)
                    .foregroundColor(.secondary)
            }
                                                
                                                Spacer()
                                            }
        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private func errorRouteCard(message: String) -> some View {
        HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .padding(.leading, 16)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                Text("Route Error")
                                                .font(.headline)
                    .foregroundColor(.red)
                                            
                Text(message)
                    .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
            Button(action: {
                tripViewModel.calculateRouteForForm(from: tripViewModel.startLocation, to: tripViewModel.endLocation)
            }) {
                Text("Retry")
                    .font(.caption)
                    .fontWeight(.medium)
                                            .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private func successRouteCard(routeInfo: RouteInformation) -> some View {
        VStack(spacing: 0) {
                            HStack {
                Text("ROUTE SUMMARY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                        
                        Spacer()
                        
                Button(action: {
                    showRoutePreview = true
                }) {
                    Label("View on Map", systemImage: "map")
                            .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            HStack(spacing: 30) {
                // Distance info
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "ruler.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                        
                        Text("Distance")
                            .font(.subheadline)
                                        .foregroundColor(.secondary)
                    }
                                    
                    Text(String(format: "%.1f km", routeInfo.distance / 1000))
                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundColor(.primary)
                                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                // Time info
                VStack(spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                        
                        Text("Duration")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                    }
                                    
                    Text(formatDuration(routeInfo.time))
                        .font(.system(.title3, design: .rounded).bold())
                                        .foregroundColor(.primary)
                                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private var actionRouteCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Calculate Route")
                                                .font(.headline)
                
                Text("Get distance and time estimates for this trip")
                            .font(.caption)
                                                    .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
            Button(action: {
                tripViewModel.calculateRouteForForm(from: tripViewModel.startLocation, to: tripViewModel.endLocation)
            }) {
                Text("Calculate")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
    }
    
    private var nextSectionButton: some View {
                        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSection = 1
                updateProgress()
            }
                        }) {
                            HStack {
                Text("Continue to Assignment")
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
                .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: animateGradient ? .leading : .trailing,
                    endPoint: animateGradient ? .trailing : .leading
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.vertical, 16)
    }
    
    private var floatingBackButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedSection -= 1
                updateProgress()
            }
        }) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Back")
                    .fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.leading, 16)
        .padding(.bottom, 16)
    }
    
    // Helper functions
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
                        } else {
            return "\(minutes) min"
        }
    }
    
    private func updateProgress() {
        formProgress = CGFloat(selectedSection + 1) / CGFloat(sections.count)
    }
    
    private var toolbarContent: some ToolbarContent {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                tripViewModel.resetForm()
                dismiss()
            }
        }
    }
    
    private var assignmentSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Driver & Vehicle Assignment", systemImage: "person.2.fill")
                            .font(.title2.bold())
                                    .foregroundColor(.white)
                        
                        Text("First select a vehicle, then assign a driver")
                                        .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                            startPoint: animateGradient ? .topLeading : .bottomTrailing,
                            endPoint: animateGradient ? .bottomTrailing : .topLeading
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 16)

                // Vehicle selection card
            VStack(spacing: 0) {
                    Text("STEP 1: SELECT VEHICLE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Vehicle Search and List
                    VStack(spacing: 16) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search vehicles...", text: $vehicleSearchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        
                        // Vehicle List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredVehicles) { vehicle in
                        Button(action: {
                                        tripViewModel.vehicleId = vehicle.id
                                    }) {
                                        HStack(spacing: 12) {
                                            // Vehicle Icon
                                            ZStack {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.15))
                                                    .frame(width: 40, height: 40)
                                                
                                                Image(systemName: "car.fill")
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            // Vehicle Details
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(vehicle.make) \(vehicle.model)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                                
                                                Text(vehicle.registrationNumber)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                
                                Spacer()
                                
                                            // Selection indicator
                                            if tripViewModel.vehicleId == vehicle.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                                        .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(tripViewModel.vehicleId == vehicle.id ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 200)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                )
                
                // Driver selection card
                VStack(spacing: 0) {
                    Text("STEP 2: SELECT DRIVER")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Driver Search and List
                    VStack(spacing: 16) {
                        // Search bar
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                            TextField("Search drivers...", text: $driverSearchText)
                .textFieldStyle(PlainTextFieldStyle())
                                .disabled(tripViewModel.vehicleId == nil)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        
                        if tripViewModel.vehicleId == nil {
                            Text("Please select a vehicle first")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            // Driver List
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredDrivers) { driver in
                Button(action: {
                                            tripViewModel.driverId = driver.id
                                        }) {
                                            HStack(spacing: 12) {
                                                // Driver Avatar
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.blue.opacity(0.15))
                                                        .frame(width: 40, height: 40)
                                                    
                                                    Text(String(driver.name.prefix(1)))
                .font(.headline)
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                // Driver Details
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(driver.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                                                    
                                                    Text(driver.phone)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
                                                Spacer()
                                                
                                                // Selection indicator
                                                if tripViewModel.driverId == driver.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                }
                                            }
                                            .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(.systemBackground))
                                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(tripViewModel.driverId == driver.id ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(height: 200)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                )
                
                // Continue button
                        Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedSection = 2
                        updateProgress()
                    }
                        }) {
                            HStack {
                        Text("Continue to Additional Info")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                            startPoint: animateGradient ? .leading : .trailing,
                            endPoint: animateGradient ? .trailing : .leading
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // Add these computed properties at the appropriate scope level
    @State private var vehicleSearchText = ""
    @State private var driverSearchText = ""
    
    private var filteredVehicles: [Vehicle] {
        if vehicleSearchText.isEmpty {
            return vehicleViewModel.activeVehicles
        }
        return vehicleViewModel.activeVehicles.filter { vehicle in
            let searchText = vehicleSearchText.lowercased()
            return vehicle.make.lowercased().contains(searchText) ||
                   vehicle.model.lowercased().contains(searchText) ||
                   vehicle.registrationNumber.lowercased().contains(searchText)
        }
    }
    
    private var filteredDrivers: [Driver] {
        // Only show drivers if vehicle is selected, but don't filter by qualifications
        let availableDrivers = tripViewModel.vehicleId == nil ? [] : driverViewModel.drivers.filter { $0.isActive }
        if driverSearchText.isEmpty {
            return availableDrivers
        }
        return availableDrivers.filter { driver in
            let searchText = driverSearchText.lowercased()
            return driver.name.lowercased().contains(searchText) ||
                   driver.phone.lowercased().contains(searchText)
        }
    }
    
    // Vehicle Selector Sheet
    private var vehicleSelectorSheet: some View {
        NavigationView {
            List {
                            ForEach(vehicleViewModel.activeVehicles) { vehicle in
                                VehicleSelectionCard(
                                    vehicle: vehicle,
                        isSelected: tripViewModel.vehicleId == vehicle.id
                    ) {
                                        tripViewModel.vehicleId = vehicle.id
                        // Clear driver selection when vehicle changes
                        tripViewModel.driverId = nil
                        showVehicleSelector = false
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Select Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showVehicleSelector = false
                    }
                }
            }
        }
    }
    
    // Driver Selector Sheet
    private var driverSelectorSheet: some View {
        NavigationView {
            List {
                if qualifiedDrivers.isEmpty {
                    Text("No qualified drivers available for this vehicle type")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(qualifiedDrivers) { driver in
                        DriverSelectionCard(
                            driver: driver,
                            isSelected: tripViewModel.driverId == driver.id
                        ) {
                            tripViewModel.driverId = driver.id
                            showDriverSelector = false
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Select Qualified Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDriverSelector = false
                    }
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Additional Information", systemImage: "doc.text.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Add notes and description for this trip")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
        .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: animateGradient ? .topLeading : .bottomTrailing,
                            endPoint: animateGradient ? .bottomTrailing : .topLeading
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Decorative elements
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .offset(x: 50, y: 20)
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .offset(x: 20, y: 50)
                }
                .padding(.top, 16)
                
                // Description text editor
                VStack(spacing: 0) {
                    Text("TRIP DESCRIPTION")
                        .font(.caption)
                        .fontWeight(.semibold)
                .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $tripViewModel.description)
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                )
                
                // Notes text editor
                VStack(spacing: 0) {
                    Text("TRIP NOTES")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "note.text")
                                .font(.system(size: 18))
                                .foregroundColor(.yellow)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes (Optional)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $tripViewModel.notes)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                )
                
                // Submit button
        Button(action: {
                    let vm = tripViewModel
                    vm.addTrip()
                    dismiss()
                }) {
                    HStack {
            Text("Schedule Trip")
                            .fontWeight(.semibold)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: animateGradient ? .leading : .trailing,
                            endPoint: animateGradient ? .trailing : .leading
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Custom UI Components

struct ProgressBar: View {
    let value: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                
                Rectangle()
                    .foregroundColor(.blue)
                    .frame(width: geometry.size.width * value)
            }
            .cornerRadius(4)
        }
    }
}

struct FloatingTextField: View {
    let title: String
    @Binding var text: String
    var format: FloatingPointFormatStyle<Double>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let format = format {
                TextField(title, value: Binding(
                    get: { Double(text) ?? 0 },
                    set: { text = String($0) }
                ), format: format)
                .textFieldStyle(ModernTextFieldStyle())
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(ModernTextFieldStyle())
            }
        }
    }
}

struct LocationInputField: View {
    let title: String
    @Binding var text: String
    @State private var showMap = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            
            Button(action: { showMap = true }) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text(text.isEmpty ? "Select Location" : text)
                        .foregroundColor(text.isEmpty ? .gray : .primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .fullScreenCover(isPresented: $showMap) {
                AppleStyleMapView(
                    selectedLocation: $selectedLocation,
                                   address: $text, 
                                   title: title,
                    onDismiss: { showMap = false }
                )
            }
        }
    }
}

// Refined Apple Maps style full-screen view
struct AppleStyleMapView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    let title: String
    var onDismiss: () -> Void
    
    @StateObject private var locationManager = LocationManager()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Map state
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var annotations: [MapLocation] = []
    @State private var isDraggingMap = false
    @State private var showCenterPin = true
    @State private var mapCenterPinScale: CGFloat = 1.0
    
    // Search state
    @State private var searchText = ""
    @StateObject private var searchCompleter = MapSearch()
    @State private var showSearchResults = false
    @State private var isLoadingLocation = false
    @State private var wrappedLocation: LocationWrapper?
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Map layer - take up the entire screen
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            userTrackingMode: .constant(.follow),
            annotationItems: annotations) { location in
            MapMarker(coordinate: location.coordinate, tint: .red)
        }
        .mapStyle(.standard)
                .ignoresSafeArea()
                .gesture(mapDragGesture)
                .onTapGesture {
                    handleMapTap()
                }
            
                // Top Apple Maps style search bar
                VStack(spacing: 0) {
                    // Search bar at top with Cancel/Done buttons
                HStack {
                        Button(action: {
                            dismiss()
                            onDismiss()
                        }) {
                            Text("Cancel")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text("Select \(title)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            saveAndDismiss()
                        }) {
                            Text("Done")
                                    .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .edgesIgnoringSafeArea(.top)
                    )
                    
                    // Search input field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                        TextField("Search Maps", text: $searchText, onCommit: {
                            performSearch()
                        })
                    .padding(10)
                    .onChange(of: searchText) { _, newValue in
                        withAnimation {
                                showSearchResults = !newValue.isEmpty && newValue.count > 2
                            searchCompleter.update(queryFragment: newValue)
                            searchCompleter.update(with: region)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation {
                            searchText = ""
                            showSearchResults = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    // Search results
                    if showSearchResults {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(searchCompleter.locationResults, id: \.self) { location in
                Button {
                    handleLocationSelection(location)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(location.subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
                .background(Color.white)
                
                if searchCompleter.locationResults.last != location {
                    Divider()
                        .padding(.leading, 48)
                                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(10)
                        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                        .frame(height: min(300, CGFloat(searchCompleter.locationResults.count * 60)))
                    }
                    
                    Spacer()
                }
                
                // Side controls
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
            
            VStack(spacing: 16) {
                            // 3D Button
                            Button(action: {}) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    
                                    Text("3D")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Compass
                            Button(action: {}) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    
                                    Image(systemName: "location.north.line.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.black)
                                }
                            }
                            
                            // Current location
                            Button(action: {
                                requestCurrentLocation()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    
                                    Image(systemName: isLoadingLocation ? "arrow.clockwise" : "location.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 100 : 120)
                    }
                }
                
                // Center pin
                if showCenterPin {
                    VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 32))
                        .foregroundColor(.red)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                            )
                            .scaleEffect(mapCenterPinScale)
                            .shadow(radius: 3)
                            .offset(y: isDraggingMap ? 0 : -15)
                            .animation(.spring(response: 0.3), value: isDraggingMap)
                        
                        // Shadow element
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 10, height: 3)
                            .offset(y: -10)
                    }
                }
                
                // Bottom action card - Apple Maps style
                VStack {
                    Spacer()
                    
                    // Action card
                    VStack(spacing: 0) {
                        // Drag handle
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 36, height: 5)
                            .padding(.vertical, 6)
                        
                        if let location = wrappedLocation {
                            // Location icon and pin
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: "mappin")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 8)
                            
                            // Location address
                            if !address.isEmpty {
                                Text(address)
                                    .font(.system(size: 16))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                                    .padding(.bottom, 8)
                            }
                            
                            Divider()
                                .padding(.horizontal, 24)
                            
                    // Action buttons
                            HStack(spacing: 0) {
                                // Confirm Button
                                Button(action: saveAndDismiss) {
                            VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16))
                                    .foregroundColor(.green)
                                        }
                                
                                Text("Confirm")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        .frame(maxWidth: .infinity)
                                }
                        
                                // Share Button
                        Button(action: {}) {
                            VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                            
                                Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                        }
                                
                                Text("Share")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                                }
                        
                                // Save Button
                        Button(action: {}) {
                            VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 36, height: 36)
                                            
                                Image(systemName: "bookmark")
                                                .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                        }
                                
                                Text("Save")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                        } else {
                            Text("Move the map to select a location")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding()
                        }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 16)
                }
            }
            .onAppear {
                if let location = selectedLocation {
                    wrappedLocation = LocationWrapper(coordinate: location)
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                    updateAddressFromLocation(location)
                } else {
                    requestCurrentLocation()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Gestures and Actions
    
    private var mapDragGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                if !isDraggingMap {
                    withAnimation(.spring(response: 0.3)) {
                        isDraggingMap = true
                        showCenterPin = true
                        mapCenterPinScale = 1.2
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    isDraggingMap = false
                    mapCenterPinScale = 1.0
                }
                
                // Use the center of the map as the selected location
                let location = region.center
                wrappedLocation = LocationWrapper(coordinate: location)
                updateAddressFromLocation(location)
            }
    }
    
    private func handleMapTap() {
        // Show the center pin
        withAnimation(.spring(response: 0.3)) {
            showCenterPin = true
            mapCenterPinScale = 1.3
        }
        
        // Animate back down after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) {
                mapCenterPinScale = 1.0
            }
            
            // Use the center of the map as the selected location
            let location = region.center
            wrappedLocation = LocationWrapper(coordinate: location)
            updateAddressFromLocation(location)
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func saveAndDismiss() {
        if let location = wrappedLocation?.coordinate {
            selectedLocation = location
            onDismiss()
            dismiss()
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleLocationSelection(_ location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        
        withAnimation {
            isLoadingLocation = true
            showSearchResults = false
            searchText = location.title
        }
        
        search.start { response, error in
            withAnimation {
                isLoadingLocation = false
            }
            
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            withAnimation(.spring(response: 0.5)) {
                wrappedLocation = LocationWrapper(coordinate: coordinate)
                
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
            
            address = "\(location.title), \(location.subtitle)"
        }
    }
    
    private func updateAddressFromLocation(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        withAnimation {
            isLoadingLocation = true
        }
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            withAnimation {
                isLoadingLocation = false
            }
            
            guard let placemark = placemarks?.first else { return }
            
            address = [
                placemark.name,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode,
                placemark.country
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        }
    }
    
    private func requestCurrentLocation() {
        Task {
            withAnimation(.easeInOut) {
                isLoadingLocation = true
            }
            
            do {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
                
                if let location = try? await locationManager.requestLocation() {
                    withAnimation {
                        wrappedLocation = LocationWrapper(coordinate: location.coordinate)
                        
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                    
                    updateAddressFromLocation(location.coordinate)
                }
            } 
            
            withAnimation {
                isLoadingLocation = false
            }
        }
    }
    
    private func performSearch() {
        if searchText.count >= 2 {
            showSearchResults = true
        }
    }
}

struct RouteInfoCard: View {
    let routeInfo: RouteInformation
    let onPreviewTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Label(
                        title: { Text("Distance: \(String(format: "%.1f", routeInfo.distance / 1000)) km") },
                        icon: { Image(systemName: "car.fill").foregroundColor(.blue) }
                    )
                    
                    Label(
                        title: { Text("Time: \(formatDuration(routeInfo.time))") },
                        icon: { Image(systemName: "clock.fill").foregroundColor(.blue) }
                    )
                }
                
                Spacer()
                
                Button(action: onPreviewTap) {
                    Image(systemName: "map.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
}

struct LoadingView: View {
    let text: String
    
    var body: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text(text)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}

struct DriverSelectionCard: View {
    let driver: Driver
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray)
                        .frame(width: 50, height: 50)
                    
                    Text(String(driver.name.prefix(1)))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(driver.name)
                        .font(.headline)
                    
                    Text(driver.phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        
                        Text("License: \(driver.licenseNumber)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VehicleSelectionCard: View {
    let vehicle: Vehicle
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(getVehicleColor(type: vehicle.vehicleType))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: getVehicleIcon(type: vehicle.vehicleType))
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                    
                    Text(vehicle.registrationNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Label("Type: \(vehicle.vehicleType.rawValue)", systemImage: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(vehicle.isActive ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text(vehicle.isActive ? "Available" : "Unavailable")
                            .font(.caption2)
                            .foregroundColor(vehicle.isActive ? .green : .orange)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getVehicleColor(type: String) -> Color {
        switch type.lowercased() {
        case "sedan":
            return .blue
        case "suv":
            return .green
        case "truck":
            return .orange
        case "van":
            return .purple
        default:
            return .gray
        }
    }
    
    private func getVehicleIcon(type: String) -> String {
        switch type.lowercased() {
        case "sedan":
            return "car.fill"
        case "suv":
            return "car.fill"
        case "truck":
            return "truck.box.fill"
        case "van":
            return "van.fill"
        default:
            return "car.fill"
        }
    }
    
    private func getVehicleColor(type: VehicleType) -> Color {
        switch type {
        case .lmvTr:
            return .blue
        case .mgv, .hmv, .hgmv:
            return .green
        case .htv, .hpmv:
            return .orange
        case .psv, .trans:
            return .purple
        }
    }
    
    private func getVehicleIcon(type: VehicleType) -> String {
        return type.icon
    }
}

struct MapLocationPicker: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // India's center
        span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
    )
    @State private var searchText = ""
    @StateObject private var searchCompleter = MapSearch()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText)
                .padding()
                .onChange(of: searchText) { newValue in
                    searchCompleter.searchTerm = newValue
                }
            
            // Search results
            if !searchCompleter.searchTerm.isEmpty {
                List(searchCompleter.locationResults, id: \.self) { location in
                    Button {
                        handleLocationSelection(location)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(location.title)
                                .foregroundColor(.primary)
                            Text(location.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Map
            Map(coordinateRegion: $region,
                annotationItems: selectedLocation.map { [MapLocation(coordinate: $0)] } ?? []) { location in
                MapMarker(coordinate: location.coordinate)
            }
            .gesture(
                DragGesture()
                    .onEnded { _ in
                        updateAddressFromLocation(region.center)
                    }
            )
        }
    }
    
    private func handleLocationSelection(_ location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            selectedLocation = coordinate
            region.center = coordinate
            address = "\(location.title), \(location.subtitle)"
        }
    }
    
    private func updateAddressFromLocation(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else { return }
            address = [
                placemark.name,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode,
                placemark.country
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
            selectedLocation = coordinate
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search location...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

class MapSearch: NSObject, ObservableObject {
    @Published var locationResults: [MKLocalSearchCompletion] = []
    @Published var searchTerm = ""
    
    private var completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )
        
        completer.queryFragment = ""
    }
    
    func update(with region: MKCoordinateRegion) {
        completer.region = region
    }
    
    func update(queryFragment: String) {
        if queryFragment.count > 2 {
            completer.queryFragment = queryFragment
        } else {
            locationResults = []
        }
    }
}

extension MapSearch: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        locationResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
    }
}

struct ModernDatePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            DatePicker(title,
                      selection: $selection,
                      displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
}

struct ModernTextEditor: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $text)
                .frame(minHeight: 100)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
}

struct ModernPicker<T: Identifiable, Content: View>: View {
    let title: String
    @Binding var selection: T.ID?
    let options: [T]
    let optionLabel: (T) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker(title, selection: $selection) {
                Text("Unassigned").tag(nil as T.ID?)
                ForEach(options) { option in
                    optionLabel(option).tag(option.id as T.ID?)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

#Preview {
    AddTripView()
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 

// Add a navigation wrapper for the location selection view
struct LocationSelectionNavigationView: View {
    let title: String
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        LocationSelectionView(
            selectedLocation: $selectedLocation,
            address: $address,
            title: title,
            locationManager: LocationManager(),
            onConfirm: {
                onDismiss()
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
        .ignoresSafeArea()
    }
}

// Add the new Apple Maps style full-screen route map view
struct RouteMapFullScreenView: View {
    let startLocation: String
    let endLocation: String
    let onDismiss: () -> Void
    let onConfirm: () -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var route: MKRoute?
    @State private var isLoadingRoute = true
    @State private var routeError: String?
    @State private var annotations: [MapLocation] = []
    
    var body: some View {
        ZStack {
            // Map layer
            Map(coordinateRegion: $region,
                annotationItems: annotations) { location in
                MapMarker(coordinate: location.coordinate, 
                          tint: location.isOrigin ? .green : .red)
            }
            .overlay(
                route != nil ?
                    MapPolyline(route: route!, lineWidth: 5, strokeColor: .blue)
                    : nil
            )
            .ignoresSafeArea()
                
            // Top bar with controls
            VStack {
                // Navigation and title bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Text("Route Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                    
                    Spacer()
                    
                    Button(action: onConfirm) {
                        Text("Use")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, safeAreaInsets.top + 8)
                .padding(.bottom, 8)
                
                if isLoadingRoute {
                    loadingBanner
                } else if let error = routeError {
                    errorBanner(message: error)
                }
                
                Spacer()
            }
            
            // Loading indicator centered
            if isLoadingRoute {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .frame(width: 80, height: 80)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            // Route details card at bottom
            if !isLoadingRoute && route != nil {
                VStack {
                    Spacer()
                    
                    routeDetailsCard
                }
                .padding(.bottom, safeAreaInsets.bottom > 0 ? safeAreaInsets.bottom : 16)
            }
        }
        .onAppear {
            calculateRoute()
        }
    }
    
    // Loading banner at top of screen
    private var loadingBanner: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Calculating route...")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Error banner that appears at top
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: calculateRoute) {
                Text("Retry")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Route details card that appears at bottom of screen
    private var routeDetailsCard: some View {
        VStack(spacing: 0) {
            // Handle for dragging
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.vertical, 6)
            
            VStack(spacing: 16) {
                if let route = route {
                    // Route locations
                    HStack(spacing: 20) {
                        // Start location
                        VStack(alignment: .center, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Start")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Route line
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: 3)
                        
                        // End location
                        VStack(alignment: .center, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                            }
                            
                            Text("End")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Route stats
                    HStack(spacing: 30) {
                        // Distance
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "ruler.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                
                                Text("Distance")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(String(format: "%.1f km", route.distance / 1000))
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()
                            .frame(height: 40)
                        
                        // Time
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                
                                Text("Duration")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(formatDuration(route.expectedTravelTime))
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        .padding(.horizontal, 16)
    }
    
    // Format duration as hours and minutes
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    // Get safe area insets
    private var safeAreaInsets: EdgeInsets {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return EdgeInsets()
        }
        let insets = window.safeAreaInsets
        return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
        #else
        return EdgeInsets()
        #endif
    }
    
    // Calculate the route between the two locations
    private func calculateRoute() {
        isLoadingRoute = true
        routeError = nil
        
        let geocoder = CLGeocoder()
        let locationManager = CLLocationManager()
        
        // Get coordinates for start location
        geocoder.geocodeAddressString(startLocation) { startPlacemarks, startError in
            guard let startCoordinate = startPlacemarks?.first?.location?.coordinate else {
                isLoadingRoute = false
                routeError = "Could not find start location: \(startError?.localizedDescription ?? "Unknown error")"
                return
            }
            
            // Get coordinates for end location
            geocoder.geocodeAddressString(endLocation) { endPlacemarks, endError in
                guard let endCoordinate = endPlacemarks?.first?.location?.coordinate else {
                    isLoadingRoute = false
                    routeError = "Could not find end location: \(endError?.localizedDescription ?? "Unknown error")"
                    return
                }
                
                // Set annotations for start and end locations
                annotations = [
                    MapLocation(id: UUID(), coordinate: startCoordinate, isOrigin: true),
                    MapLocation(id: UUID(), coordinate: endCoordinate, isOrigin: false)
                ]
                
                // Set region to cover both points
                let centerLatitude = (startCoordinate.latitude + endCoordinate.latitude) / 2
                let centerLongitude = (startCoordinate.longitude + endCoordinate.longitude) / 2
                
                // Calculate appropriate zoom level
                let latDelta = abs(startCoordinate.latitude - endCoordinate.latitude) * 1.5
                let lonDelta = abs(startCoordinate.longitude - endCoordinate.longitude) * 1.5
                
                withAnimation {
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
                        span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
                    )
                }
                
                // Calculate route
                let startItem = MKMapItem(placemark: MKPlacemark(coordinate: startCoordinate))
                let endItem = MKMapItem(placemark: MKPlacemark(coordinate: endCoordinate))
                
                let request = MKDirections.Request()
                request.source = startItem
                request.destination = endItem
                request.transportType = .automobile
                
                let directions = MKDirections(request: request)
                directions.calculate { response, error in
                    isLoadingRoute = false
                    
                    if let error = error {
                        routeError = "Routing error: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let unwrappedResponse = response, let unwrappedRoute = unwrappedResponse.routes.first else {
                        routeError = "No route found"
                        return
                    }
                    
                    route = unwrappedRoute
                }
            }
        }
    }
}

// Add a MapPolyline view for drawing the route
struct MapPolyline: UIViewRepresentable {
    let route: MKRoute
    var lineWidth: CGFloat = 5
    var strokeColor: Color = .blue
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.alpha = 1
        
        let polyline = route.polyline
        mapView.addOverlay(polyline)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlay(route.polyline)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapPolyline
        
        init(_ parent: MapPolyline) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKPolyline {
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor(parent.strokeColor)
                renderer.lineWidth = parent.lineWidth
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} 

// Add the LocationSelectionView
struct LocationSelectionView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    let title: String
    @ObservedObject var locationManager: LocationManager
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var searchText = ""
    @StateObject private var searchCompleter = MapSearch()
    @State private var showSearchResults = false
    @State private var isLoadingLocation = false
    @State private var isDraggingMap = false
    @State private var showCenterPin = true
    @State private var mapCenterPinScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Map layer
                Map(coordinateRegion: $region,
                    showsUserLocation: true,
                    userTrackingMode: .constant(.follow))
                    .mapStyle(.standard)
                    .ignoresSafeArea()
                    .gesture(mapDragGesture)
                
                // Top search bar and controls
                VStack(spacing: 0) {
                    // Navigation bar
                    HStack {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text("Select \(title)")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: onConfirm) {
                            Text("Done")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .edgesIgnoringSafeArea(.top)
                    )
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                        
                        TextField("Search location", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { newValue in
                                withAnimation {
                                    showSearchResults = !newValue.isEmpty && newValue.count > 2
                                    searchCompleter.update(queryFragment: newValue)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation {
                                    searchText = ""
                                    showSearchResults = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    // Search results
                    if showSearchResults {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(searchCompleter.locationResults, id: \.self) { location in
                                    Button {
                                        handleLocationSelection(location)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.red)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(location.title)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                
                                                Text(location.subtitle)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                    }
                                    .background(Color.white)
                                    
                                    if searchCompleter.locationResults.last != location {
                                        Divider()
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                        .frame(height: min(300, CGFloat(searchCompleter.locationResults.count * 60)))
                    }
                    
                    Spacer()
                }
                
                // Center pin
                if showCenterPin {
                    VStack(spacing: 0) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                            )
                            .scaleEffect(mapCenterPinScale)
                            .shadow(radius: 3)
                            .offset(y: isDraggingMap ? 0 : -15)
                            .animation(.spring(response: 0.3), value: isDraggingMap)
                        
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 10, height: 3)
                            .offset(y: -10)
                    }
                }
                
                // Side controls
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Current location button
                            Button(action: requestCurrentLocation) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                                    
                                    Image(systemName: isLoadingLocation ? "arrow.clockwise" : "location.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 100 : 120)
                    }
                }
            }
            .onAppear {
                if let location = selectedLocation {
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: location,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    }
                    updateAddressFromLocation(location)
                } else {
                    requestCurrentLocation()
                }
            }
        }
    }
    
    // MARK: - Gestures
    
    private var mapDragGesture: some Gesture {
        DragGesture()
            .onChanged { _ in
                if !isDraggingMap {
                    withAnimation(.spring(response: 0.3)) {
                        isDraggingMap = true
                        showCenterPin = true
                        mapCenterPinScale = 1.2
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3)) {
                    isDraggingMap = false
                    mapCenterPinScale = 1.0
                }
                
                let location = region.center
                selectedLocation = location
                updateAddressFromLocation(location)
            }
    }
    
    // MARK: - Helper Methods
    
    private func handleLocationSelection(_ location: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: location)
        let search = MKLocalSearch(request: searchRequest)
        
        withAnimation {
            isLoadingLocation = true
            showSearchResults = false
            searchText = location.title
        }
        
        search.start { response, error in
            withAnimation {
                isLoadingLocation = false
            }
            
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            withAnimation(.spring(response: 0.5)) {
                selectedLocation = coordinate
                
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
            
            address = "\(location.title), \(location.subtitle)"
        }
    }
    
    private func updateAddressFromLocation(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        withAnimation {
            isLoadingLocation = true
        }
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            withAnimation {
                isLoadingLocation = false
            }
            
            guard let placemark = placemarks?.first else { return }
            
            address = [
                placemark.name,
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.postalCode,
                placemark.country
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        }
    }
    
    private func requestCurrentLocation() {
        Task {
            withAnimation(.easeInOut) {
                isLoadingLocation = true
            }
            
            do {
                if locationManager.authorizationStatus == .notDetermined {
                    locationManager.requestWhenInUseAuthorization()
                }
                
                if let location = try? await locationManager.requestLocation() {
                    withAnimation {
                        selectedLocation = location.coordinate
                        
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                    
                    updateAddressFromLocation(location.coordinate)
                }
            }
            
            withAnimation {
                isLoadingLocation = false
            }
        }
    }
} 