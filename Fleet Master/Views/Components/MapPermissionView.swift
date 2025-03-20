import SwiftUI
import CoreLocation

struct MapPermissionView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To provide optimal route planning and navigation features, Fleet Master needs access to your location.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                PermissionFeatureRow(icon: "route", text: "Calculate optimal routes between locations")
                PermissionFeatureRow(icon: "clock.arrow.circlepath", text: "Provide accurate travel time estimates")
                PermissionFeatureRow(icon: "location.fill", text: "Allow drivers to track their position on routes")
            }
            .padding(.vertical)
            
            if locationStatus == .denied {
                Text("Location access has been denied. Please update your settings to use map features.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            } else {
                Button(action: {
                    locationManager.requestLocationPermission()
                }) {
                    Text("Allow Location Access")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            checkLocationPermission()
        }
    }
    
    private func checkLocationPermission() {
        let status = CLLocationManager().authorizationStatus
        locationStatus = status
    }
}

struct PermissionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
        }
        .padding(.horizontal)
    }
}

#Preview {
    MapPermissionView()
} 