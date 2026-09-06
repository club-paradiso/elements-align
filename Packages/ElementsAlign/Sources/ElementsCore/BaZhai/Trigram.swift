import Foundation

/// The eight trigrams (八卦), encoded by their lines.
///
/// The raw value *is* the trigram: bit 0 is the bottom line, bit 1 the middle,
/// bit 2 the top, with a set bit meaning a solid (yang) line. Encoding it this
/// way is what lets the Eight Mansions relationships be derived from the
/// classical changing-line rule instead of transcribed from a table.
public enum Trigram: Int, CaseIterable, Hashable, Sendable {
    case kun = 0    // 坤 ☷  all yin
    case zhen = 1   // 震 ☳  solid bottom
    case kan = 2    // 坎 ☵  solid middle
    case dui = 3    // 兌 ☱  solid bottom and middle
    case gen = 4    // 艮 ☶  solid top
    case li = 5     // 離 ☲  solid bottom and top
    case xun = 6    // 巽 ☴  solid middle and top
    case qian = 7   // 乾 ☰  all yang

    public var bottomLineIsYang: Bool { rawValue & 0b001 != 0 }
    public var middleLineIsYang: Bool { rawValue & 0b010 != 0 }
    public var topLineIsYang: Bool { rawValue & 0b100 != 0 }

    public var name: String {
        ["Kun", "Zhen", "Kan", "Dui", "Gen", "Li", "Xun", "Qian"][rawValue]
    }

    public var chineseName: String {
        ["坤", "震", "坎", "兌", "艮", "離", "巽", "乾"][rawValue]
    }

    /// Compass bearing of this trigram in the Later Heaven arrangement (後天八卦).
    public var direction: CompassSector {
        switch self {
        case .kan:  return .north
        case .gen:  return .northeast
        case .zhen: return .east
        case .xun:  return .southeast
        case .li:   return .south
        case .kun:  return .southwest
        case .dui:  return .west
        case .qian: return .northwest
        }
    }
}

/// One of the eight 45-degree compass sectors.
public enum CompassSector: Int, CaseIterable, Hashable, Sendable {
    case north = 0, northeast, east, southeast, south, southwest, west, northwest

    /// Bearing of the sector's centre, in degrees clockwise from north.
    public var centerDegrees: Double { Double(rawValue) * 45.0 }

    public var abbreviation: String {
        ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][rawValue]
    }

    public var localizationKey: String {
        "direction.\(["north", "northeast", "east", "southeast",
                      "south", "southwest", "west", "northwest"][rawValue])"
    }

    /// The sector a heading falls in. Sector centres sit at multiples of 45
    /// degrees, so a sector spans 22.5 degrees either side of its centre.
    public static func containing(heading: Double) -> CompassSector {
        let normalized = Angle.normalizedDegrees(heading + 22.5)
        let index = Int((normalized / 45.0).rounded(.down)) % 8
        return CompassSector(rawValue: index) ?? .north
    }

    public var trigram: Trigram {
        Trigram.allCases.first { $0.direction == self } ?? .kan
    }
}

/// The eight Eight Mansions relationships (八宅).
///
/// The classical 變爻 rule generates these in a fixed order by flipping lines
/// of your own trigram: top, then middle, then bottom, then middle, then top,
/// then middle, then bottom, then middle — returning to where it started.
/// Each relationship is therefore just an XOR mask over the line encoding.
///
/// This derivation was checked against the published table for 坎 on all eight
/// directions, and against the structural requirement that the relationship
/// between two trigrams is symmetric.
public enum BaZhaiRelation: Int, CaseIterable, Hashable, Sendable {
    case shengQi = 0   // 生氣
    case tianYi        // 天醫
    case yanNian       // 延年
    case fuWei         // 伏位
    case huoHai        // 禍害
    case liuSha        // 六煞
    case wuGui         // 五鬼
    case jueMing       // 絕命

    /// XOR mask over the trigram line encoding.
    public var lineMask: Int {
        [0b100, 0b011, 0b111, 0b000, 0b001, 0b101, 0b110, 0b010][rawValue]
    }

    public var isAuspicious: Bool { rawValue < 4 }

    /// Value used by the alignment engine, in [-1, 1].
    ///
    /// The *ranking* is traditional — 生氣 is the most favourable of the four
    /// good directions, 絕命 the least favourable of the four others. These
    /// particular numbers are a product decision: they spread the eight
    /// relationships evenly so that no two directions score the same.
    public var weight: Double {
        [1.0, 0.75, 0.5, 0.25, -0.25, -0.5, -0.75, -1.0][rawValue]
    }

    public var name: String {
        ["ShengQi", "TianYi", "YanNian", "FuWei",
         "HuoHai", "LiuSha", "WuGui", "JueMing"][rawValue]
    }

    public var chineseName: String {
        ["生氣", "天醫", "延年", "伏位", "禍害", "六煞", "五鬼", "絕命"][rawValue]
    }

    public var localizationKey: String { "bazhai.relation.\(name.lowercased())" }
}
