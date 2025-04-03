import SwiftUI

struct ModernTripManagementView: View {
    @ObservedObject var viewModel: TripViewModel
    @ObservedObject var driverViewModel: DriverViewModel
    @ObservedObject var vehicleViewModel: VehicleViewModel
    @State private var selectedViewMode: ModernViewMode = .list
    
    enum ModernViewMode {
        case list, calendar, map
    }
    
    var body: some View {
        NavigationStack {
            ModernTripManagementContentView(
                viewModel: viewModel,
                driverViewModel: driverViewModel,
                vehicleViewModel: vehicleViewModel,
                selectedViewMode: $selectedViewMode
            )
            .navigationTitle("Trip Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addTripButton
                }
            }
        }
    }
    
    // MARK: - Add Trip Button
    
    private var addTripButton: some View {
        Button(action: {
            viewModel.isShowingAddTrip = true
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Trip")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Content View Container
struct ModernTripManagementContentView: View {
    @ObservedObject var viewModel: TripViewModel
    @ObservedObject var driverViewModel: DriverViewModel
    @ObservedObject var vehicleViewModel: VehicleViewModel
    @Binding var selectedViewMode: ModernTripManagementView.ModernViewMode
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with background blur
                TopBarSection(
                    viewModel: viewModel,
                    selectedViewMode: $selectedViewMode
                )
                
                // Main content area
                MainContentSection(
                    viewModel: viewModel,
                    driverViewModel: driverViewModel,
                    vehicleViewModel: vehicleViewModel
                )
            }
            .sheet(isPresented: $viewModel.isShowingAddTrip) {
                AddTripView()
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingEditTrip) {
                if let selectedTrip = viewModel.selectedTrip {
                    EditTripView(selectedTrip: selectedTrip)
                        .environmentObject(viewModel)
                        .environmentObject(driverViewModel)
                        .environmentObject(vehicleViewModel)
                }
            }
            .sheet(isPresented: $viewModel.isShowingAssignDriver) {
                if let selectedTrip = viewModel.selectedTrip {
                    AssignDriverView(selectedTrip: selectedTrip)
                        .environmentObject(viewModel)
                        .environmentObject(driverViewModel)
                        .environmentObject(vehicleViewModel)
                }
            }
            .alert(viewModel.alertMessage, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) { }
            }
            .refreshable {
                // Refresh data - No explicit loadTrips method exists
                // This is just for pull-to-refresh functionality
            }
            .onChange(of: viewModel.searchText) { _ in
                // Filtering happens automatically via filteredTrips computed property
            }
        }
    }
}

