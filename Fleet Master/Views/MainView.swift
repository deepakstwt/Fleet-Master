import SwiftUI

struct MainView: View {
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var maintenanceViewModel: MaintenanceViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @EnvironmentObject private var tripViewModel: TripViewModel
    
    enum SidebarItem: Hashable {
        case dashboard
        case driverManagement
        case maintenanceManagement
        case vehicleManagement
        case tripManagement
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .driverManagement: return "Driver Management"
            case .maintenanceManagement: return "Maintenance Management"
            case .vehicleManagement: return "Vehicle Management"
            case .tripManagement: return "Trip Management"
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "gauge"
            case .driverManagement: return "person.2.fill"
            case .maintenanceManagement: return "wrench.fill"
            case .vehicleManagement: return "car.fill"
            case .tripManagement: return "map.fill"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Main") {
                    NavigationLink(value: SidebarItem.dashboard) {
                        Label("Dashboard", systemImage: "gauge")
                    }
                }
                
                Section("User Management") {
                    NavigationLink(value: SidebarItem.driverManagement) {
                        Label("Driver Management", systemImage: "person.2.fill")
                    }
                    
                    NavigationLink(value: SidebarItem.maintenanceManagement) {
                        Label("Maintenance Management", systemImage: "wrench.fill")
                    }
                }
                
                Section("Fleet Management") {
                    NavigationLink(value: SidebarItem.vehicleManagement) {
                        Label("Vehicle Management", systemImage: "car.fill")
                    }
                    
                    NavigationLink(value: SidebarItem.tripManagement) {
                        Label("Trip Management", systemImage: "map.fill")
                    }
                }
            }
            .navigationTitle("Fleet Master")
        } detail: {
            NavigationStack {
                switch selectedSidebarItem {
                case .dashboard:
                    DashboardView()
                        .environmentObject(driverViewModel)
                        .environmentObject(vehicleViewModel)
                        .environmentObject(tripViewModel)
                case .driverManagement:
                    DriverManagementView()
                        .environmentObject(driverViewModel)
                case .maintenanceManagement:
                    MaintenanceManagementView()
                        .environmentObject(maintenanceViewModel)
                case .vehicleManagement:
                    VehicleManagementView()
                        .environmentObject(vehicleViewModel)
                case .tripManagement:
                    TripManagementView()
                        .environmentObject(tripViewModel)
                        .environmentObject(driverViewModel)
                        .environmentObject(vehicleViewModel)
                case nil:
                    // Default view when nothing is selected
                    DashboardView()
                        .environmentObject(driverViewModel)
                        .environmentObject(vehicleViewModel)
                        .environmentObject(tripViewModel)
                }
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(DriverViewModel())
        .environmentObject(MaintenanceViewModel())
        .environmentObject(VehicleViewModel())
        .environmentObject(TripViewModel())
} 
