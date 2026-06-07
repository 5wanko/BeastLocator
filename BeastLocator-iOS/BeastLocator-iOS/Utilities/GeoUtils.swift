import Foundation
import CoreLocation

class GeoUtils {
    static let shared = GeoUtils()
    private let waterKeywords = ["sea", "ocean", "bay", "gulf", "channel", "海", "洋", "湾", "灘"]
    
    func randomDestination(center: CLLocationCoordinate2D, radiusKm: Double) -> CLLocationCoordinate2D {
        let distanceM = sqrt(Double.random(in: 0...1)) * radiusKm * 1000.0
        let bearingRad = Double.random(in: 0...360) * .pi / 180.0
        let earthRadius = 6371000.0
        
        let lat1 = center.latitude * .pi / 180.0
        let lon1 = center.longitude * .pi / 180.0
        let angularDistance = distanceM / earthRadius
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180.0 / .pi, longitude: lon2 * 180.0 / .pi)
    }
    
    func randomDestinationWithLandFilter(center: CLLocationCoordinate2D, radiusKm: Double, landOnlyEnabled: Bool) async -> CLLocationCoordinate2D {
        if !landOnlyEnabled {
            return randomDestination(center: center, radiusKm: radiusKm)
        }
        var fallback = randomDestination(center: center, radiusKm: radiusKm)
        for _ in 0..<12 {
            let candidate = randomDestination(center: center, radiusKm: radiusKm)
            fallback = candidate
            if await isLikelyLand(coordinate: candidate) {
                return candidate
            }
        }
        return fallback
    }
    
    func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let l1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let l2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return l1.distance(from: l2)
    }
    
    func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180.0 / .pi
        if bearing < 0 {
            bearing += 360.0
        }
        return bearing
    }
    
    func formatDistance(_ distanceMeters: Double) -> String {
        if distanceMeters >= 1000.0 {
            return String(format: "%.2f km", distanceMeters / 1000.0)
        } else {
            return "\(Int(distanceMeters)) m"
        }
    }
    
    func cardinalFromBearing(_ bearing: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let idx = Int(((bearing + 22.5).truncatingRemainder(dividingBy: 360.0)) / 45.0)
        return dirs[idx]
    }
    
    func isLikelyLand(coordinate: CLLocationCoordinate2D) async -> Bool {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return false }
            
            let country = placemark.country ?? ""
            let administrativeArea = placemark.administrativeArea ?? ""
            let locality = placemark.locality ?? ""
            let ocean = placemark.ocean ?? ""
            let inlandWater = placemark.inlandWater ?? ""
            
            if !ocean.isEmpty || !inlandWater.isEmpty {
                return false
            }
            
            let addressText = [
                placemark.name,
                placemark.locality,
                placemark.subLocality,
                placemark.administrativeArea,
                placemark.country
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            
            if waterKeywords.contains(where: { addressText.contains($0) }) {
                return false
            }
            
            return !country.isEmpty || !administrativeArea.isEmpty || !locality.isEmpty
        } catch {
            return true
        }
    }
}
