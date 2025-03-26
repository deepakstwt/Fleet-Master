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
                    HStack(spacing: 16) {
                        // Vehicles Card
                        DashboardCard(
                            title: "Vehicles",
                            icon: "car.fill",
                            color: .blue,
                            content: {
                                StatRow(title: "Total", value: "\(vehicleViewModel.vehicles.count)", valueColor: .blue)
                                StatRow(title: "Available", value: "\(vehicleViewModel.activeVehicles.count)", valueColor: .green)
                                StatRow(title: "On Duty", value: "\(vehicleViewModel.vehicles.filter { !$0.isActive }.count)", valueColor: .red)
                            }
                        )
                        
                        // Drivers Card
                        DashboardCard(
                            title: "Drivers",
                            icon: "person.2.fill",
                            color: .indigo,
                            content: {
                                StatRow(title: "Total", value: "\(driverViewModel.drivers.count)", valueColor: .indigo)
                                StatRow(title: "Available", value: "\(driverViewModel.availableDrivers.count)", valueColor: .green)
                                StatRow(title: "On Duty", value: "\(driverViewModel.drivers.filter { !$0.isAvailable && $0.isActive }.count)", valueColor: .orange)
                            }
                        )
                        
                        // Trips Card
                        DashboardCard(
                            title: "Trips",
                            icon: "arrow.triangle.swap",
                            color: .purple,
                            content: {
                                StatRow(title: "Scheduled", value: "\(tripViewModel.trips.count)", valueColor: .purple)
                                StatRow(title: "Active", value: "\(tripViewModel.inProgressTrips.count)", valueColor: .blue)
                                StatRow(title: "Completed", value: "\(tripViewModel.trips.filter { Calendar.current.isDateInToday($0.scheduledStartTime) }.count)", valueColor: .green)
                            }
                        )
            }
            .padding(.horizontal)
                    
                    // Costs Card
                    DashboardCard(
                        title: "Costs",
                        icon: "indianrupeesign",
                        color: .green,
                        isFullWidth: true,
                        content: {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Monthly Fuel Cost")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("₹ \(String(format: "%.2f", monthlyFuelCosts.last?.cost ?? 0))")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                    
                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.up.right")
                                            Text("12%")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        
                                        Text("vs last month")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Chart {
                                    ForEach(monthlyFuelCosts, id: \.month) { item in
                                        BarMark(
                                            x: .value("Month", item.month),
                                            y: .value("Cost", item.cost)
                                        )
                                        .foregroundStyle(Color.green.gradient)
                                    }
                                }
                                .frame(height: 150)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisValueLabel {
                                            if let cost = value.as(Double.self) {
                                                Text("₹\(Int(cost/1000))k")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let month = value.as(String.self) {
                                                Text(month)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
                    
                    // Maintenance Statistics
                    DashboardCard(
                        title: "Maintenance",
                        icon: "wrench.and.screwdriver.fill",
                        color: .orange,
                        isFullWidth: true,
                        content: {
                            VStack(spacing: 16) {
                                // Maintenance Status Cards
                                VStack(spacing: 12) {
                                    // Currently Under Maintenance Card
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: "wrench.fill")
                                                    .foregroundStyle(.orange)
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Currently Under Maintenance")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("4 Vehicles")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    // Driver Reported Issues Card
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.red.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundStyle(.red)
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Driver Pending requests.")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("7 Requests")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                        
                        Spacer()
                        
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    // Upcoming Service Card
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: "calendar.badge.clock")
                                                    .foregroundStyle(.blue)
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Upcoming Service Due")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("12 Vehicles")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        
                            Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                // Maintenance Cost Statistics
                                HStack(spacing: 16) {
                                    // Monthly Cost Card
                                    VStack(spacing: 8) {
                                        Text("830$")
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text("Total Monthly maintenance cost")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .padding(24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.blue.opacity(0.7), .green.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    
                                    // Average Cost Card
                                    VStack(spacing: 8) {
                                        Text("48$")
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text("Average cost per vehicle")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .padding(24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.green.opacity(0.7), .blue.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                }

                                // Top Costliest Vehicles
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Top Costliest Vehicles")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 4)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            // Most Expensive Vehicle
                                            VStack(alignment: .leading, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("KA01AB1234")
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                    
                                                    Text("₹35,000")
                                                        .font(.title2)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                                
                                                Divider()
                                                    .background(.white.opacity(0.3))
                                                
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text("Engine Overhaul")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.white.opacity(0.9))
                                                    
                                                    Text("Last repair: 2 days ago")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                }
                                            }
                                            .padding()
                                            .frame(width: 220)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(red: 0.2, green: 0.3, blue: 0.4), Color(red: 0.1, green: 0.15, blue: 0.2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            // Second Most Expensive
                                            VStack(alignment: .leading, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("KA01CD5678")
                            .font(.headline)
                                                        .foregroundStyle(.white)
                                                    
                                                    Text("₹28,000")
                                                        .font(.title2)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                                
                                                Divider()
                                                    .background(.white.opacity(0.3))
                                                
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text("Transmission Repair")
                                .font(.subheadline)
                                                        .foregroundStyle(.white.opacity(0.9))
                                                    
                                                    Text("Last repair: 5 days ago")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                }
                                            }
                                            .padding()
                                            .frame(width: 220)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(red: 0.25, green: 0.35, blue: 0.45), Color(red: 0.15, green: 0.2, blue: 0.25)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            // Third Most Expensive
                                            VStack(alignment: .leading, spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("KA01EF9012")
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                    
                                                    Text("₹22,000")
                                                        .font(.title2)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                                
                                                Divider()
                                                    .background(.white.opacity(0.3))
                                                
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text("Brake System")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.white.opacity(0.9))
                                                    
                                                    Text("Last repair: 1 week ago")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                }
                                            }
                                            .padding()
                                            .frame(width: 220)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(red: 0.3, green: 0.4, blue: 0.5), Color(red: 0.2, green: 0.25, blue: 0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }

                                // Frequent Repairs List
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Most Frequent Repairs")
                            .font(.headline)
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 4)
                                    
                                    VStack(spacing: 12) {
                                        // Engine Oil Change
                                        FrequentRepairRow(
                                            icon: "engine.combustion.fill",
                                            iconColor: .orange,
                                            repairType: "Engine Oil Change"
                                        )
                                        
                                        // Tire Replacement
                                        FrequentRepairRow(
                                            icon: "car.wheel.and.tire",
                                            iconColor: .blue,
                                            repairType: "Tire Replacement"
                                        )
                                        
                                        // Brake Service
                                        FrequentRepairRow(
                                            icon: "brake",
                                            iconColor: .red,
                                            repairType: "Brake Service"
                                        )
                                        
                                        
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
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
    
    var body: some View {
            HStack {
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
