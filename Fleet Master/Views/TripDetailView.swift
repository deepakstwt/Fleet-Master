import SwiftUI
import MapKit

struct TripDetailView: View {
    @State private var tripData: Trip
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var showMap = false
    @State private var showingShareSheet = false
    @State private var animateContent = false
    @State private var estimatedTime: String = "Calculating..."
    @State private var estimatedDistance: Double = 0.0
    @State private var estimatedDuration: TimeInterval = 0
    @State private var isCustomSchedule: Bool = true
    @State private var customStartTime: Date = Date()
    @State private var customEndTime: Date = Date().addingTimeInterval(3600) // Default 1 hour later
    @State private var userHasEditedEndTime: Bool = false
    @State private var isMapFullScreen: Bool = false
    @State private var isHindiMode: Bool = false
    @State private var isProcessingAction = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCancelConfirmation = false
    @EnvironmentObject private var tripViewModel: TripViewModel
    
    init(trip: Trip) {
        _tripData = State(initialValue: trip)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                tripHeaderCard
                    .padding(.horizontal)
                
                // Trip Status Card
                statusCard
                    .padding(.horizontal)
                
                // Locations Card
                locationsCard
                    .padding(.horizontal)
                
                // Assignment Card
                assignmentCard
                    .padding(.horizontal)
                
                // Trip Details Card
                detailsCard
                    .padding(.horizontal)
                
                // Trip Notes
                if let notes = tripData.notes, !notes.isEmpty {
                    notesCard(notes: notes)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Trip Details")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Label("Share Trip", systemImage: "square.and.arrow.up")
                    }
                    
                    NavigationLink(destination: EditTripView(selectedTrip: tripData)) {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        showCancelConfirmation = true
                    }) {
                        Label("Cancel Trip", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $showMap) {
                NavigationStack {
                    VStack(spacing: 0) {
                        TripMapView(trips: [tripData], locationManager: locationManager)
                            .navigationTitle("Trip Route")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Close") {
                                        showMap = false
                                    }
                                }
                            }
                            .edgesIgnoringSafeArea(.all)
                    }
                    }
                }
                .fullScreenCover(isPresented: $isMapFullScreen) {
                    ZStack(alignment: .bottom) {
                        // Map view with Indian region focus and route zoom
                        TripMapView(
                            trips: [tripData],
                            locationManager: locationManager,
                            isAssignedTrip: tripData.status == .ongoing && tripData.driverId != nil && tripData.vehicleId != nil
                        )
                            .edgesIgnoringSafeArea(.all)
                            .overlay(alignment: .topTrailing) {
                                Button(action: {
                                    isMapFullScreen = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                        .background(
                                            Circle()
                                                .fill(Color(.systemBackground))
                                                .shadow(radius: 2)
                                        )
                                }
                                .padding(.top, 0)
                                .padding(.trailing, 16)
                            }

                        // Removing the bottom information card completely
                    }
                    .onAppear {
                        // Force calculation of route with focus on Indian routes
                        locationManager.calculateRoute(from: tripData.startLocation, to: tripData.endLocation) { result in
                            if case .success = result {
                                // Route calculation successful, map will center on the route
                                print("Indian route calculated and displayed with proper zoom")
                            }
                        }
                    }
                }
        .sheet(isPresented: $showingShareSheet) {
            let tripDetails = """
            Trip: \(tripData.title)
            From: \(tripData.startLocation)
            To: \(tripData.endLocation)
            Date: \(formatDate(tripData.scheduledStartTime))
            """
            ActivityViewController(activityItems: [tripDetails])
        }
        .onAppear {
            // Initialize custom time controls with the trip's scheduled times
            customStartTime = tripData.scheduledStartTime
            customEndTime = tripData.scheduledEndTime
            
            // First load any existing data if available
            if let routeInfo = tripData.routeInfo {
                // Initialize from existing trip data immediately
                estimatedDistance = routeInfo.distance / 1000
                estimatedDuration = routeInfo.time
                
                // Format the time for display
                let timeInMinutes = routeInfo.time / 60
                if timeInMinutes < 60 {
                    estimatedTime = "\(Int(timeInMinutes)) min"
                } else {
                    let hrs = Int(timeInMinutes / 60)
                    let mins = Int(timeInMinutes.truncatingRemainder(dividingBy: 60))
                    estimatedTime = "\(hrs)h \(mins)m"
                }
            }
            
            // Calculate fresh route info but don't update times
            calculateRouteInfo()
            
            // Animate content with a slight delay to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
            }
        }
        .overlay(
            ZStack {
                if isProcessingAction {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("Cancelling trip...")
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray4)))
                }
            }
        )
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Cancel Trip", isPresented: $showCancelConfirmation) {
            Button("No", role: .cancel) {}
            Button("Yes, Cancel Trip", role: .destructive) {
                Task {
                    await cancelTrip()
                }
            }
        } message: {
            Text("Are you sure you want to cancel this trip?")
        }
    }
    
    // MARK: - UI Components
    
    private var tripHeaderCard: some View {
        VStack(spacing: 0) {
            // Top section with title and status badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tripData.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        
                        Text(formatDate(tripData.scheduledStartTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                statusBadge
                    .offset(y: -5)
            }
            .padding()
            
            Divider()
                .padding(.horizontal)
            
            HStack(spacing: 24) {
                tripInfoItem(
                    icon: "arrow.left.and.right",
                    value: String(format: "%.1f km", estimatedDistance),
                    label: "Distance"
                )
                
                tripInfoItem(
                    icon: "clock",
                    value: estimatedTime,
                    label: "Est. Time"
                )
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    private var statusBadge: some View {
        Text(tripData.status.rawValue.capitalized)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(20)
    }
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            // Clean header with icon
            HStack {
                Label {
                    Text("Time Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                }
                
                Spacer()
            }
            
            // Simple time display
            HStack(spacing: 40) {
                // Start time
                VStack(alignment: .center, spacing: 8) {
                    Text("Start")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatTimeWithoutAmPm(tripData.scheduledStartTime))
                            .font(.system(size: 28, weight: .bold))
                        Text(getAmPm(tripData.scheduledStartTime))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDateOnly(tripData.scheduledStartTime))
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                // End time
                VStack(alignment: .center, spacing: 8) {
                    Text("End")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatTimeWithoutAmPm(tripData.scheduledEndTime))
                            .font(.system(size: 28, weight: .bold))
                        Text(getAmPm(tripData.scheduledEndTime))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDateOnly(tripData.scheduledEndTime))
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            
            // Duration pill
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Text(estimatedTime)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 120)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    private var locationsCard: some View {
        VStack(spacing: 18) {
            // Header with built-in map toggle
            HStack {
                Label("Locations", systemImage: "map")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: {
                    // Always open full screen map regardless of trip status
                    isMapFullScreen = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.caption)
                    Text("View Map")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Map preview
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: "map")
                                .font(.system(size: 30))
                                .foregroundColor(.blue.opacity(0.5))
                        )
                        .overlay(
                            // Decorative route line
                            Path { path in
                                path.move(to: CGPoint(x: 20, y: 70))
                                path.addCurve(
                                    to: CGPoint(x: 320, y: 30),
                                    control1: CGPoint(x: 80, y: 80),
                                    control2: CGPoint(x: 240, y: 10)
                                )
                            }
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5]))
                            .opacity(0.6)
                        )
                        .overlay(
                            // Start point
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .offset(x: -140, y: 30)
                        )
                        .overlay(
                            // End point
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .offset(x: 130, y: -10)
                        )
                }
                .padding(.bottom, 5)
                
            // Start location
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(tripData.startLocation)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .onChange(of: tripData.startLocation) { _ in
                            calculateRouteInfo() // Recalculate when location changes
                        }
                }
                
                Spacer()
            }
            
            // Connecting line
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .padding(.leading, 7)
                
                Spacer()
            }
            .frame(height: 20)
            
            // End location
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(tripData.endLocation)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .onChange(of: tripData.endLocation) { _ in
                            calculateRouteInfo() // Recalculate when location changes
                        }
                }
                
                Spacer()
            }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    private var assignmentCard: some View {
        VStack(spacing: 18) {
            Label("Assignment", systemImage: "person.and.person.fill")
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // Driver Info
                personInfoView(
                    icon: "person.circle.fill",
                    title: "Driver",
                    value: driverName,
                    color: .blue
                )
                
                Divider()
                    .frame(height: 60)
                
                // Vehicle Info
                personInfoView(
                    icon: "car.fill",
                    title: "Vehicle",
                    value: vehicleName,
                    color: .indigo
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Trip Details", systemImage: "doc.text")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(tripData.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Divider()
                
                if let actualStart = tripData.actualStartTime {
                    detailRow(
                        title: "Actual Start",
                        value: formatDate(actualStart),
                        icon: "clock.arrow.2.circlepath"
                    )
                }
                
                if let actualEnd = tripData.actualEndTime {
                    detailRow(
                        title: "Actual End",
                        value: formatDate(actualEnd),
                        icon: "clock.arrow.circlepath"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(notes)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: animateContent ? 0 : 20)
        .opacity(animateContent ? 1 : 0)
    }
    
    // MARK: - Helper Views
    
    private func tripInfoItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
            Text(value)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func personInfoView(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var statusColor: Color {
        switch tripData.status {
        case .scheduled:
            return .blue
        case .ongoing:
            return .green
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private func getTripProgressColor(stage: Int) -> Color {
        switch tripData.status {
        case .scheduled:
            return stage == 0 ? .blue : Color.gray.opacity(0.3)
        case .ongoing:
            return stage <= 1 ? .green : Color.gray.opacity(0.3)
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private var driverName: String {
        if let driverId = tripData.driverId,
           let driver = driverViewModel.getDriverById(driverId) {
            return driver.name
        }
        return "Unassigned"
    }
    
    private var vehicleName: String {
        if let vehicleId = tripData.vehicleId,
           let vehicle = vehicleViewModel.getVehicleById(vehicleId) {
            return "\(vehicle.make) \(vehicle.model)"
        }
        return "Unassigned"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateRouteInfo() {
        // If we already have route info from the model, use it for initial display
        if let routeInfo = tripData.routeInfo {
            // Update the distance
            self.estimatedDistance = routeInfo.distance / 1000
            self.estimatedDuration = routeInfo.time
            
            // Format the time for display
            let timeInMinutes = routeInfo.time / 60
            if timeInMinutes < 60 {
                self.estimatedTime = "\(Int(timeInMinutes)) min"
            } else {
                let hrs = Int(timeInMinutes / 60)
                let mins = Int(timeInMinutes.truncatingRemainder(dividingBy: 60))
                self.estimatedTime = "\(hrs)h \(mins)m"
            }
        } else {
            // Set loading state if no pre-existing data
            self.estimatedTime = "Calculating..."
        }
        
        // Calculate fresh route info using the LocationManager
        locationManager.calculateRoute(from: tripData.startLocation, to: tripData.endLocation) { result in
            switch result {
            case .success(let route):
                    DispatchQueue.main.async {
                        // Update the distance
                        self.estimatedDistance = route.distance / 1000
                        
                        // Update the duration
                        let timeInMinutes = route.expectedTravelTime / 60
                        self.estimatedDuration = route.expectedTravelTime
                        
                        // Format the time for display
                        if timeInMinutes < 60 {
                            self.estimatedTime = "\(Int(timeInMinutes)) min"
                        } else {
                            let hrs = Int(timeInMinutes / 60)
                            let mins = Int(timeInMinutes.truncatingRemainder(dividingBy: 60))
                            self.estimatedTime = "\(hrs)h \(mins)m"
                        }
                        
                        // Store the route info in the trip data for future use
                        self.tripData.routeInfo = RouteInformation(
                            distance: route.distance,
                            time: route.expectedTravelTime
                        )
                    }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.estimatedTime = "Route error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func updateScheduledTimes() {
        // Format the current time for debugging
        let currentTimeFormatter = DateFormatter()
        currentTimeFormatter.dateFormat = "h:mm:ss a"
        
        // Calculate end time by adding the estimated duration to the original scheduled start time
        let endTime = tripData.scheduledStartTime.addingTimeInterval(estimatedDuration)
        
        // Format the time strings for debugging
        _ = currentTimeFormatter.string(from: tripData.scheduledStartTime)
        _ = currentTimeFormatter.string(from: endTime)
        
        // Update only the end time based on the duration
        tripData.scheduledEndTime = endTime
        
        // Update custom time values for when custom mode is toggled on
        customStartTime = tripData.scheduledStartTime
        customEndTime = endTime
        userHasEditedEndTime = false
        
        // Log the update with time details
        print("Schedule updated based on original times")
        print("Start: \(formatDate(tripData.scheduledStartTime)) (preserved original time)")
        print("End: \(formatDate(endTime)) (start time + \(Int(estimatedDuration/60)) minutes)")
        print("Duration: \(estimatedTime)")
    }
    
    // Format time without AM/PM
    private func formatTimeWithoutAmPm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    // Get AM/PM part separately
    private func getAmPm(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }
    
    private func cancelTrip() async {
        isProcessingAction = true
        
        do {
            // Use the environment injected tripViewModel
            try await tripViewModel.cancelTripAsync(tripData)
            
            // Update UI on the main thread
            await MainActor.run {
                isProcessingAction = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessingAction = false
                errorMessage = "Failed to cancel trip: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - ActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Helper view for location markers
struct LocationMarker: View {
    var color: Color
    var title: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 20, height: 20)
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip.previewTrip)
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
    }
}