// MARK: - Top Bar Section
struct TopBarSection: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var selectedViewMode: ModernTripManagementView.ModernViewMode
    
    var body: some View {
        VStack(spacing: 16) {
            // Status cards
            StatusCardsSection(viewModel: viewModel)
            
            // Search bar
            SearchBarView(viewModel: viewModel)
            
            // View mode selector
            ViewModeSelectorView(selectedViewMode: $selectedViewMode)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background {
            Color.white
                .opacity(0.5)
                .background(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Status Cards Section
struct StatusCardsSection: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatusCard(
                    title: "Scheduled", 
                    count: viewModel.trips.filter { $0.status == .scheduled }.count, 
                    icon: "calendar", 
                    color: .blue
                ) {
                    viewModel.filterStatus = .scheduled
                }
                
                StatusCard(
                    title: "In Progress", 
                    count: viewModel.trips.filter { $0.status == .ongoing }.count, 
                    icon: "airplane.departure", 
                    color: .yellow
                ) {
                    viewModel.filterStatus = .ongoing
                }
                
                StatusCard(
                    title: "Completed", 
                    count: viewModel.trips.filter { $0.status == .completed }.count, 
                    icon: "checkmark.circle", 
                    color: .green
                ) {
                    viewModel.filterStatus = .completed
                }
                
                StatusCard(
                    title: "Cancelled", 
                    count: viewModel.trips.filter { $0.status == .cancelled }.count, 
                    icon: "xmark.circle", 
                    color: .red
                ) {
                    viewModel.filterStatus = .cancelled
                }
                
                StatusCard(
                    title: "All Trips",
                    count: viewModel.trips.count,
                    icon: "list.bullet.clipboard",
                    color: .purple
                ) {
                    viewModel.filterStatus = nil
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Status Card
struct StatusCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: 130, height: 90)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
        .onTapGesture(perform: action)
    }
}

// MARK: - Search Bar
struct SearchBarView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField("Search trips...", text: $viewModel.searchText)
                .font(.body)
                .padding(.vertical, 10)
                .onSubmit {
                    // Just typing in the search field will trigger the onChange
                    // and the filteredTrips computed property will filter automatically
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - View Mode Selector
struct ViewModeSelectorView: View {
    @Binding var selectedViewMode: ModernTripManagementView.ModernViewMode
    
    var body: some View {
        HStack(spacing: 8) {
            viewModeButton(mode: .list, icon: "list.bullet")
            viewModeButton(mode: .calendar, icon: "calendar")
            viewModeButton(mode: .map, icon: "map")
        }
        .padding(4)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func viewModeButton(mode: ModernTripManagementView.ModernViewMode, icon: String) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedViewMode = mode
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selectedViewMode == mode ? .white : .secondary)
                .frame(width: 90, height: 36)
                .background {
                    if selectedViewMode == mode {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Main Content Section
struct MainContentSection: View {
    @ObservedObject var viewModel: TripViewModel
    @ObservedObject var driverViewModel: DriverViewModel
    @ObservedObject var vehicleViewModel: VehicleViewModel
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                TripLoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                TripErrorView(message: errorMessage)
            } else if viewModel.filteredTrips.isEmpty {
                TripEmptyStateView(viewModel: viewModel)
            } else {
                TripListView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trip List View
struct TripListView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.filteredTrips) { trip in
                TripRowView(trip: trip, viewModel: viewModel)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .background(Color.clear)
    }
}

// MARK: - Loading View
struct TripLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Loading trips...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View
struct TripErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error Loading Trips")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                // Refresh action would go here
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
    }
}

// MARK: - Empty State
struct TripEmptyStateView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text("No Trips Found")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("Start by adding your first trip")
                .font(.footnote)
                .foregroundColor(Color(UIColor.systemGray2))
            
            Button("Add Trip") {
                viewModel.isShowingAddTrip = true
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
    }
}

// MARK: - Trip Row View

struct TripRowView: View {
    let trip: Trip
    @ObservedObject var viewModel: TripViewModel
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Trip title and ID
            HStack {
                Text(trip.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("ID: \(trip.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Locations
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    locationRow(label: "From:", location: trip.startLocation, icon: "mappin.circle")
                    locationRow(label: "To:", location: trip.endLocation, icon: "mappin.and.ellipse")
                }
                
                Spacer()
                
                // Status badge
                statusBadge(status: trip.status)
            }
            
            // Times section
            VStack(alignment: .leading, spacing: 4) {
                timeRow(label: "Scheduled:", start: trip.scheduledStartTime, end: trip.scheduledEndTime, icon: "calendar")
                
                if let actualStart = trip.actualStartTime {
                    timeRow(label: "Actual:", start: actualStart, end: trip.actualEndTime, icon: "clock")
                }
            }
            
            // Driver and Vehicle info (if assigned)
            HStack {
                if let driverId = trip.driverId {
                    Text("Driver: \(driverId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let vehicleId = trip.vehicleId {
                    Text("Vehicle: \(vehicleId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action buttons
            HStack {
                Button("Edit") {
                    viewModel.selectTripForEdit(trip: trip)
                }
                .buttonStyle(TripActionButtonStyle(color: .blue))
                
                Spacer()
                
                if trip.status == .scheduled {
                    Button("Start") {
                        viewModel.updateTripStatus(trip: trip, newStatus: .ongoing)
                    }
                    .buttonStyle(TripActionButtonStyle(color: .green))
                } else if trip.status == .ongoing {
                    Button("Complete") {
                        viewModel.updateTripStatus(trip: trip, newStatus: .completed)
                    }
                    .buttonStyle(TripActionButtonStyle(color: .green))
                }
                
                Spacer()
                
                Button("Actions") {
                    showingActionSheet = true
                }
                .buttonStyle(TripActionButtonStyle(color: .gray))
                .actionSheet(isPresented: $showingActionSheet) {
                    ActionSheet(
                        title: Text("Trip Actions"),
                        message: Text("Select an action for this trip"),
                        buttons: [
                            .default(Text("Assign Driver")) {
                                viewModel.selectedTrip = trip
                                viewModel.isShowingAssignDriver = true
                            },
                            .destructive(Text("Cancel Trip")) {
                                viewModel.cancelTrip(trip)
                            },
                            .destructive(Text("Delete Trip")) {
                                // Since there's no deleteTrip method, we need to manually remove the trip from the trips array
                                if let index = viewModel.trips.firstIndex(where: { $0.id == trip.id }) {
                                    viewModel.trips.remove(at: index)
                                }
                            },
                            .cancel()
                        ]
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func locationRow(label: String, location: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(location)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func timeRow(label: String, start: Date, end: Date?, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 14))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatTimeRange(start: start, end: end))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    private func formatTimeRange(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        if let end = end {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            return "\(formatter.string(from: start)) - ?"
        }
    }
    
    private func statusBadge(status: TripStatus) -> some View {
        let config: (Color, String) = {
            switch status {
            case .scheduled:
                return (.blue, "calendar.badge.clock")
            case .ongoing:
                return (.yellow, "arrow.triangle.swap")
            case .completed:
                return (.green, "checkmark.circle")
            case .cancelled:
                return (.red, "xmark.circle")
            }
        }()
        
        return HStack {
            Image(systemName: config.1)
            Text(status.rawValue)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(config.0.opacity(0.2))
        .foregroundColor(config.0)
        .clipShape(Capsule())
    }
}

// MARK: - Button Styles

struct TripActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct ModernTripManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ModernTripManagementView(
            viewModel: TripViewModel(),
            driverViewModel: DriverViewModel(),
            vehicleViewModel: VehicleViewModel()
        )
    }
} 
