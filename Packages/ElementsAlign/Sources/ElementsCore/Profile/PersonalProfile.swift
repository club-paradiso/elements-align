import Foundation

/// A point on the Earth. Latitude is carried for future spatial work; the V1
/// engine only needs longitude, for solar time.
public struct GeoLocation: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// What the user told us about their birth.
///
/// This is the most sensitive data the product holds. It never leaves the
/// device: everything downstream of it is local arithmetic.
public struct BirthMoment: Hashable, Sendable {
    /// The instant in Universal Time. If the birth time is unknown this still
    /// needs a value; use local noon, and set `precision` to `.dayOnly`.
    public let instant: Date
    /// Where the birth happened. Solar time is a property of the place of the
    /// event, not of where the user lives now.
    public let location: GeoLocation
    public let precision: ChartPrecision

    public init(instant: Date, location: GeoLocation, precision: ChartPrecision = .exact) {
        self.instant = instant
        self.location = location
        self.precision = precision
    }
}

/// The user's stored configuration.
public struct PersonalProfile: Hashable, Sendable {
    public let birth: BirthMoment

    /// Polarity as Eight Mansions requires it.
    ///
    /// The classical rule is stated in terms of 男 and 女. It is an input the
    /// traditional system demands, not a claim the product makes about the
    /// user, so it is modelled as the yang/yin polarity the rule actually turns
    /// on and is presented as a choice with that explanation attached.
    public let polarity: Polarity

    public let options: BaZiOptions

    public init(birth: BirthMoment, polarity: Polarity, options: BaZiOptions = .default) {
        self.birth = birth
        self.polarity = polarity
        self.options = options
    }
}

/// Everything derived from a profile that does not change over time.
///
/// Building this is the expensive part of the engine — it runs the solar-term
/// solver — so it is computed once when the profile is saved and then reused.
/// Nothing on a per-frame or per-heading path should ever construct one.
public struct PersonalChart: Hashable, Sendable {
    public let profile: PersonalProfile
    public let pillars: FourPillars
    public let baZhai: BaZhaiProfile
    public let natalDistribution: ElementDistribution
    public let favourableElements: Set<Element>
    public let dayMasterStrength: Double
    public let natalBalance: Double

    public var dayMaster: HeavenlyStem { pillars.dayMaster }
    public var dayMasterElement: Element { pillars.dayMasterElement }
    public var isDayMasterStrong: Bool { pillars.isDayMasterStrong }

    public init(profile: PersonalProfile, calculator: BaZiCalculator) {
        let instant = JulianDayConversion.julianDay(from: profile.birth.instant)
        let pillars = calculator.pillars(
            at: instant,
            longitude: profile.birth.location.longitude,
            precision: profile.birth.precision,
            options: profile.options)

        self.profile = profile
        self.pillars = pillars
        self.natalDistribution = pillars.elementDistribution(weights: .natal)
        self.favourableElements = pillars.favourableElements()
        self.dayMasterStrength = pillars.dayMasterStrength()
        self.natalBalance = pillars.natalBalance()
        self.baZhai = BaZhaiProfile(
            gua: LifeGua(baziYear: calculator.solarTerms.baziYear(at: instant),
                         polarity: profile.polarity))
    }
}
