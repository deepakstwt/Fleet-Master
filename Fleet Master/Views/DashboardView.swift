import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @State private var showNotificationCenter = false
    
    // Sample data for the fuel costs chart
    let monthlyFuelCosts: [(month: String, cost: Double)] = [
        ("Jan", 2450),
        ("Feb", 2100),
        ("Mar", 2800),
        ("Apr", 2300),
        ("May", 2600),
        ("Jun", 2900)
    ]
    
    var body: some View {
        NavigationStack {
        ScrollView {
                VStack(spacing: 24) {
                    // Main Stats Section
                    VStack(spacing: 16) {
                        // Top Row
                        HStack(spacing: 16) {
                            // Fleet Overview Card
                            DashboardCard(
                                title: "Fleet Overview",
                                icon: "car.2.fill",
                                color: .blue,
                                content: {
                                    VStack(spacing: 12) {
                                        StatRow(
                                            title: "Total Vehicles",
                                            value: "\(vehicleViewModel.vehicles.count)",
                                            valueColor: .blue,
                                            icon: "car.fill"
                                        )
                                        StatRow(
                                            title: "In Use",
                                            value: "\(vehicleViewModel.activeVehicles.count)",
                                            valueColor: .green,
                                            icon: "checkmark.circle.fill"
                                        )
                                        StatRow(
                                            title: "Under Maintenance",
                                            value: "\(vehicleViewModel.vehicles.filter { !$0.isActive }.count)",
                                            valueColor: .red,
                                            icon: "wrench.fill"
                                        )
                                    }
                                }
                            )
                            
                            // Driver Overview Card
                            DashboardCard(
                                title: "Driver Overview",
                                icon: "person.2.fill",
                                color: .indigo,
                                content: {
                                    VStack(spacing: 12) {
                                        StatRow(
                                            title: "Total Drivers",
                                            value: "\(driverViewModel.drivers.count)",
                                            valueColor: .indigo,
                                            icon: "person.fill"
                                        )
                                        StatRow(
                                            title: "Available",
                                            value: "\(driverViewModel.availableDrivers.count)",
                                            valueColor: .green,
                                            icon: "checkmark.circle.fill"
                                        )
                                        StatRow(
                                            title: "On Duty",
                                            value: "\(driverViewModel.drivers.filter { !$0.isAvailable && $0.isActive }.count)",
                                            valueColor: .orange,
                                            icon: "figure.walk"
                                        )
                                    }
                                }
                            )
                        }
                        .padding(.horizontal)
                        
                        // Bottom Row
                        HStack(spacing: 16) {
                            // Trips Card
                            DashboardCard(
                                title: "Trips Overview",
                                icon: "arrow.triangle.swap",
                                color: .purple,
                                content: {
                                    VStack(spacing: 12) {
                                        StatRow(
                                            title: "Scheduled",
                                            value: "\(tripViewModel.trips.count)",
                                            valueColor: .purple,
                                            icon: "calendar.badge.clock"
                                        )
                                        StatRow(
                                            title: "Active",
                                            value: "\(tripViewModel.inProgressTrips.count)",
                                            valueColor: .blue,
                                            icon: "arrow.triangle.branch"
                                        )
                                        StatRow(
                                            title: "Pending",
                                            value: "5",
                                            valueColor: .orange,
                                            icon: "clock.fill"
                                        )
                                        StatRow(
                                            title: "Completed",
                                            value: "\(tripViewModel.trips.filter { Calendar.current.isDateInToday($0.scheduledStartTime) }.count)",
                                            valueColor: .green,
                                            icon: "checkmark.circle.fill"
                                        )
                                    }
                                }
                            )
                            
                            // Maintenance Overview Card
                            DashboardCard(
                                title: "Maintenance Overview",
                                icon: "wrench.and.screwdriver.fill",
                                color: .orange,
                                content: {
                                    VStack(spacing: 12) {
                                        StatRow(
                                            title: "Vehicles Under Maintenance",
                                            value: "4",
                                            valueColor: .orange,
                                            icon: "wrench.fill"
                                        )
                                        StatRow(
                                            title: "Upcoming",
                                            value: "12",
                                            valueColor: .blue,
                                            icon: "calendar.badge.clock"
                                        )
                                        StatRow(
                                            title: "Delayed Repairs",
                                            value: "5",
                                            valueColor: .red,
                                            icon: "exclamationmark.triangle.fill"
                                        )
                                        StatRow(
                                            title: "Monthly Maintenance Cost",
                                            value: "₹83,000",
                                            valueColor: .green,
                                            icon: "indianrupeesign.circle.fill"
                                        )
                                    }
                                }
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                                        
                                    }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNotificationCenter = true
                    } label: {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterView()
            }
        }
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    var isFullWidth: Bool = false
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .background {
            if isFullWidth {
                // Regular card background for full-width cards
                Color(.systemBackground)
            } else {
                // Enhanced glass effect for small cards
                ZStack {
                    Color(.systemBackground)
                        .opacity(0.7)
                    
                    // Enhanced gradient overlay
                    LinearGradient(
                        colors: [
                            .white.opacity(0.7),
                            .white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .blur(radius: 0.5)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Multiple layered shadows for depth
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 0)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        // Enhanced border for glass effect
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    .linearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .white.opacity(0.2),
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFullWidth ? 0 : 1
                )
        )
        // Outer glow effect
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: isFullWidth ? 0 : 2)
                .blur(radius: 4)
        )
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let valueColor: Color
    let icon: String?
    
    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
        }
    }
}

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: NotificationType = .driver
    
    enum NotificationType: String, CaseIterable {
        case driver = "Drivers"
        case maintenance = "Maintenance"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Notification Type", selection: $selectedTab) {
                    ForEach(NotificationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Notification List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<(selectedTab == .driver ? 5 : 3), id: \.self) { _ in
                            NotificationRow(
                                title: selectedTab == .driver ? "Trip Completed" : "Vehicle Service Required",
                                message: selectedTab == .driver ? 
                                    "Driver John Doe completed trip #1234" : 
                                    "Vehicle ABC-123 requires maintenance",
                                time: selectedTab == .driver ? "2 minutes ago" : "1 hour ago",
                                type: selectedTab
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NotificationRow: View {
    let title: String
    let message: String
    let time: String
    let type: NotificationCenterView.NotificationType
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(type == .driver ? .blue : .orange)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: type == .driver ? "person.fill" : "wrench.fill")
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .background(Color(.systemBackground))
    }
}

struct FrequentRepairRow: View {
    let icon: String
    let iconColor: Color
    let repairType: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
            
            // Repair Type
            Text(repairType)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
        DashboardView()
            .environmentObject(TripViewModel())
            .environmentObject(DriverViewModel())
            .environmentObject(VehicleViewModel())
} 
