import Foundation
import MapKit

// MapView vehicle location information model - for visualization purposes
struct MapVehicleLocationInfo: Identifiable {
    let id = UUID()
    let vehicleId: String
    let latitude: Double
    let longitude: Double
    let type: MapVehicleType
    let heading: Double
    let speed: Double
    let status: MapVehicleStatus
    
    // Convenience property to get coordinate
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MapView vehicle types - for visualization purposes
enum MapVehicleType: String, CaseIterable {
    case car = "Car"
    case truck = "Truck"
    case van = "Van"
    case bike = "Bike"
    
    // Return the appropriate system name for the vehicle type icon
    var iconName: String {
        switch self {
        case .car:
            return "car.fill"
        case .truck:
            return "truck.box.fill"
        case .van:
            return "van.fill"
        case .bike:
            return "bicycle"
        }
    }
    
    // Return the appropriate color for the vehicle type
    var color: UIColor {
        switch self {
        case .car:
            return UIColor.systemBlue
        case .truck:
            return UIColor.systemOrange
        case .van:
            return UIColor.systemGreen
        case .bike:
            return UIColor.systemRed
        }
    }
    
    // Helper method to convert from VehicleType in the main model
    static func fromVehicleType(_ type: VehicleType) -> MapVehicleType {
        switch type {
        case .lmvTr, .psv:
            return .car
        case .mgv, .hgmv:
            return .truck
        case .hmv, .htv, .hpmv:
            return .van
        case .trans:
            return .bike
        }
    }
}

// MapView vehicle status - for visualization purposes
enum MapVehicleStatus: String, CaseIterable {
    case moving = "Moving"
    case idle = "Idle"
    case stopped = "Stopped"
    case maintenance = "Maintenance"
    
    // Return the appropriate color for the status
    var color: UIColor {
        switch self {
        case .moving:
            return UIColor.systemGreen
        case .idle:
            return UIColor.systemYellow
        case .stopped:
            return UIColor.systemRed
        case .maintenance:
            return UIColor.systemGray
        }
    }
}

// MapView vehicle annotation for the map
class MapVehicleAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let vehicleType: MapVehicleType
    var heading: Double
    let vehicleId: String
    var tripId: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, vehicleType: MapVehicleType, heading: Double, vehicleId: String = "", tripId: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.vehicleType = vehicleType
        self.heading = heading
        self.vehicleId = vehicleId
        self.tripId = tripId
        super.init()
    }
} 