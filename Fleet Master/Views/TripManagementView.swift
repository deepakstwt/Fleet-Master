import SwiftUI
import MapKit

struct TripManagementView: View {
    // MARK: - Custom Button Style
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.spring(response: 0.2), value: configuration.isPressed)
        }
    }
    
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @StateObject private var locationManager = LocationManager()
    
    @State private var searchText = ""
    @State private var statusFilter: TripStatus? = nil
    @State private var selectedTrip: Trip?
    @State private var showDetailView = false
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showAssignDriverSheet = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var viewMode: ViewMode = .list
    @State private var showFilterOptions = false
    @State private var isRefreshing = false
    @State private var isProcessingAction = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum ViewMode {
        case list
        case calendar
        case map
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Header with stats and search bar
                    headerSection
                    
                    // View type selector and filters
                    controlSection
                    
                    // Content based on view mode
                    contentSection
                        .overlay(
                            Group {
                                if tripViewModel.isLoading && !isRefreshing {
                                    ProgressView("Loading trips...")
                                        .padding()
                                        .background(Color(.systemBackground).opacity(0.8))
                                        .cornerRadius(10)
                                        .shadow(radius: 3)
                                }
                            }
                        )
                }
                .navigationTitle("Trip Management")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                await refreshData()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .disabled(isRefreshing || tripViewModel.isLoading || isProcessingAction)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            showAddSheet = true
                        }) {
                            Label("", systemImage: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.accentColor))
                                .shadow(color: Color.accentColor.opacity(0.4), radius: 5, x: 0, y: 2)
                        }
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Status Update"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .fullScreenCover(isPresented: $showAddSheet) {
                    NavigationStack {
                        AddTripView()
                            .environmentObject(tripViewModel)
                            .environmentObject(driverViewModel)
                            .environmentObject(vehicleViewModel)
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    if let trip = selectedTrip {
                        NavigationStack {
                            EditTripView(selectedTrip: trip)
                        }
                        .presentationDetents([.large])
                        .onDisappear {
                            // Refresh data when edit sheet disappears
                            Task {
                                await refreshData()
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAssignDriverSheet) {
                    if let trip = selectedTrip {
                        NavigationStack {
                            AssignDriverView(selectedTrip: trip)
                        }
                        .presentationDetents([.medium])
                        .onDisappear {
                            // Refresh data when assign driver sheet disappears
                            Task {
                                await refreshData()
                            }
                        }
                    }
                }
                .sheet(item: $selectedTrip) { trip in
                    NavigationStack {
                        TripDetailView(trip: trip)
                            .onAppear {
                                // Load route information if not already available
                                if trip.routeInfo == nil {
                                    locationManager.calculateRoute(from: trip.startLocation, to: trip.endLocation) { [self] result in
                                        if case .success(let route) = result {
                                            // Update trip with route info in view model
                                            let routeInfo = RouteInformation(distance: route.distance, time: route.expectedTravelTime)
                                            self.tripViewModel.updateTripRouteInfo(trip: trip, routeInfo: routeInfo)
                                        }
                                    }
                                }
                            }
                    }
                    .presentationDetents([.large])
                }
                
                // Display overlay for processing state
                if isProcessingAction {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray4)))
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Refresh data when the view appears
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    // MARK: - Data Operations
    
    private func refreshData() async {
        isRefreshing = true
        
        // Apply any active filters
        await tripViewModel.loadTrips(withStatus: statusFilter)
        
        // If we have an active search, also apply that
        if !searchText.isEmpty {
            await tripViewModel.searchTripsFromSupabase()
        }
        
        isRefreshing = false
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Trip stats row
            HStack(spacing: 14) {
                statCard(count: tripViewModel.trips.filter { $0.status == .scheduled }.count,
                        title: "Scheduled",
                        icon: "calendar",
                        color: .blue)
                
                statCard(count: tripViewModel.trips.filter { $0.status == .inProgress }.count,
                        title: "In Progress",
                        icon: "arrow.triangle.swap",
                        color: .orange)
                
                statCard(count: tripViewModel.trips.filter { $0.status == .completed }.count,
                        title: "Completed",
                        icon: "checkmark.circle",
                        color: .green)
                
                statCard(count: tripViewModel.trips.filter { $0.status == .cancelled }.count,
                        title: "Cancelled",
                        icon: "xmark.circle",
                        color: .red)
            }
            .padding(.horizontal, 12)
            
            // Search bar with filter
            HStack(spacing: 10) {
                // Filter button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showFilterOptions.toggle()
                    }
                }) {
                    Image(systemName: "line.horizontal.3.decrease.circle\(showFilterOptions ? ".fill" : "")")
                        .foregroundColor(showFilterOptions ? .accentColor : .secondary)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(showFilterOptions ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    
                    TextField("Search trips by title, location...", text: $searchText)
                        .padding(.vertical, 12)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                searchText = ""
                            }
                            // Dismiss keyboard
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                        }
                        .padding(.trailing, 12)
                        .transition(.scale)
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var controlSection: some View {
        VStack(spacing: 10) {
            // View type selector
            Picker("View", selection: $viewMode) {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                  
                }.tag(ViewMode.list)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                    
                }.tag(ViewMode.calendar)
                
                HStack {
                    Image(systemName: "map")
                        .font(.system(size: 16, weight: .medium))
                  
                }.tag(ViewMode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            
            // Filter options
            if showFilterOptions {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filter by Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            filterButton(title: "All Trips", status: nil)
                            filterButton(title: "Scheduled", status: .scheduled)
                            filterButton(title: "In Progress", status: .inProgress)
                            filterButton(title: "Completed", status: .completed)
                            filterButton(title: "Cancelled", status: .cancelled)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
                )
                .padding(.horizontal, 12)
            }
            
            Divider()
                .padding(.top, 4)
        }
    }
    
    private var contentSection: some View {
        Group {
            if tripViewModel.trips.isEmpty {
                emptyStateView
            } else {
                switch viewMode {
                case .list:
                    tripListView
                case .calendar:
                    ScrollView {
                        ScheduledTripsCalendarView()
                    }
                    .refreshable {
                        await refreshData()
                    }
                case .map:
                    ScrollView {
                        mapContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
        }
    }
    
    private var tripListView: some View {
        List {
            ForEach(filteredTrips) { trip in
                modernTripCard(trip: trip)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTrip = trip
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if trip.status == .scheduled {
                            Button(action: {
                                selectedTrip = trip
                                showAssignDriverSheet = true
                            }) {
                                Label("Assign", systemImage: "person.fill.badge.plus")
                            }
                            .tint(.blue)
                        }
                        
                        if trip.status == .scheduled || trip.status == .inProgress {
                            Button(role: .destructive, action: {
                                Task {
                                    await cancelTrip(trip)
                                }
                            }) {
                                Label("Cancel", systemImage: "xmark.circle")
                            }
                            .tint(.red)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button(action: {
                            selectedTrip = trip
                            showEditSheet = true
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                        
                        if trip.status == .scheduled {
                            Button(action: {
                                Task {
                                    await updateTripStatus(trip: trip, newStatus: .inProgress)
                                }
                            }) {
                                Label("Start", systemImage: "play.circle")
                            }
                            .tint(.green)
                        } else if trip.status == .inProgress {
                            Button(action: {
                                Task {
                                    await updateTripStatus(trip: trip, newStatus: .completed)
                                }
                            }) {
                                Label("Complete", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .refreshable {
            await refreshData()
        }
        .overlay(
            ZStack {
                if isProcessingAction {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView()
                            .tint(.white)
                        Text("Processing...")
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
    }
    
    private var mapContent: some View {
        Group {
            if filteredTrips.isEmpty {
                emptyStateView
            } else {
                ZStack(alignment: .bottomTrailing) {
                    TripMapView(
                        trips: filteredTrips,
                        locationManager: locationManager, 
                        isAssignedTrip: true, // Professional map mode for Fleet Managers
                        showAllRoutes: true,  // Show all routes on map
                        highlightSelectedRoute: true // Highlight routes when selected
                    )
                    .edgesIgnoringSafeArea(.all)
                    
                    // Fleet Manager Control Panel
                    VStack(spacing: 12) {
                        Text("Fleet Manager Controls")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .foregroundColor(.primary)
                        
                        Divider()
                        
                        // Trip Statistics
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(filteredTrips.filter { $0.status == .inProgress }.count)")
                                    .font(.title2.bold())
                                    .foregroundColor(.blue)
                                Text("Active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(filteredTrips.filter { $0.status == .scheduled }.count)")
                                    .font(.title2.bold())
                                    .foregroundColor(.orange)
                                Text("Scheduled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                let driverCount = filteredTrips.compactMap { $0.driverId }.count
                                Text("\(driverCount)")
                                    .font(.title2.bold())
                                    .foregroundColor(.green)
                                Text("Drivers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // Trip Filter Controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Filter Active Trips")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    Button(action: {
                                        // Filter for vehicles that need attention
                                        statusFilter = .inProgress
                                    }) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundColor(.orange)
                                            Text("Attention Needed")
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(statusFilter == .inProgress ? Color.orange.opacity(0.2) : Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.orange.opacity(0.5), lineWidth: statusFilter == .inProgress ? 1.5 : 0)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    Button(action: {
                                        // Show all in-progress trips
                                        statusFilter = .inProgress
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.swap")
                                                .foregroundColor(.blue)
                                            Text("In Progress")
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(statusFilter == .inProgress ? Color.blue.opacity(0.2) : Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.blue.opacity(0.5), lineWidth: statusFilter == .inProgress ? 1.5 : 0)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    Button(action: {
                                        // Clear all filters
                                        statusFilter = nil
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                                .foregroundColor(.green)
                                            Text("All Trips")
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(statusFilter == nil ? Color.green.opacity(0.2) : Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.green.opacity(0.5), lineWidth: statusFilter == nil ? 1.5 : 0)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Live tracking controls
                        VStack(spacing: 10) {
                            Button(action: {
                                // Enable live tracking for all vehicles on the map
                                let vehicleIds = filteredTrips.compactMap { $0.vehicleId }
                                locationManager.startTrackingVehicles(vehicleIds: vehicleIds)
                            }) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.white)
                                    Text("Track All Vehicles")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                            
                            Button(action: {
                                // Show optimal routes for all active trips
                                // This would show traffic-optimized routes for all vehicles
                                for trip in filteredTrips.filter({ $0.status == .inProgress }) {
                                    locationManager.calculateRoute(from: trip.startLocation, to: trip.endLocation) { result in
                                        // Route is recalculated with live traffic data
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .foregroundColor(.white)
                                    Text("Optimize Routes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground).opacity(0.95))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
                    )
                    .frame(width: 300)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "car.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)
            }
            .padding(.bottom, 8)
            
            Text("No Trips Found")
                .font(.title.bold())
                .foregroundColor(.primary)
            
            Text("Start by adding your first trip to manage your fleet")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.systemGray2))
                .padding(.horizontal, 32)
            
            Button(action: {
                showAddSheet = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Trip")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var filteredTrips: [Trip] {
        tripViewModel.trips.filter { trip in
            // First check if the trip matches the search text
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch = trip.title.localizedCaseInsensitiveContains(searchText) ||
                    trip.description.localizedCaseInsensitiveContains(searchText) ||
                    trip.startLocation.localizedCaseInsensitiveContains(searchText) ||
                    trip.endLocation.localizedCaseInsensitiveContains(searchText)
            }
            
            // Then check if it matches the status filter
            let matchesStatus = statusFilter == nil || trip.status == statusFilter
            
            // Return true only if both conditions are satisfied
            return matchesSearch && matchesStatus
        }
    }
    
    private func getDriverName(for trip: Trip) -> String {
        if let driverId = trip.driverId, 
           let driver = driverViewModel.getDriverById(driverId) {
            return driver.name
        }
        return "Unassigned"
    }
    
    private func getVehicleName(for trip: Trip) -> String {
        if let vehicleId = trip.vehicleId, 
           let vehicle = vehicleViewModel.getVehicleById(vehicleId) {
            return formatVehicle(vehicle)
        }
        return "Unassigned"
    }
    
    private func formatVehicle(_ vehicle: Vehicle?) -> String {
        guard let vehicle = vehicle else { return "Unknown" }
        return "\(vehicle.make) \(vehicle.model)"
    }
    
    private func statusIcon(for status: TripStatus) -> some View {
        switch status {
        case .scheduled:
            return Image(systemName: "calendar")
                .foregroundColor(.blue)
        case .inProgress:
            return Image(systemName: "arrow.triangle.swap")
                .foregroundColor(.orange)
        case .completed:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .cancelled:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
    
    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private func calculateProgress(for trip: Trip) -> Double {
        guard trip.status == .inProgress, 
              let actualStartTime = trip.actualStartTime else { return 0.0 }
        
        let now = Date()
        let totalDuration = trip.scheduledEndTime.timeIntervalSince(actualStartTime)
        let elapsedDuration = now.timeIntervalSince(actualStartTime)
        
        return max(0, min(1, elapsedDuration / totalDuration))
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d · h:mm a"
        return formatter.string(from: date)
    }
    
    private func statCard(count: Int, title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
                
                RoundedRectangle(cornerRadius: 18)
                    .fill(color.opacity(0.06))
                
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1.5)
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .frame(height: 130)
    }
    
    private func filterButton(title: String, status: TripStatus?) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                statusFilter = status
            }
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(statusFilter == status ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusFilter == status ? Color.accentColor : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(statusFilter == status ? Color.clear : Color(.systemGray4), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func modernTripCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                // Trip status icon and title
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(statusColor(for: trip.status).opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        statusIcon(for: trip.status)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trip.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(formatDateTime(trip.scheduledStartTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status badge
                Text(trip.status.rawValue)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(statusColor(for: trip.status).opacity(0.15))
                    )
                    .foregroundColor(statusColor(for: trip.status))
                    .overlay(
                        Capsule()
                            .stroke(statusColor(for: trip.status).opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.bottom, 6)
            
            Divider()
                .background(Color(.systemGray4).opacity(0.7))
                .padding(.vertical, 6)
            
            // Trip locations
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                    
                    Text(trip.startLocation)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                // Connecting line between points
                HStack {
                    Rectangle()
                        .frame(width: 1, height: 30)
                        .foregroundColor(Color(.systemGray4))
                        .padding(.leading, 16)
                    
                    Spacer()
                }
                
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    
                    Text(trip.endLocation)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            
            // If we have driver and vehicle info, show it
            if trip.driverId != nil || trip.vehicleId != nil {
                Divider()
                    .background(Color(.systemGray4).opacity(0.7))
                    .padding(.vertical, 6)
                
                HStack(spacing: 24) {
                    if let driverId = trip.driverId,
                       let driver = driverViewModel.getDriverById(driverId) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            
                            Text(driver.name)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    
                    if let vehicleId = trip.vehicleId,
                       let vehicle = vehicleViewModel.getVehicleById(vehicleId) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "car.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                            }
                            
                            Text(vehicle.registrationNumber)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Trip progress if in progress
            if trip.status == .inProgress, let actualStartTime = trip.actualStartTime {
                Divider()
                    .background(Color(.systemGray4).opacity(0.7))
                    .padding(.vertical, 6)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Trip Progress")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(calculateProgress(for: trip) * 100))%")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: calculateProgress(for: trip))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .frame(height: 8)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 250)
    }
    
    // MARK: - Action Methods
    
    private func cancelTrip(_ trip: Trip) async {
        isProcessingAction = true
        
        do {
            // Use Task to perform async operation
            try await tripViewModel.cancelTripAsync(trip)
            
            // Update UI on the main thread
            await MainActor.run {
                isProcessingAction = false
                alertMessage = "Trip has been cancelled successfully."
                showAlert = true
                
                // Refresh data to ensure UI is updated
                Task {
                    await refreshData()
                }
            }
        } catch {
            await MainActor.run {
                isProcessingAction = false
                errorMessage = "Failed to cancel trip: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func updateTripStatus(trip: Trip, newStatus: TripStatus) async {
        isProcessingAction = true
        
        do {
            // Use Task to perform async operation
            try await tripViewModel.updateTripStatusAsync(trip: trip, newStatus: newStatus)
            
            // Update UI on the main thread
            await MainActor.run {
                isProcessingAction = false
                
                let statusMessage: String
                switch newStatus {
                case .inProgress: statusMessage = "Trip has been started."
                case .completed: statusMessage = "Trip has been completed."
                case .cancelled: statusMessage = "Trip has been cancelled."
                default: statusMessage = "Trip status has been updated."
                }
                
                alertMessage = statusMessage
                showAlert = true
                
                // Refresh data to ensure UI is updated
                Task {
                    await refreshData()
                }
            }
        } catch {
            await MainActor.run {
                isProcessingAction = false
                errorMessage = "Failed to update trip status: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    TripManagementView()
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 
