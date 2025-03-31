import Foundation
import CoreLocation
import MapKit

// Make CLLocationCoordinate2D conform to Equatable
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        let tolerance: Double = 0.000001
        return abs(lhs.latitude - rhs.latitude) < tolerance &&
               abs(lhs.longitude - rhs.longitude) < tolerance
    }
} 