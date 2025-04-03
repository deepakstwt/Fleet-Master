import SwiftUI
import MapKit

struct LiveMapView: View {
    let activeTrips: [Trip]
    @StateObject private var viewModel: LiveMapViewModel
    
    init(activeTrips: [Trip]) {
        self.activeTrips = activeTrips
        _viewModel = StateObject(wrappedValue: LiveMapViewModel(trips: activeTrips))
    }
    
    var body: some View {
        ZStack {
            MapViewRepresentable(
                region: $viewModel.region,
                annotations: viewModel.annotations,
                polylines: viewModel.routePolylines
            )
            
            // Controls overlay
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.refreshRoutes()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                if !activeTrips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(activeTrips) { trip in
                                LiveTripStatusCard(trip: trip)
                                    .onTapGesture {
                                        viewModel.focusOnTrip(trip)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
        .onAppear {
            viewModel.setupInitialRegion()
            viewModel.startUpdatingVehicleLocations()
        }
        .onDisappear {
            viewModel.stopUpdatingVehicleLocations()
        }
    }
}

// Custom MapView that handles both annotations and polylines
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [LiveMapViewModel.MapAnnotation]
    let polylines: [MKPolyline]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Update annotations
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)
        
        let newAnnotations = annotations.map { annotation -> CustomAnnotation in
            let customAnnotation = CustomAnnotation(
                coordinate: annotation.coordinate,
                title: annotation.label,
                isVehicle: annotation.isVehicle,
                isStart: annotation.isStart
            )
            return customAnnotation
        }
        mapView.addAnnotations(newAnnotations)
        
        // Update polylines
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlays(polylines)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let customAnnotation = annotation as? CustomAnnotation else { return nil }
            
            let identifier = customAnnotation.isVehicle ? "VehiclePin" : "LocationPin"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            if customAnnotation.isVehicle {
                // Vehicle annotation
                annotationView.glyphImage = UIImage(systemName: "car.fill")
                annotationView.markerTintColor = .systemBlue
            } else {
                // Location annotation
                annotationView.glyphImage = UIImage(systemName: customAnnotation.isStart ? "location.fill" : "location")
                annotationView.markerTintColor = customAnnotation.isStart ? .systemGreen : .systemRed
            }
            
            annotationView.canShowCallout = true
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Custom annotation class
class CustomAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let isVehicle: Bool
    let isStart: Bool
    
    init(coordinate: CLLocationCoordinate2D, title: String?, isVehicle: Bool, isStart: Bool) {
        self.coordinate = coordinate
        self.title = title
        self.isVehicle = isVehicle
        self.isStart = isStart
    }
}

// Live Trip Status Card for the map overlay
struct LiveTripStatusCard: View {
    let trip: Trip
    @EnvironmentObject private var driverViewModel: DriverViewModel
    @EnvironmentObject private var vehicleViewModel: VehicleViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Vehicle and driver info
            HStack {
                if let vehicle = vehicleViewModel.getVehicleById(trip.vehicleId ?? "") {
                    Text(vehicle.registrationNumber)
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if let driver = driverViewModel.getDriverById(trip.driverId ?? "") {
                    Text(driver.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress info
            if let startTime = trip.actualStartTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(formatDuration(since: startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color(.systemGray4).opacity(0.5), radius: 2)
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

// View Model for Live Map
class LiveMapViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var annotations: [MapAnnotation] = []
    @Published var routePolylines: [MKPolyline] = []
    
    private var trips: [Trip]
    private var locationManager = LocationManager()
    private var timer: Timer?
    private var tripAnnotations: [String: [MapAnnotation]] = [:]
    
    struct MapAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let label: String?
        let isStart: Bool
        let isVehicle: Bool
        let tripId: String?
        
        init(coordinate: CLLocationCoordinate2D, label: String? = nil, isStart: Bool = false, isVehicle: Bool = false, tripId: String? = nil) {
            self.coordinate = coordinate
            self.label = label
            self.isStart = isStart
            self.isVehicle = isVehicle
            self.tripId = tripId
        }
    }
    
    init(trips: [Trip]) {
        self.trips = trips
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3352, longitude: -122.0096),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    }
    
    func setupInitialRegion() {
        guard !trips.isEmpty else { return }
        loadAllRoutes()
    }
    
    func startUpdatingVehicleLocations() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateVehicleLocations()
        }
    }
    
    func stopUpdatingVehicleLocations() {
        timer?.invalidate()
        timer = nil
    }
    
    func refreshRoutes() {
        loadAllRoutes()
    }
    
    func focusOnTrip(_ trip: Trip) {
        if let tripAnnotations = tripAnnotations[trip.id],
           let vehicleAnnotation = tripAnnotations.first(where: { $0.isVehicle }) {
            withAnimation {
                region = MKCoordinateRegion(
                    center: vehicleAnnotation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
    
    private func loadAllRoutes() {
        annotations.removeAll()
        routePolylines.removeAll()
        tripAnnotations.removeAll()
        
        for trip in trips {
            loadRoute(for: trip)
        }
    }
    
    private func loadRoute(for trip: Trip) {
        locationManager.calculateRoute(from: trip.startLocation, to: trip.endLocation) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let route):
                    // Add route polyline
                    self.routePolylines.append(route.polyline)
                    
                    // Add start and end annotations
                    let startCoordinate = route.polyline.points()[0]
                    let endCoordinate = route.polyline.points()[route.polyline.pointCount - 1]
                    
                    let tripAnnotations = [
                        MapAnnotation(
                            coordinate: startCoordinate.coordinate,
                            label: "Start",
                            isStart: true,
                            isVehicle: false,
                            tripId: trip.id
                        ),
                        MapAnnotation(
                            coordinate: endCoordinate.coordinate,
                            label: "End",
                            isStart: false,
                            isVehicle: false,
                            tripId: trip.id
                        ),
                        MapAnnotation(
                            coordinate: self.interpolateLocation(
                                start: startCoordinate.coordinate,
                                end: endCoordinate.coordinate,
                                fraction: 0.3
                            ),
                            label: nil,
                            isStart: false,
                            isVehicle: true,
                            tripId: trip.id
                        )
                    ]
                    
                    self.tripAnnotations[trip.id] = tripAnnotations
                    self.annotations.append(contentsOf: tripAnnotations)
                    
                    // Update region to show all annotations
                    if self.routePolylines.count == 1 {
                        self.region = self.calculateRegion(for: route)
                    }
                    
                    case .failure(_): break
                    // Failed to load route
                }
            }
        }
    }
    
    private func updateVehicleLocations() {
        withAnimation {
            for trip in trips {
                guard let tripAnnotations = tripAnnotations[trip.id],
                      let startAnnotation = tripAnnotations.first(where: { $0.isStart }),
                      let endAnnotation = tripAnnotations.first(where: { !$0.isStart && !$0.isVehicle }),
                      let vehicleIndex = annotations.firstIndex(where: { $0.isVehicle && $0.tripId == trip.id }) else {
                    continue
                }
                
                // Calculate progress based on elapsed time
                let progress: Double
                if let startTime = trip.actualStartTime {
                    let totalDuration = trip.scheduledEndTime.timeIntervalSince(trip.scheduledStartTime)
                    let elapsed = Date().timeIntervalSince(startTime)
                    progress = min(max(elapsed / totalDuration, 0), 1)
                } else {
                    progress = 0.3 // Default position if not started
                }
                
                // Update vehicle position
                let newPosition = interpolateLocation(
                    start: startAnnotation.coordinate,
                    end: endAnnotation.coordinate,
                    fraction: progress
                )
                
                annotations[vehicleIndex] = MapAnnotation(
                    coordinate: newPosition,
                    isVehicle: true,
                    tripId: trip.id
                )
            }
        }
    }
    
    private func interpolateLocation(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let lat = start.latitude + (end.latitude - start.latitude) * fraction
        let lon = start.longitude + (end.longitude - start.longitude) * fraction
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private func calculateRegion(for route: MKRoute) -> MKCoordinateRegion {
        let rect = route.polyline.boundingMapRect
        let center = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: rect.size.height * 0.0001 * 1.5,
                longitudeDelta: rect.size.width * 0.0001 * 1.5
            )
        )
    }
} 
