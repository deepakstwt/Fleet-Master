import Foundation
import CoreLocation
import MapKit
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isLoadingLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        isLoadingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
    }
    
    // MARK: - Geocoding
    
    func geocodeAddress(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                completion(.failure(NSError(domain: "LocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to geocode address"])))
                return
            }
            
            completion(.success(location.coordinate))
        }
    }
    
    func reverseLookupLocation(_ coordinate: CLLocationCoordinate2D, completion: @escaping (Result<String, Error>) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(.failure(NSError(domain: "LocationManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No placemark found"])))
                return
            }
            
            let address = [
                placemark.thoroughfare,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
            
            completion(.success(address))
        }
    }
    
    // MARK: - Route Calculation
    
    func calculateRoute(from startAddress: String, to endAddress: String, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        // First geocode the start address
        geocodeAddress(startAddress) { [weak self] startResult in
            guard let self = self else { return }
            
            switch startResult {
            case .success(let startCoordinate):
                // Then geocode the end address
                self.geocodeAddress(endAddress) { endResult in
                    switch endResult {
                    case .success(let endCoordinate):
                        // Create source and destination placemarks
                        let sourcePlacemark = MKPlacemark(coordinate: startCoordinate)
                        let destinationPlacemark = MKPlacemark(coordinate: endCoordinate)
                        
                        // Create routing request
                        let request = MKDirections.Request()
                        request.source = MKMapItem(placemark: sourcePlacemark)
                        request.destination = MKMapItem(placemark: destinationPlacemark)
                        request.transportType = .automobile
                        
                        // Calculate route
                        let directions = MKDirections(request: request)
                        directions.calculate { response, error in
                            if let error = error {
                                completion(.failure(error))
                                return
                            }
                            
                            guard let route = response?.routes.first else {
                                completion(.failure(NSError(domain: "LocationManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No route found"])))
                                return
                            }
                            
                            completion(.success(route))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        isLoadingLocation = false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        isLoadingLocation = false
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            break
        }
    }
} 