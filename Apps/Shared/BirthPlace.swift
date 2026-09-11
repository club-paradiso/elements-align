import Foundation
import ElementsCore

/// A birth place the user can choose without a network round trip.
///
/// V1 ships a small offline table rather than calling a geocoding service.
/// Sending someone's birth city to a third party in order to look up a
/// longitude is a poor trade for a value that only needs to be accurate to
/// about a degree, and it would make the claim that birth data never leaves
/// the device untrue. The manual longitude entry covers everywhere the table
/// does not; proper offline geocoding is on the roadmap.
public struct BirthPlace: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let region: String
    public let location: GeoLocation
    /// IANA identifier. Carried so a birth time can be resolved against the
    /// offset that was in force on the date, not the one in force today --
    /// Korea, for one, ran on UTC+8:30 from 1954 to 1961.
    public let timeZoneIdentifier: String

    public init(id: String, name: String, region: String,
                latitude: Double, longitude: Double, timeZone: String) {
        self.id = id
        self.name = name
        self.region = region
        self.location = GeoLocation(latitude: latitude, longitude: longitude)
        self.timeZoneIdentifier = timeZone
    }

    public var displayName: String { "\(name), \(region)" }

    /// A longitude's offset from its own time zone's central meridian, in
    /// minutes of solar time. Shown during onboarding because it is the reason
    /// the app asks where someone was born at all.
    public func solarOffsetMinutes(fromStandardMeridian meridian: Double) -> Double {
        (location.longitude - meridian) * 4.0
    }
}

