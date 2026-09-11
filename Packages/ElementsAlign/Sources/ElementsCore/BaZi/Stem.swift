import Foundation

/// The ten Heavenly Stems (天干).
///
/// Element is the case index halved and polarity is its parity, which is the
/// actual structure of the cycle rather than a coincidence worth tabulating.
public enum HeavenlyStem: Int, CaseIterable, Hashable, Sendable {
    case jia = 0, yi, bing, ding, wu, ji, geng, xin, ren, gui

    public var element: Element { Element(rawValue: rawValue / 2) ?? .wood }
    public var polarity: Polarity { rawValue % 2 == 0 ? .yang : .yin }

    public var name: String {
        ["Jia", "Yi", "Bing", "Ding", "Wu",
         "Ji", "Geng", "Xin", "Ren", "Gui"][rawValue]
    }

    public var chineseName: String {
        ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"][rawValue]
    }
}

/// The twelve Earthly Branches (地支).
public enum EarthlyBranch: Int, CaseIterable, Hashable, Sendable {
    case zi = 0, chou, yin, mao, chen, si, wu, wei, shen, you, xu, hai

    public var name: String {
        ["Zi", "Chou", "Yin", "Mao", "Chen", "Si",
         "Wu", "Wei", "Shen", "You", "Xu", "Hai"][rawValue]
    }

    public var chineseName: String {
        ["子", "丑", "寅", "卯", "辰", "巳",
         "午", "未", "申", "酉", "戌", "亥"][rawValue]
    }

    /// The branch's own element.
    public var element: Element {
        [.water, .earth, .wood, .wood, .earth, .fire,
         .fire, .earth, .metal, .metal, .earth, .water][rawValue]
    }

    /// Hidden stems (藏干), principal qi first.
    ///
    /// A branch is not a single element: it holds one to three stems, and a
    /// chart that ignores them loses most of its texture. The ordering is the
    /// classical 本氣 / 中氣 / 餘氣 sequence.
    public var hiddenStems: [HeavenlyStem] {
        switch self {
        case .zi:   return [.gui]
        case .chou: return [.ji, .gui, .xin]
        case .yin:  return [.jia, .bing, .wu]
        case .mao:  return [.yi]
        case .chen: return [.wu, .yi, .gui]
        case .si:   return [.bing, .geng, .wu]
        case .wu:   return [.ding, .ji]
        case .wei:  return [.ji, .ding, .yi]
        case .shen: return [.geng, .ren, .wu]
        case .you:  return [.xin]
        case .xu:   return [.wu, .xin, .ding]
        case .hai:  return [.ren, .jia]
        }
    }

    /// Weight given to each hidden stem.
    ///
    /// The ordering is traditional; these particular numbers are a product
    /// decision, documented in Documentation/ALIGNMENT_ENGINE.md. They always
    /// sum to 1 so that every branch contributes equally to a distribution
    /// regardless of how many stems it hides.
    public var hiddenStemWeights: [Double] {
        switch hiddenStems.count {
        case 1:  return [1.0]
        case 2:  return [0.7, 0.3]
        default: return [0.6, 0.3, 0.1]
        }
    }

    /// Weighted hidden stems, paired.
    public var weightedHiddenStems: [(stem: HeavenlyStem, weight: Double)] {
        Array(zip(hiddenStems, hiddenStemWeights)).map { (stem: $0.0, weight: $0.1) }
    }
}

/// One pillar: a stem over a branch.
public struct Pillar: Hashable, Sendable {
    public let stem: HeavenlyStem
    public let branch: EarthlyBranch

    public init(stem: HeavenlyStem, branch: EarthlyBranch) {
        self.stem = stem
        self.branch = branch
    }

    /// Position in the sexagenary cycle, 0...59.
    ///
    /// Only 60 of the 120 stem/branch pairings occur, because stems and
    /// branches advance together and their parities stay locked.
    public var sexagenaryIndex: Int? {
        for index in 0..<60 where index % 10 == stem.rawValue && index % 12 == branch.rawValue {
            return index
        }
        return nil
    }

    public var name: String { stem.name + branch.name }
    public var chineseName: String { stem.chineseName + branch.chineseName }
}
