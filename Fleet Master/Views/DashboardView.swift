import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingMapView = false
    @State private var selectedTrip: Trip?
    
    enum TimeFrame: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header section with key metrics
                HStack(spacing: 20) {
                    MetricCard(
                        title: "Active Trips",
                        value: "\(tripViewModel.inProgressTrips.count)",
                        icon: "arrow.triangle.swap",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Available Drivers",
                        value: "\(driverViewModel.availableDrivers.count)",
                        icon: "person.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Active Vehicles",
                        value: "\(vehicleViewModel.activeVehicles.count)",
                        icon: "car.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal)
                
                // Chart section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Trip Overview")
                            .font(.headline)
                        
                        Spacer()
                        
                        Picker("Time Frame", selection: $selectedTimeFrame) {
                            ForEach(TimeFrame.allCases) { timeFrame in
                                Text(timeFrame.rawValue).tag(timeFrame)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    
                    ZStack {
                        if #available(iOS 16.0, *) {
                            TripChart(trips: tripViewModel.trips, timeFrame: selectedTimeFrame)
                                .frame(height: 250)
                        } else {
                            Text("Charts available in iOS 16 and above")
                                .frame(height: 250)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Map preview section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Active Fleet Map")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            // Open detailed map view
                        }) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 200)
                        
                        // Sample map preview (replace with actual map component)
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        // Overlay showing active vehicles/trips count
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(tripViewModel.inProgressTrips.count) Active Trips")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("\(vehicleViewModel.activeVehicles.count) Vehicles on Road")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding()
                                
                                Spacer()
                            }
                            .background(Color.black.opacity(0.6))
                        }
                    }
                    .cornerRadius(12)
                    .onTapGesture {
                        // Open map view
                    }
                }
                .padding(.horizontal)
                
                // Upcoming trips section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Upcoming Trips")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: TripManagementView()) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if tripViewModel.upcomingTrips.isEmpty {
                        DashboardEmptyStateView(
                            icon: "calendar",
                            message: "No upcoming trips scheduled"
                        )
                    } else {
                        ForEach(Array(tripViewModel.upcomingTrips.prefix(3))) { trip in
                            UpcomingTripCard(
                                trip: trip,
                                driverName: trip.driverId != nil ? (driverViewModel.getDriverById(trip.driverId!)?.name ?? "Unassigned") : "Unassigned",
                                vehicleName: trip.vehicleId != nil ? formatVehicle(vehicleViewModel.getVehicleById(trip.vehicleId!)) : "Unassigned"
                            )
                            .onTapGesture {
                                selectedTrip = trip
                                showingMapView = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Driver availability section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Driver Availability")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: DriverManagementView()) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack(spacing: 15) {
                        DriverStatusCard(
                            count: driverViewModel.availableDrivers.count,
                            status: "Available",
                            color: .green
                        )
                        
                        DriverStatusCard(
                            count: driverViewModel.drivers.filter({ !$0.isAvailable && $0.isActive }).count,
                            status: "On Duty",
                            color: .orange
                        )
                        
                        DriverStatusCard(
                            count: driverViewModel.drivers.filter({ !$0.isActive }).count,
                            status: "Inactive",
                            color: .gray
                        )
                    }
                }
                .padding(.horizontal)
                
                // Vehicle status section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Vehicle Status")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: VehicleManagementView()) {
                            Text("View All")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if #available(iOS 16.0, *) {
                        VehicleStatusChart(vehicles: vehicleViewModel.vehicles)
                            .frame(height: 200)
                    } else {
                        HStack(spacing: 15) {
                            VehicleStatusCard(
                                count: vehicleViewModel.activeVehicles.count,
                                status: "Active",
                                color: .green
                            )
                            
                            VehicleStatusCard(
                                count: vehicleViewModel.vehicles.filter({ !$0.isActive }).count,
                                status: "Inactive",
                                color: .gray
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingMapView) {
            if let trip = selectedTrip {
                NavigationStack {
                    TripMapView(startLocation: trip.startLocation, endLocation: trip.endLocation)
                        .navigationTitle("Trip Route")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showingMapView = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func formatVehicle(_ vehicle: Vehicle?) -> String {
        guard let vehicle = vehicle else { return "Unknown" }
        return "\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))"
    }
}

// MARK: - Supporting Components

struct MetricCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
                
                Text("\(value)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct UpcomingTripCard: View {
    var trip: Trip
    var driverName: String
    var vehicleName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.title)
                        .font(.headline)
                    
                    Text(formatDate(trip.scheduledStartTime))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(driverName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                    }
                    
                    Label {
                        Text(vehicleName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                    Text(trip.startLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DriverStatusCard: View {
    var count: Int
    var status: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct VehicleStatusCard: View {
    var count: Int
    var status: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct DashboardEmptyStateView: View {
    var icon: String
    var message: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        }
        .frame(height: 120)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - Chart Components

@available(iOS 16.0, *)
struct TripChart: View {
    var trips: [Trip]
    var timeFrame: DashboardView.TimeFrame
    
    var body: some View {
        Chart {
            ForEach(chartData) { data in
                BarMark(
                    x: .value("Day", data.day),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(by: .value("Status", data.status))
            }
        }
        .chartForegroundStyleScale([
            "Scheduled": Color.blue,
            "In Progress": Color.orange,
            "Completed": Color.green,
            "Cancelled": Color.gray
        ])
        .chartLegend(position: .bottom, alignment: .center)
    }
    
    private var chartData: [TripChartData] {
        let calendar = Calendar.current
        let today = Date()
        
        var data: [TripChartData] = []
        var daysToShow = 7
        
        switch timeFrame {
        case .day:
            daysToShow = 1
        case .week:
            daysToShow = 7
        case .month:
            daysToShow = 30
        }
        
        for dayOffset in 0..<daysToShow {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            
            // For each day, count trips by status
            let dayTrips = trips.filter { trip in
                return calendar.isDate(trip.scheduledStartTime, inSameDayAs: date)
            }
            
            let scheduledCount = dayTrips.filter { $0.status == .scheduled }.count
            let inProgressCount = dayTrips.filter { $0.status == .inProgress }.count
            let completedCount = dayTrips.filter { $0.status == .completed }.count
            let cancelledCount = dayTrips.filter { $0.status == .cancelled }.count
            
            // Format the day string
            let formatter = DateFormatter()
            formatter.dateFormat = daysToShow > 7 ? "MMM d" : "E"
            let dayString = formatter.string(from: date)
            
            // Add data points
            if scheduledCount > 0 {
                data.append(TripChartData(day: dayString, status: "Scheduled", count: scheduledCount))
            }
            if inProgressCount > 0 {
                data.append(TripChartData(day: dayString, status: "In Progress", count: inProgressCount))
            }
            if completedCount > 0 {
                data.append(TripChartData(day: dayString, status: "Completed", count: completedCount))
            }
            if cancelledCount > 0 {
                data.append(TripChartData(day: dayString, status: "Cancelled", count: cancelledCount))
            }
            
            // If no trips, add zero data point to maintain consistent x-axis
            if dayTrips.isEmpty {
                data.append(TripChartData(day: dayString, status: "Scheduled", count: 0))
            }
        }
        
        return data.reversed()
    }
    
    struct TripChartData: Identifiable {
        var id = UUID()
        var day: String
        var status: String
        var count: Int
    }
}

@available(iOS 16.0, *)
struct VehicleStatusChart: View {
    var vehicles: [Vehicle]
    
    var body: some View {
        Chart {
            SectorMark(
                angle: .value("Count", activeVehicles),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(5)
            .foregroundStyle(.green)
            .annotation(position: .overlay) {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            
            SectorMark(
                angle: .value("Count", inactiveVehicles),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(5)
            .foregroundStyle(.gray)
            .annotation(position: .overlay) {
                Text("Inactive")
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
        }
        .frame(height: 200)
        .padding(.horizontal)
        
        HStack {
            HStack {
                Rectangle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
                Text("Active (\(activeVehicles))")
                    .font(.caption)
            }
            
            Spacer()
            
            HStack {
                Rectangle()
                    .fill(.gray)
                    .frame(width: 12, height: 12)
                Text("Inactive (\(inactiveVehicles))")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
    }
    
    private var activeVehicles: Int {
        vehicles.filter { $0.isActive }.count
    }
    
    private var inactiveVehicles: Int {
        vehicles.filter { !$0.isActive }.count
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(TripViewModel())
            .environmentObject(DriverViewModel())
            .environmentObject(VehicleViewModel())
    }
} 