public extension BirthPlace {
    /// Common birth places. Not exhaustive, and not meant to be.
    static let table: [BirthPlace] = [
        BirthPlace(id: "seoul", name: "Seoul", region: "South Korea", latitude: 37.567, longitude: 126.978, timeZone: "Asia/Seoul"),
        BirthPlace(id: "busan", name: "Busan", region: "South Korea", latitude: 35.180, longitude: 129.075, timeZone: "Asia/Seoul"),
        BirthPlace(id: "incheon", name: "Incheon", region: "South Korea", latitude: 37.456, longitude: 126.705, timeZone: "Asia/Seoul"),
        BirthPlace(id: "daegu", name: "Daegu", region: "South Korea", latitude: 35.872, longitude: 128.601, timeZone: "Asia/Seoul"),
        BirthPlace(id: "gwangju", name: "Gwangju", region: "South Korea", latitude: 35.160, longitude: 126.851, timeZone: "Asia/Seoul"),
        BirthPlace(id: "daejeon", name: "Daejeon", region: "South Korea", latitude: 36.351, longitude: 127.385, timeZone: "Asia/Seoul"),
        BirthPlace(id: "jeju", name: "Jeju", region: "South Korea", latitude: 33.499, longitude: 126.531, timeZone: "Asia/Seoul"),
        BirthPlace(id: "tokyo", name: "Tokyo", region: "Japan", latitude: 35.690, longitude: 139.692, timeZone: "Asia/Tokyo"),
        BirthPlace(id: "osaka", name: "Osaka", region: "Japan", latitude: 34.694, longitude: 135.502, timeZone: "Asia/Tokyo"),
        BirthPlace(id: "beijing", name: "Beijing", region: "China", latitude: 39.904, longitude: 116.407, timeZone: "Asia/Shanghai"),
        BirthPlace(id: "shanghai", name: "Shanghai", region: "China", latitude: 31.230, longitude: 121.474, timeZone: "Asia/Shanghai"),
        BirthPlace(id: "hongkong", name: "Hong Kong", region: "China", latitude: 22.319, longitude: 114.169, timeZone: "Asia/Hong_Kong"),
        BirthPlace(id: "taipei", name: "Taipei", region: "Taiwan", latitude: 25.033, longitude: 121.565, timeZone: "Asia/Taipei"),
        BirthPlace(id: "singapore", name: "Singapore", region: "Singapore", latitude: 1.352, longitude: 103.820, timeZone: "Asia/Singapore"),
        BirthPlace(id: "bangkok", name: "Bangkok", region: "Thailand", latitude: 13.756, longitude: 100.502, timeZone: "Asia/Bangkok"),
        BirthPlace(id: "manila", name: "Manila", region: "Philippines", latitude: 14.599, longitude: 120.984, timeZone: "Asia/Manila"),
        BirthPlace(id: "jakarta", name: "Jakarta", region: "Indonesia", latitude: -6.209, longitude: 106.845, timeZone: "Asia/Jakarta"),
        BirthPlace(id: "hanoi", name: "Hanoi", region: "Vietnam", latitude: 21.028, longitude: 105.834, timeZone: "Asia/Ho_Chi_Minh"),
        BirthPlace(id: "delhi", name: "Delhi", region: "India", latitude: 28.614, longitude: 77.209, timeZone: "Asia/Kolkata"),
        BirthPlace(id: "mumbai", name: "Mumbai", region: "India", latitude: 19.076, longitude: 72.878, timeZone: "Asia/Kolkata"),
        BirthPlace(id: "dubai", name: "Dubai", region: "UAE", latitude: 25.205, longitude: 55.271, timeZone: "Asia/Dubai"),
        BirthPlace(id: "sydney", name: "Sydney", region: "Australia", latitude: -33.869, longitude: 151.209, timeZone: "Australia/Sydney"),
        BirthPlace(id: "melbourne", name: "Melbourne", region: "Australia", latitude: -37.814, longitude: 144.963, timeZone: "Australia/Melbourne"),
        BirthPlace(id: "auckland", name: "Auckland", region: "New Zealand", latitude: -36.848, longitude: 174.763, timeZone: "Pacific/Auckland"),
        BirthPlace(id: "london", name: "London", region: "United Kingdom", latitude: 51.507, longitude: -0.128, timeZone: "Europe/London"),
        BirthPlace(id: "paris", name: "Paris", region: "France", latitude: 48.857, longitude: 2.352, timeZone: "Europe/Paris"),
        BirthPlace(id: "berlin", name: "Berlin", region: "Germany", latitude: 52.520, longitude: 13.405, timeZone: "Europe/Berlin"),
        BirthPlace(id: "madrid", name: "Madrid", region: "Spain", latitude: 40.417, longitude: -3.704, timeZone: "Europe/Madrid"),
        BirthPlace(id: "rome", name: "Rome", region: "Italy", latitude: 41.903, longitude: 12.496, timeZone: "Europe/Rome"),
        BirthPlace(id: "moscow", name: "Moscow", region: "Russia", latitude: 55.756, longitude: 37.617, timeZone: "Europe/Moscow"),
        BirthPlace(id: "istanbul", name: "Istanbul", region: "Turkey", latitude: 41.008, longitude: 28.978, timeZone: "Europe/Istanbul"),
        BirthPlace(id: "cairo", name: "Cairo", region: "Egypt", latitude: 30.044, longitude: 31.236, timeZone: "Africa/Cairo"),
        BirthPlace(id: "lagos", name: "Lagos", region: "Nigeria", latitude: 6.524, longitude: 3.379, timeZone: "Africa/Lagos"),
        BirthPlace(id: "johannesburg", name: "Johannesburg", region: "South Africa", latitude: -26.204, longitude: 28.047, timeZone: "Africa/Johannesburg"),
        BirthPlace(id: "newyork", name: "New York", region: "United States", latitude: 40.713, longitude: -74.006, timeZone: "America/New_York"),
        BirthPlace(id: "losangeles", name: "Los Angeles", region: "United States", latitude: 34.052, longitude: -118.244, timeZone: "America/Los_Angeles"),
        BirthPlace(id: "chicago", name: "Chicago", region: "United States", latitude: 41.878, longitude: -87.630, timeZone: "America/Chicago"),
        BirthPlace(id: "houston", name: "Houston", region: "United States", latitude: 29.760, longitude: -95.370, timeZone: "America/Chicago"),
        BirthPlace(id: "sanfrancisco", name: "San Francisco", region: "United States", latitude: 37.775, longitude: -122.419, timeZone: "America/Los_Angeles"),
        BirthPlace(id: "seattle", name: "Seattle", region: "United States", latitude: 47.606, longitude: -122.332, timeZone: "America/Los_Angeles"),
        BirthPlace(id: "toronto", name: "Toronto", region: "Canada", latitude: 43.653, longitude: -79.383, timeZone: "America/Toronto"),
        BirthPlace(id: "vancouver", name: "Vancouver", region: "Canada", latitude: 49.283, longitude: -123.121, timeZone: "America/Vancouver"),
        BirthPlace(id: "mexicocity", name: "Mexico City", region: "Mexico", latitude: 19.433, longitude: -99.133, timeZone: "America/Mexico_City"),
        BirthPlace(id: "saopaulo", name: "Sao Paulo", region: "Brazil", latitude: -23.551, longitude: -46.633, timeZone: "America/Sao_Paulo"),
        BirthPlace(id: "buenosaires", name: "Buenos Aires", region: "Argentina", latitude: -34.604, longitude: -58.382, timeZone: "America/Argentina/Buenos_Aires"),
        BirthPlace(id: "lima", name: "Lima", region: "Peru", latitude: -12.046, longitude: -77.043, timeZone: "America/Lima"),
    ]

    static func search(_ query: String) -> [BirthPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return table }
        return table.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.region.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
