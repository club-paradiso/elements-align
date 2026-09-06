import Foundation

/// The Five Elements (五行).
///
/// The case order is the generating cycle, which makes both classical cycles
/// fall out of modular arithmetic instead of lookup tables:
/// generating is +1, controlling is +2.
public enum Element: Int, CaseIterable, Hashable, Sendable {
    case wood = 0, fire, earth, metal, water

    /// 相生 — the element this one produces. Wood feeds Fire.
    public var generates: Element { Element(rawValue: (rawValue + 1) % 5) ?? .wood }

    /// The element that produces this one. Water feeds Wood.
    public var generatedBy: Element { Element(rawValue: (rawValue + 4) % 5) ?? .wood }

    /// 相剋 — the element this one restrains. Wood parts Earth.
    public var controls: Element { Element(rawValue: (rawValue + 2) % 5) ?? .wood }

    /// The element that restrains this one. Metal cuts Wood.
    public var controlledBy: Element { Element(rawValue: (rawValue + 3) % 5) ?? .wood }

    /// Localisation key. User-facing strings are resolved in the UI layer; the
    /// domain layer never holds display text.
    public var localizationKey: String { "element.\(identifier)" }

    public var identifier: String {
        ["wood", "fire", "earth", "metal", "water"][rawValue]
    }

    public var chineseName: String {
        ["木", "火", "土", "金", "水"][rawValue]
    }
}

/// Yin/yang polarity (陰陽).
public enum Polarity: Int, Hashable, Sendable {
    case yang = 0, yin

    public var identifier: String { self == .yang ? "yang" : "yin" }
    public var chineseName: String { self == .yang ? "陽" : "陰" }
}

/// A normalised distribution of the Five Elements, always summing to 1.
public struct ElementDistribution: Hashable, Sendable {
    public private(set) var values: [Element: Double]

    /// Builds a normalised distribution from raw weights.
    /// Returns a uniform distribution if every weight is zero, so that callers
    /// never have to handle a degenerate case.
    public init(weights: [Element: Double]) {
        let total = weights.values.reduce(0, +)
        guard total > 0 else {
            self.values = Dictionary(uniqueKeysWithValues:
                Element.allCases.map { ($0, 0.2) })
            return
        }
        var normalized: [Element: Double] = [:]
        for element in Element.allCases {
            normalized[element] = (weights[element] ?? 0) / total
        }
        self.values = normalized
    }

    public subscript(element: Element) -> Double { values[element] ?? 0 }

    /// Combined share of a set of elements.
    public func share(of elements: Set<Element>) -> Double {
        elements.reduce(0) { $0 + self[$1] }
    }

    /// The element with the largest share.
    ///
    /// `max(by:)` keeps the earlier element when two compare equal, so ties
    /// resolve to the lower case index and the result is deterministic.
    public var dominant: Element {
        Element.allCases.max { self[$0] < self[$1] } ?? .earth
    }

    /// Normalised Shannon entropy in [0, 1]. 1 means all five elements are
    /// equally represented; 0 means the chart is entirely one element.
    public var balance: Double {
        let entropy = values.values.reduce(0.0) { partial, p in
            p > 0 ? partial - p * log(p) : partial
        }
        return entropy / log(5.0)
    }
}
