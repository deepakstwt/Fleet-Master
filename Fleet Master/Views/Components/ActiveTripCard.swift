import SwiftUI

struct ActiveTripCard: View {
    let trip: Trip
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    @State private var showMap = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Trip Info Section
            VStack(alignment: .leading, spacing: 12) {
                // Title and Status
                HStack {
                    Text(trip.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Status Badge
                    Text("In Progress")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                // Locations
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.green)
                        Text(trip.startLocation)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundStyle(.red)
                        Text(trip.endLocation)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                
                Divider()
                
                // Driver and Progress
                HStack {
                    // Driver info
                    if let driver = driverViewModel.getDriverById(trip.driverId ?? "") {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            Text(driver.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Trip duration
                    if let startTime = trip.actualStartTime {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(since: startTime))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Track Location Button
                Button {
                    showMap = true
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Track Location")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.systemGray4).opacity(0.5), radius: 5)
        .sheet(isPresented: $showMap) {
            NavigationStack {
                TripMapView(startLocation: trip.startLocation, endLocation: trip.endLocation)
                    .navigationTitle("Track Vehicle")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") {
                                showMap = false
                            }
                        }
                    }
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
} 