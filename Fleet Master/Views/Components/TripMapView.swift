import SwiftUI
import MapKit

struct TripMapView: View {
    var startLocation: String
    var endLocation: String
    @StateObject private var viewModel = TripMapViewModel()
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.mapAnnotations) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: annotation.color)
            }
            .overlay(
                MapOverlay(polylines: viewModel.routePolylines)
            )
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Calculating route...")
                        .padding(.top, 5)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            }
            
            if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .padding(.top, 5)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.loadRoute(from: startLocation, to: endLocation)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 2)
                    }
                    .padding()
                }
                
                Spacer()
                
                if let tripInfo = viewModel.tripInfo {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("Est. Time: \(formatDuration(tripInfo.expectedTravelTime))")
                                    .font(.callout)
                            }
                            
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(.secondary)
                                Text("Distance: \(formatDistance(tripInfo.distance))")
                                    .font(.callout)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.loadRoute(from: startLocation, to: endLocation)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let kilometers = meters / 1000
        return String(format: "%.1f km", kilometers)
    }
}

struct MapOverlay: UIViewRepresentable {
    var polylines: [MKPolyline]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.alpha = 1
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlays(polylines)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct MapAnnotation: Identifiable {
    var id = UUID()
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var iconName: String
    var color: Color
}

class TripMapViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3352, longitude: -122.0096),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @Published var mapAnnotations: [MapAnnotation] = []
    @Published var routePolylines: [MKPolyline] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var tripInfo: (expectedTravelTime: TimeInterval, distance: CLLocationDistance)?
    
    private let locationManager = LocationManager()
    
    func loadRoute(from startLocation: String, to endLocation: String) {
        isLoading = true
        errorMessage = nil
        tripInfo = nil
        mapAnnotations = []
        routePolylines = []
        
        locationManager.calculateRoute(from: startLocation, to: endLocation) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let route):
                    // Add route polyline
                    self.routePolylines = [route.polyline]
                    
                    // Add start and end annotations
                    let startCoordinate = route.polyline.points()[0]
                    let endCoordinate = route.polyline.points()[route.polyline.pointCount - 1]
                    
                    self.mapAnnotations = [
                        MapAnnotation(
                            coordinate: startCoordinate.coordinate,
                            title: "Start",
                            iconName: "mappin.circle.fill",
                            color: .green
                        ),
                        MapAnnotation(
                            coordinate: endCoordinate.coordinate,
                            title: "End",
                            iconName: "mappin.and.ellipse",
                            color: .red
                        )
                    ]
                    
                    // Set the map region to cover the route
                    self.region = self.calculateRegionForRoute(route: route)
                    
                    // Update trip info
                    self.tripInfo = (route.expectedTravelTime, route.distance)
                    
                case .failure(let error):
                    self.errorMessage = "Couldn't calculate route: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Calculate the region to display the route
    private func calculateRegionForRoute(route: MKRoute) -> MKCoordinateRegion {
        let rect = route.polyline.boundingMapRect
        let center = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        
        // Add some padding around the route
        let span = MKCoordinateSpan(
            latitudeDelta: rect.size.height * 0.0001 * 1.5,
            longitudeDelta: rect.size.width * 0.0001 * 1.5
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    TripMapView(startLocation: "1 Infinite Loop, Cupertino, CA", endLocation: "1 Apple Park Way, Cupertino, CA")
        .frame(height: 400)
} 