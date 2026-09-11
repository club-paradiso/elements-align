import Foundation

/// A personal directional profile: which way is favourable for this person.
public struct BaZhaiProfile: Hashable, Sendable {
    public let gua: LifeGua

    public init(gua: LifeGua) { self.gua = gua }

    /// The relationship this person has with each compass sector.
    public func relation(for sector: CompassSector) -> BaZhaiRelation {
        let own = gua.trigram.rawValue
        // Derived, not tabulated: the sector's trigram XOR our own gives the
        // line difference, and the relationship is whichever mask matches.
        let mask = own ^ sector.trigram.rawValue
        return BaZhaiRelation.allCases.first { $0.lineMask == mask } ?? .fuWei
    }

    /// All eight sectors and their relationships.
    public var sectors: [(sector: CompassSector, relation: BaZhaiRelation)] {
        CompassSector.allCases.map { ($0, relation(for: $0)) }
    }

    /// The four auspicious sectors, best first.
    public var auspiciousSectors: [(sector: CompassSector, relation: BaZhaiRelation)] {
        sectors.filter { $0.relation.isAuspicious }
            .sorted { $0.relation.weight > $1.relation.weight }
    }

    /// The single most favourable direction (生氣).
    public var primaryDirection: CompassSector {
        auspiciousSectors.first?.sector ?? .north
    }

    /// A continuous directional value in [-1, 1] for an arbitrary heading.
    ///
    /// The eight sectors carry discrete traditional weights, but a watch face
    /// that snapped between eight values as the wearer turned would feel broken.
    /// Between sector centres the value is interpolated with a smoothstep, which
    /// is continuous, has zero derivative at each centre — so the value peaks
    /// exactly on a sector centre rather than sliding past it — and preserves
    /// the traditional ordering everywhere.
    public func directionalValue(heading: Double) -> Double {
        let normalized = Angle.normalizedDegrees(heading)
        let index = Int((normalized / 45.0).rounded(.down))
        let fraction = (normalized - Double(index) * 45.0) / 45.0

        let lower = CompassSector(rawValue: index % 8) ?? .north
        let upper = CompassSector(rawValue: (index + 1) % 8) ?? .north

        let v0 = relation(for: lower).weight
        let v1 = relation(for: upper).weight
        return v0 + (v1 - v0) * Angle.smoothstep(fraction)
    }
}
