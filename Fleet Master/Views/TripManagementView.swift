import SwiftUI

struct TripManagementView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
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
    
    enum ViewMode {
        case list
        case calendar
        case map
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with stats and search bar
                headerSection
                
                // View type selector and filters
                controlSection
                
                // Content based on view mode
                contentSection
            }
            .navigationTitle("Trip Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showAddSheet = true
                    }) {
                        Label("Schedule New Trip", systemImage: "plus.circle")
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
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddTripView()
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showEditSheet) {
                if let trip = selectedTrip {
                    NavigationStack {
                        EditTripView(selectedTrip: trip)
                    }
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showAssignDriverSheet) {
                if let trip = selectedTrip {
                    NavigationStack {
                        AssignDriverView(selectedTrip: trip)
                    }
                    .presentationDetents([.medium])
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Trip stats row
            HStack(spacing: 12) {
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
            .padding(.horizontal)
            
            // Search bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search trips by title, location...", text: $searchText)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button(action: {
                    withAnimation(.spring()) {
                        showFilterOptions.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        Text(statusFilter?.rawValue ?? "All")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var controlSection: some View {
        VStack(spacing: 8) {
            // View type selector
            Picker("View", selection: $viewMode) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("List")
                }.tag(ViewMode.list)
                
                HStack {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }.tag(ViewMode.calendar)
                
                HStack {
                    Image(systemName: "map")
                    Text("Map")
                }.tag(ViewMode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Filter options
            if showFilterOptions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterButton(title: "All Trips", status: nil)
                        filterButton(title: "Scheduled", status: .scheduled)
                        filterButton(title: "In Progress", status: .inProgress)
                        filterButton(title: "Completed", status: .completed)
                        filterButton(title: "Cancelled", status: .cancelled)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .background(Color(.systemBackground))
            }
            
            Divider()
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
                    ScheduledTripsCalendarView()
                case .map:
                    tripMapOverview
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
                        showDetailView = true
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
                                tripViewModel.cancelTrip(trip)
                                alertMessage = "Trip has been cancelled."
                                showAlert = true
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
                                tripViewModel.updateTripStatus(trip: trip, newStatus: .inProgress)
                                alertMessage = "Trip has been started."
                                showAlert = true
                            }) {
                                Label("Start", systemImage: "play.circle")
                            }
                            .tint(.green)
                        } else if trip.status == .inProgress {
                            Button(action: {
                                tripViewModel.updateTripStatus(trip: trip, newStatus: .completed)
                                alertMessage = "Trip has been completed."
                                showAlert = true
                            }) {
                                Label("Complete", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                        }
                    }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .sheet(isPresented: $showDetailView) {
            if let trip = selectedTrip {
                NavigationStack {
                    TripDetailView(trip: trip)
                }
                .presentationDetents([.large])
            }
        }
    }
    
    private var tripMapOverview: some View {
        VStack(spacing: 20) {
            // Placeholder for the map functionality
            ZStack {
                Color(.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Map View Coming Soon")
                        .font(.headline)
                    
                    Text("Trip mapping functionality will be available in a future update.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                    
                    // Button to switch to list view
                    Button(action: {
                        withAnimation {
                            viewMode = .list
                        }
                    }) {
                        Label("Switch to List View", systemImage: "list.bullet")
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
                .padding()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.accentColor.opacity(0.7))
            
            Text("No Trips Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Start by adding your first trip")
                .foregroundColor(.secondary)
            
            Button(action: {
                showAddSheet = true
            }) {
                Text("Add Trip")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 12)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - UI Components
    
    private func statCard(count: Int, title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func filterButton(title: String, status: TripStatus?) -> some View {
        Button(action: {
            withAnimation {
                statusFilter = status
            }
        }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(statusFilter == status ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(statusFilter == status ? Color.accentColor : Color(.systemGray5))
                )
        }
    }
    
    private func modernTripCard(trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Trip status icon and title
                HStack(alignment: .center) {
                    statusIcon(for: trip.status)
                        .padding(6)
                        .background(statusColor(for: trip.status).opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
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
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: trip.status).opacity(0.15))
                    .foregroundColor(statusColor(for: trip.status))
                    .cornerRadius(20)
            }
            
            Divider()
            
            // Locations with icons
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 10) {
                    // Start indicator dot
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    
                    // Route line
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                    
                    // End indicator dot
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                }
                .frame(height: 50)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Start location
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(trip.startLocation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    // End location
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(trip.endLocation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Assignment and distance info
            HStack(spacing: 16) {
                // Driver info
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                    
                    Text(getDriverName(for: trip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Vehicle info
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .foregroundColor(.secondary)
                    
                    Text(getVehicleName(for: trip))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Distance
                if let distance = trip.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("\(String(format: "%.1f", distance)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Show progress bar for in-progress trips
            if trip.status == .inProgress {
                ProgressView(value: calculateProgress(for: trip))
                    .tint(statusColor(for: trip.status))
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        )
        .padding(.vertical, 4)
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
}

#Preview {
    TripManagementView()
        .environmentObject(TripViewModel())
        .environmentObject(DriverViewModel())
        .environmentObject(VehicleViewModel())
}
