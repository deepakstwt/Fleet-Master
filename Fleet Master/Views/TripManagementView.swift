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
    @State private var statusFilter: TripStatus?
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
    
    // Add these state variables for calendar functionality
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showingExpandedTrip: Trip? = nil
    
    enum ViewMode {
        case list
        case calendar
        case map
    }
    
    let initialFilter: TripStatus?
    
    init(initialFilter: TripStatus? = nil) {
        self.initialFilter = initialFilter
        _statusFilter = State(initialValue: initialFilter)
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
                
                // Show "+" button only when not in calendar view
                if viewMode != .calendar {
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
        
        // First load ALL trips regardless of filter
        await tripViewModel.loadTrips()
        
        // Then apply the filter again for UI display
        tripViewModel.filterStatus = statusFilter
        
        // If we have an active search, also apply that
        if !searchText.isEmpty {
            tripViewModel.searchText = searchText
            await tripViewModel.searchTripsFromSupabase()
        }
        
        isRefreshing = false
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Trip stats row - now clickable
            HStack(spacing: 14) {
                clickableStatCard(
                    count: tripViewModel.trips.filter { $0.status == .scheduled }.count,
                        title: "Scheduled",
                        icon: "calendar",
                    color: .blue,
                    status: .scheduled
                )
                
                clickableStatCard(
                    count: tripViewModel.trips.filter { $0.status == .ongoing }.count,
                        title: "Ongoing",
                        icon: "arrow.triangle.swap",
                    color: .orange,
                    status: .ongoing
                )
                
                clickableStatCard(
                    count: tripViewModel.trips.filter { $0.status == .completed }.count,
                        title: "Completed",
                        icon: "checkmark.circle",
                    color: .green,
                    status: .completed
                )
                
                clickableStatCard(
                    count: tripViewModel.trips.filter { $0.status == .cancelled }.count,
                        title: "Cancelled",
                        icon: "xmark.circle",
                    color: .red,
                    status: .cancelled
                )
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
                            filterButton(title: "Ongoing", status: .ongoing)
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
                    VStack(spacing: 0) {
                        // Professional calendar container
                        VStack(spacing: 0) {
                            // Month navigation header
                            calendarHeaderView
                            
                            Divider()
                                .padding(.top, 4)
                            
                            // Calendar view
                            ScrollView {
                                enhancedCalendarView()
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .background(Color(.systemGroupedBackground).opacity(0.5))
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
                        if trip.status == .scheduled || trip.status == .ongoing {
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
                                    await updateTripStatus(trip: trip, newStatus: .ongoing)
                                }
                            }) {
                                Label("Start", systemImage: "play.circle")
                            }
                            .tint(.green)
                        } else if trip.status == .ongoing{
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
                                Text("\(filteredTrips.filter { $0.status == .ongoing }.count)")
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
                        statusFilter = .ongoing
                                    }) {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundColor(.orange)
                                            Text("Attention Needed")
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(statusFilter == .ongoing ? Color.orange.opacity(0.2) : Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.orange.opacity(0.5), lineWidth: statusFilter == .ongoing ? 1.5 : 0)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    Button(action: {
                                        // Show all in-progress trips
                                        statusFilter = .ongoing
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.swap")
                                                .foregroundColor(.blue)
                                            Text("Ongoing")
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(statusFilter == .ongoing ? Color.blue.opacity(0.2) : Color(.systemBackground))
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.blue.opacity(0.5), lineWidth: statusFilter == .ongoing ? 1.5 : 0)
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
                                for trip in filteredTrips.filter({ $0.status == .ongoing}) {
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
        case .ongoing:
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
        case .ongoing:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private func calculateProgress(for trip: Trip) -> Double {
        guard trip.status == .ongoing,
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
        VStack(alignment: .leading, spacing: 0) {
            // Professional card header with enhanced visual design
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    // Trip status icon with improved visual design
                    ZStack {
                        Circle()
                            .fill(statusColor(for: trip.status).opacity(0.12))
                            .frame(width: 50, height: 50)
                        
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 42, height: 42)
                        
                        Circle()
                            .fill(statusColor(for: trip.status).opacity(0.9))
                            .frame(width: 38, height: 38)
                            .shadow(color: statusColor(for: trip.status).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        statusIcon(for: trip.status)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .trim(from: 0, to: trip.status == .ongoing ? 0.75 : 1)
                            .stroke(statusColor(for: trip.status).opacity(0.7), lineWidth: 3)
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(trip.status == .ongoing ? 360 : 0))
                            .animation(trip.status == .ongoing ?
                                      Animation.linear(duration: 1.5).repeatForever(autoreverses: false) :
                                    .default, value: trip.status == .ongoing)
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(formatDateTime(trip.scheduledStartTime))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 16)
                
                Spacer()
                
                    // Status badge with enhanced design
                Text(trip.status.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .kerning(0.5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(statusColor(for: trip.status).opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(statusColor(for: trip.status).opacity(0.7), lineWidth: 2)
                    )
                    .foregroundColor(statusColor(for: trip.status))
                    // Add a slight shadow for better visibility
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                ZStack(alignment: .topTrailing) {
                    // Modern gradient background
                    LinearGradient(
                        gradient: Gradient(
                            colors: [
                                Color(UIColor.systemBackground),
                                statusColor(for: trip.status).opacity(0.05)
                            ]
                        ),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Decorative elements
                    Circle()
                        .fill(statusColor(for: trip.status).opacity(0.03))
                        .frame(width: 120, height: 120)
                        .offset(x: 40, y: -30)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            // Trip journey section with enhanced design
            VStack(spacing: 0) {
                // Trip route visualization
                HStack(spacing: 28) {
                    // Left column - Timeline with enhanced visual design
                    VStack(spacing: 0) {
                        // Time column
                        VStack(spacing: 10) {
                            Text(formatTimeOnly(trip.scheduledStartTime))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 70, alignment: .trailing)
                            
                            Spacer()
                            
                            Text(formatTimeOnly(trip.scheduledEndTime))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .frame(height: 120)
                    }
                    
                    // Middle column - Journey line
                    VStack(spacing: 0) {
                        // Origin icon
                    ZStack {
                        Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 28, height: 28)
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                        }
                        
                        // Animated journey line
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.green, location: 0),
                                        .init(color: Color.blue.opacity(0.7), location: 0.4),
                                        .init(color: Color.red.opacity(0.8), location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3, height: 65)
                            .overlay(
                                Group {
                                    if trip.status == .ongoing {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 7, height: 7)
                                            .shadow(color: Color.blue.opacity(0.5), radius: 2, x: 0, y: 0)
                                            .offset(y: -5)
                                            .animation(
                                                Animation.easeInOut(duration: 3.0)
                                                    .repeatForever(autoreverses: false)
                                                    .delay(1),
                                                value: trip.status == .ongoing                                            )
                                    }
                                }
                            )
                        
                        // Destination icon
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 28, height: 28)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .frame(width: 36)
                    
                    // Right column - Location details with improved layout
                    VStack(alignment: .leading, spacing: 0) {
                        // Origin details
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("FROM")
                                    .font(.system(size: 12, weight: .heavy))
                                    .kerning(1)
                                    .foregroundColor(Color.green.opacity(0.7))
                            }
                            .padding(.bottom, 3)
                    
                    Text(trip.startLocation)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                        // Trip details in the middle
                        if let distance = trip.distance {
                            VStack(spacing: 8) {
                                HStack(alignment: .center, spacing: 18) {
                                    // Distance pill
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                        
                                        Text(String(format: "%.1f km", distance))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    
                                    // Duration pill
                                    if let routeInfo = trip.routeInfo {
                                        HStack(spacing: 5) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.purple)
                                            
                                            Text(formatDuration(routeInfo.time))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color.purple.opacity(0.1))
                                        )
                                    }
                                }
                                .padding(.vertical, 12)
                            }
                        }
                        
                        // Destination details
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("TO")
                                    .font(.system(size: 12, weight: .heavy))
                                    .kerning(1)
                                    .foregroundColor(Color.red.opacity(0.7))
                            }
                            .padding(.bottom, 3)
                    
                    Text(trip.endLocation)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        .lineLimit(1)
                }
                    }
                    .padding(.leading, 8)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 24)
            }
            
            // Driver and vehicle info with enhanced design
            if trip.driverId != nil || trip.vehicleId != nil {
                VStack(spacing: 0) {
                Divider()
                        .background(Color(.systemGray5))
                        .padding(.horizontal, 24)
                
                HStack(spacing: 24) {
                        // Driver information with enhanced design
                        if let driverId = trip.driverId, let driver = driverViewModel.getDriverById(driverId) {
                            HStack(spacing: 12) {
                                // Driver avatar
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                
                                Image(systemName: "person.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.blue)
                                }
                                
                                // Driver name
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Driver")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                            
                            Text(driver.name)
                                        .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Vehicle information with enhanced design
                        if let vehicleId = trip.vehicleId, let vehicle = vehicleViewModel.getVehicleById(vehicleId) {
                            HStack(spacing: 12) {
                                // Vehicle icon
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                
                                Image(systemName: "car.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.orange)
                                }
                                
                                // Vehicle details
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Vehicle")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                            
                            Text(vehicle.registrationNumber)
                                        .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
                .background(Color(.systemGray6).opacity(0.3))
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.09), radius: 16, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
    }
    
    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
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
                case .ongoing: statusMessage = "Trip has been started."
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
    
    // Add this new function for clickable stat cards
    private func clickableStatCard(count: Int, title: String, icon: String, color: Color, status: TripStatus) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                // Toggle off if already selected, otherwise set to this status
                if statusFilter == status {
                    statusFilter = nil
                } else {
                    statusFilter = status
                }
                
                // Close the filter options drawer if it's open
                if showFilterOptions {
                    showFilterOptions = false
                }
                
                // Reset search text when filtering
                searchText = ""
            }
        }) {
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
                        .fill(color.opacity(statusFilter == status ? 0.12 : 0.06))
                    
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(color.opacity(statusFilter == status ? 0.5 : 0.25), lineWidth: statusFilter == status ? 2 : 1.5)
                }
            )
            .shadow(color: Color.black.opacity(statusFilter == status ? 0.1 : 0.05), radius: 10, x: 0, y: 4)
        .overlay(
                Group {
                    if statusFilter == status {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(color)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                            .position(x: 18, y: 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            )
            .frame(height: 130)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // Navigation for months
    private func previousMonth() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func goToToday() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentMonth = Date()
            selectedDate = Date()
        }
    }
    
    // Format month and year
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    // Update the calendar header view to use dynamic date
    private var calendarHeaderView: some View {
        HStack(spacing: 16) {
            Button(action: {
                previousMonth()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Text(formatMonthYear(currentMonth))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Button(action: {
                nextMonth()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            Button(action: {
                goToToday()
            }) {
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 14)
        .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // Generate dates for a month
    private func getDaysInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        
        // Get start of the month
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        // Get all dates in the month's display
        let startDate = monthFirstWeek.start
        let endDate = monthLastWeek.end
        
        var dates: [Date] = []
        var currentDate = startDate
        
        // Iterate from start to end
        while currentDate < endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    // Check if a trip is on a specific date
    private func hasTripsOn(date: Date) -> Bool {
        let calendar = Calendar.current
        return filteredTrips.contains(where: { trip in
            calendar.isDate(date, inSameDayAs: trip.scheduledStartTime) ||
            calendar.isDate(date, inSameDayAs: trip.scheduledEndTime)
        })
    }
    
    // Get trips for a specific date
    private func tripsForDate(_ date: Date) -> [Trip] {
        let calendar = Calendar.current
        return filteredTrips.filter { trip in
            calendar.isDate(date, inSameDayAs: trip.scheduledStartTime) ||
            calendar.isDate(date, inSameDayAs: trip.scheduledEndTime)
        }
    }
    
    // Enhanced version of the custom calendar view implementation
    private func enhancedCalendarView() -> some View {
        VStack(spacing: 20) {
            // Calendar grid with dynamic dates
            VStack(spacing: 12) {
                // Day headers - professionally styled
                HStack(spacing: 0) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 10)
                .padding(.horizontal, 12)
                
                // Date grid with dynamic data
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 12) {
                    ForEach(getDaysInMonth(for: currentMonth), id: \.self) { date in
                        let isInCurrentMonth = Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let hasEvents = hasTripsOn(date: date)
                        
                        calendarCell(date: date, isSelected: isSelected, hasEvents: hasEvents, isInCurrentMonth: isInCurrentMonth)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedDate = date
                                }
                            }
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 10)
            
            // Trip events for selected date
            VStack(spacing: 8) {
                HStack {
                    // Section header with date indicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatFullDate(selectedDate))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Scheduled Trips")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showAddSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Add Trip")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Display trip events for the selected date
                let tripsForSelectedDate = tripsForDate(selectedDate)
                if !tripsForSelectedDate.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(tripsForSelectedDate) { trip in
                                tripEventCard(trip: trip)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if showingExpandedTrip == trip {
                                                showingExpandedTrip = nil
            } else {
                                                showingExpandedTrip = trip
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: 400)
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 36))
                                .foregroundColor(Color(.systemGray))
                        }
                        .padding(.bottom, 12)
                        
                        Text("No trips scheduled")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(.systemGray))
                        
                        Text("Tap the '+' button to add a new trip")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.systemGray2))
                        
                        Spacer()
                    }
                    .frame(height: 240)
                    .padding(.top, 12)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .padding(.vertical, 10)
    }
    
    // Updated calendar cell with better visuals
    private func calendarCell(date: Date, isSelected: Bool, hasEvents: Bool, isInCurrentMonth: Bool) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = date
            }
        }) {
            ZStack {
                // Selection background
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                
                // Today indicator
                if isToday(date) && !isSelected {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }
                
                VStack(spacing: 4) {
                    // Date number
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 16, weight: isSelected ? .bold : (isToday(date) ? .semibold : .regular)))
                        .foregroundColor(
                            isSelected ? .white :
                                (!isInCurrentMonth ? Color(.systemGray3) : .primary)
                        )
                    
                    // Event indicator
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Color.accentColor)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .opacity(isInCurrentMonth ? 1.0 : 0.4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // Format full date
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    // Trip event card for calendar view
    private func tripEventCard(trip: Trip) -> some View {
        VStack(spacing: 0) {
            // Card Header with gradient background
            HStack(alignment: .center, spacing: 10) {
                // Time indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTimeOnly(trip.scheduledStartTime))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(formatTimeOnly(trip.scheduledEndTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 70, alignment: .leading)
                
                // Vertical separator
                Rectangle()
                    .fill(statusColor(for: trip.status).opacity(0.5))
                    .frame(width: 2, height: 36)
                
                // Title and details
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // From-To indicator with subtle animation
                        HStack(spacing: 4) {
                            Text(trip.startLocation.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                                .opacity(showingExpandedTrip == trip ? 0.8 : 0.5)
                                .scaleEffect(showingExpandedTrip == trip ? 1.2 : 1.0)
                            
                            Text(trip.endLocation.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Status badge with animation
                        Text(trip.status.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(statusColor(for: trip.status).opacity(0.1))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(statusColor(for: trip.status).opacity(0.3), lineWidth: 1)
                                    .opacity(showingExpandedTrip == trip ? 1.0 : 0.0)
                            )
                            .foregroundColor(statusColor(for: trip.status))
                    }
                }
                
                Spacer()
                
                // Right accessories with enhanced design
                if let driverId = trip.driverId, let driver = driverViewModel.getDriverById(driverId) {
                    ZStack {
                        // Outer circle
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        // Inner circle
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                        
                        // Driver initial
                        Text(String(driver.name.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                    }
                } else if let vehicleId = trip.vehicleId, let vehicle = vehicleViewModel.getVehicleById(vehicleId) {
                    ZStack {
                        // Outer circle
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        // Inner circle
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                        
                        // Vehicle icon
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        statusColor(for: trip.status).opacity(0.05)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Expandable details section with trip information
            if showingExpandedTrip == trip {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Trip details
                    VStack(alignment: .leading, spacing: 12) {
                        // Locations with improved layout
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                    
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("From")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text(trip.startLocation)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // Vertical connector line
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 2, height: 20)
                                .padding(.leading, 11)
                            
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                    
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("To")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text(trip.endLocation)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Trip details with improved layout
                        HStack(spacing: 20) {
                            // Distance info
                            if let distance = trip.distance {
                                HStack(spacing: 6) {
                                    Image(systemName: "map")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                    
                                    Text(String(format: "%.1f km", distance))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            // Duration info
                            if let routeInfo = trip.routeInfo {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                        .foregroundColor(.purple)
                                    
                                    Text(formatDuration(routeInfo.time))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            // View details button
                            Button(action: {
                                selectedTrip = trip
                            }) {
                                Text("View Details")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 10)
                }
                .background(Color(.systemGray6).opacity(0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor(for: trip.status).opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        // Add scale effect when pressed for interactive feel
        .scaleEffect(showingExpandedTrip == trip ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingExpandedTrip == trip)
    }
    
    // Date helper function that was removed
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

#Preview {
    TripManagementView(initialFilter: .ongoing)
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
} 

