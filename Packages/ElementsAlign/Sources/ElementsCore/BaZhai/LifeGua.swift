import Foundation

/// A life gua (本命卦), the personal trigram Eight Mansions is built on.
public struct LifeGua: Hashable, Sendable {
    /// 1...9 excluding 5, which is reassigned on construction.
    public let number: Int
    public let polarity: Polarity

    public var trigram: Trigram {
        switch number {
        case 1: return .kan
        case 2: return .kun
        case 3: return .zhen
        case 4: return .xun
        case 6: return .qian
        case 7: return .dui
        case 8: return .gen
        default: return .li      // 9
        }
    }

    /// East group (東四命) covers gua 1, 3, 4 and 9; the rest are West group.
    public var isEastGroup: Bool { [1, 3, 4, 9].contains(number) }

    public var groupLocalizationKey: String {
        isEastGroup ? "bazhai.group.east" : "bazhai.group.west"
    }

    /// Derives the life gua from a BaZi year and a polarity.
    ///
    /// The classical rules are usually stated per century — "for 1900s males,
    /// ten minus the reduced digit sum of the last two digits; for 2000s males,
    /// nine minus it" — with separate rules for females. Both centuries reduce
    /// to a single congruence, because 1900 and 2000 differ by exactly the
    /// offset the two rules differ by:
    ///
    ///     yang:  (11 - year) mod 9        yin:  (year + 4) mod 9
    ///
    /// with 0 mapped to 9. The central number 5 has no trigram, and is
    /// reassigned to 2 (坤) for yang and 8 (艮) for yin, as tradition directs.
    ///
    /// The derivation was verified against the per-century statements for every
    /// year from 1900 to 2060, for both polarities, with no disagreement.
    ///
    /// - Note: `baziYear` must be the 立春-based year, not the calendar year. A
    ///   January birth belongs to the previous BaZi year and gets a different
    ///   gua — using the calendar year here is a classic source of wrong charts.
    public init(baziYear: Int, polarity: Polarity) {
        let raw: Int
        switch polarity {
        case .yang: raw = ((11 - baziYear) % 9 + 9) % 9
        case .yin:  raw = ((baziYear + 4) % 9 + 9) % 9
        }
        var number = raw == 0 ? 9 : raw
        if number == 5 { number = polarity == .yang ? 2 : 8 }
        self.number = number
        self.polarity = polarity
    }
}
