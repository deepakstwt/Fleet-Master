import SwiftUI

struct ActiveTripCard: View {
    let trip: Trip
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @State private var showMap = false
    @State private var showDriverProfile = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header with Driver Info
            HStack(alignment: .center) {
                // Trip title
                Text(trip.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(.darkGray))
                    .lineLimit(1)
                
                Spacer()
                
                // Status badge
                Text("In Progress")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // Route Information
            VStack(spacing: 18) {
                // Start location
                HStack(spacing: 12) {
                    // Start point indicator
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(trip.startLocation)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // End location with ETA
                HStack(spacing: 12) {
                    // End point indicator
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                    
                    Text(trip.endLocation)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Estimated arrival (if we have route info)
                    if let routeInfo = trip.routeInfo {
                        Text("ETA: \(formatTimeInterval(routeInfo.time))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            
            // Divider
            Divider()
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            
            // Trip duration
            if let startTime = trip.actualStartTime {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(formatDuration(since: startTime))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 10)
            }
            
            // Driver Info and Track Button Row
            HStack(alignment: .center) {
                // Driver Information (if assigned)
                if let driverId = trip.driverId, let driver = driverViewModel.getDriverById(driverId) {
                    Button(action: {
                        showDriverProfile = true
                    }) {
                        HStack(spacing: 10) {
                            // Driver avatar
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                
                                Text(String(driver.name.prefix(1)))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            
                            // Driver name
                            Text(driver.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // No driver assigned
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("No driver assigned")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Track Location Button
                
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .navigationDestination(isPresented: $showDriverProfile) {
            if let driverId = trip.driverId, let driver = driverViewModel.getDriverById(driverId) {
                // Navigate to the existing driver profile view with the actual Driver object
                DriverDetailView(driver: driver)
            }
        }
    }
    
    private func formatDuration(since startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTimeInterval(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

