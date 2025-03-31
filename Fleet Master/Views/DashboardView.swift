import SwiftUI
import Charts
import MapKit

struct DashboardView: View {
    @EnvironmentObject private var tripViewModel: TripViewModel
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @State private var showNotificationCenter = false
    @State private var selectedTrip: Trip?
    @State private var showTripDetail = false
    
    var body: some View {
        NavigationStack {
        ScrollView {
                VStack(spacing: 24) {
                    // KPI Metrics (Fleet Summary)
                    VStack(spacing: 24) {  // Increased spacing
                        Text("Fleet Summary")
                            .font(.title)  // Larger title
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // KPI Grid with larger spacing
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 20),
                                GridItem(.flexible(), spacing: 20)
                            ],
                            spacing: 20
                        ) {
                            // Total Vehicles KPI
                            KPICard(
                                title: "Total Vehicles",
                                value: "",
                                icon: "car.fill",
                                details: [
                                    KPIDetail(
                                        label: "Active",
                                        value: "\(vehicleViewModel.activeVehicles.count)",
                                        color: Color(hex: "1E3A8A")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Under Maintenance",
                                        value: "\(vehicleViewModel.vehicles.filter { !$0.isActive }.count)",
                                        color: Color(hex: "1E3A8A")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Idle",
                                        value: "0",
                                        color: Color(hex: "1E3A8A")  // Using primary gradient color
                                    )
                                ]
                            )
                            
                            // Drivers KPI
                            KPICard(
                                title: "Drivers",
                                value: "",
                                icon: "person.2.fill",
                                details: [
                                    KPIDetail(
                                        label: "Available",
                                        value: "\(driverViewModel.availableDrivers.count)",
                                        color: Color(hex: "059669")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "On Trip",
                                        value: "\(driverViewModel.drivers.filter { !$0.isAvailable && $0.isActive }.count)",
                                        color: Color(hex: "059669")  // Using primary gradient color
                                    )
                                ]
                            )
                            
                            // Maintenance KPI
                            KPICard(
                                title: "Maintenance",
                                value: "",
                                icon: "wrench.fill",
                                details: [
                                    KPIDetail(
                                        label: "In Progress",
                                        value: "\(vehicleViewModel.vehicles.filter { !$0.isActive }.count)",
                                        color: Color(hex: "C2410C")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Scheduled",
                                        value: "0",
                                        color: Color(hex: "C2410C")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Overdue",
                                        value: "0",
                                        color: Color(hex: "C2410C")  // Using primary gradient color
                                    )
                                ]
                            )
                            
                            // Active Trips KPI
                            KPICard(
                                title: "Active Trips",
                                value: "",
                                icon: "arrow.triangle.swap",
                                details: [
                                    KPIDetail(
                                        label: "In Progress",
                                        value: "\(tripViewModel.inProgressTrips.count)",
                                        color: Color(hex: "4F46E5")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Scheduled",
                                        value: "0",
                                        color: Color(hex: "4F46E5")  // Using primary gradient color
                                    ),
                                    KPIDetail(
                                        label: "Delayed",
                                        value: "0",
                                        color: Color(hex: "4F46E5")  // Using primary gradient color
                                    )
                                ]
                            )
            }
            .padding(.horizontal)
                    }
                    
                    // Active Trips Section
                    VStack(alignment: .leading, spacing: 16) {
                    HStack {
                            Text("Active Trips")
                                .font(.title2)
                                .fontWeight(.bold)
                        
                        Spacer()
                        
                            NavigationLink(destination: TripManagementView()) {
                            Text("View All")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        if tripViewModel.inProgressTrips.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "car.2.fill")
                            .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No Active Trips")
                                        .font(.headline)
                                Text("All vehicles are currently stationary")
                                        .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color(.systemGray4).opacity(0.5), radius: 5)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(tripViewModel.inProgressTrips) { trip in
                                    ActiveTripCard(trip: trip)
                                }
                            }
                            .padding(.horizontal)
                        }
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
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
        }
    }
}

// KPI Detail Model
struct KPIDetail {
    let label: String
    let value: String
    let color: Color
}

// KPI Card Component
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let details: [KPIDetail]
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with icon and title
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 35))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: iconGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: iconGradient[0].opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text(title)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                ForEach(details, id: \.label) { detail in
                    HStack(alignment: .center, spacing: 12) {
                        // Indicator dot (using primary color)
                        Circle()
                            .fill(iconGradient[0])
                            .frame(width: 8, height: 8)
                        
                        // Label and value
                        HStack {
                            Text(detail.label)
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(detail.value)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(iconGradient[0])
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(cardGradient)
                    .opacity(isHovered ? 0.15 : 0.1)
                
                // Glass effect overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            iconGradient[0].opacity(isHovered ? 0.3 : 0.1),
                            iconGradient[1].opacity(isHovered ? 0.2 : 0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: iconGradient[0].opacity(0.1), radius: isHovered ? 15 : 10, x: 0, y: 4)
        .shadow(color: iconGradient[1].opacity(0.05), radius: isHovered ? 5 : 1, x: 0, y: 1)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
    }
    
    // Gradient colors based on card type with semantic meaning
    private var iconGradient: [Color] {
        switch title {
        case "Total Vehicles":
            // Deep Blue to Royal Blue - Automotive industry standard colors
            // Represents reliability, professionalism, and trust
            return [Color(hex: "1E3A8A"), Color(hex: "3B82F6")]
        case "Drivers":
            // Forest Green to Emerald - Human resource management colors
            // Represents growth, safety, and personnel
            return [Color(hex: "059669"), Color(hex: "34D399")]
        case "Maintenance":
            // Deep Orange to Amber - Universal maintenance colors
            // Represents caution, attention, and industrial standards
            return [Color(hex: "C2410C"), Color(hex: "F59E0B")]
        case "Active Trips":
            // Indigo to Purple - Movement and energy colors
            // Represents dynamic activity and navigation
            return [Color(hex: "4F46E5"), Color(hex: "8B5CF6")]
        default:
            return [.blue, .blue.opacity(0.7)]
        }
    }
    
    // Card background gradient based on card type
    private var cardGradient: some ShapeStyle {
        LinearGradient(
            colors: iconGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
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
