import Foundation
import ElementsCore

/// An sRGB colour as plain data.
///
/// Deliberately not a SwiftUI `Color`: the palette is data, so it can be
/// tested, diffed and reasoned about on any platform, including the Linux CI
/// that has no SwiftUI at all. The SwiftUI bridge is a thin extension.
public struct RGB: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Builds a colour from a 24-bit hex literal, e.g. `RGB(0x6FA292)`.
    public init(_ hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
    }

    /// Relative luminance per WCAG 2.x, used by the contrast tests.
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio against another colour, from 1 to 21.
    public func contrastRatio(against other: RGB) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Linear blend towards another colour.
    public func mixed(with other: RGB, amount: Double) -> RGB {
        let t = Angle.clamp01(amount)
        return RGB(red: red + (other.red - red) * t,
                   green: green + (other.green - green) * t,
                   blue: blue + (other.blue - blue) * t)
    }
}

/// A colour with a variant for each appearance.
public struct ColorToken: Hashable, Sendable {
    public let dark: RGB
    public let light: RGB

    public init(dark: RGB, light: RGB) {
        self.dark = dark
        self.light = light
    }

    public init(dark: UInt32, light: UInt32) {
        self.dark = RGB(dark)
        self.light = RGB(light)
    }
}

/// The product's palette.
///
/// The elements are not drawn as their literal substances. Wood is a muted
/// celadon rather than a neon green, Fire a warm ember rather than a pure red,
/// Water an ink blue rather than a cyan. The point is a single coherent family
/// that reads as one designed system on a black OLED display, not five
/// unrelated primaries.
///
/// The alignment ramp is deliberately restrained at the bottom and warm at the
/// top: low states are desaturated greys that recede, and only `aligned` is
/// allowed to be bright. Nothing in the ramp is red, because nothing here is a
/// warning.
public enum Palette {

    // MARK: - Elements

    public static let wood = ColorToken(dark: 0x6FA292, light: 0x3F6B5C)
    public static let fire = ColorToken(dark: 0xD08163, light: 0xA34E33)
    public static let earth = ColorToken(dark: 0xC6A374, light: 0x8A6A3E)
    public static let metal = ColorToken(dark: 0xAFBAC4, light: 0x66727E)
    public static let water = ColorToken(dark: 0x6E8FC0, light: 0x3A5680)

    public static func token(for element: Element) -> ColorToken {
        switch element {
        case .wood:  return wood
        case .fire:  return fire
        case .earth: return earth
        case .metal: return metal
        case .water: return water
        }
    }

    // MARK: - Alignment states

    public static let alignmentLow = ColorToken(dark: 0x4C525A, light: 0x8A9099)
    public static let alignmentUnfavourable = ColorToken(dark: 0x5E656E, light: 0x767D87)
    public static let alignmentNeutral = ColorToken(dark: 0x828A94, light: 0x5F6771)
    public static let alignmentFavourable = ColorToken(dark: 0x94AEB3, light: 0x466A72)
    public static let alignmentStrong = ColorToken(dark: 0xC9A96A, light: 0x7E6329)
    public static let alignmentAligned = ColorToken(dark: 0xF0E6CE, light: 0x5E4C22)

    public static func token(for level: AlignmentLevel) -> ColorToken {
        switch level {
        case .low:          return alignmentLow
        case .unfavourable: return alignmentUnfavourable
        case .neutral:      return alignmentNeutral
        case .favourable:   return alignmentFavourable
        case .strong:       return alignmentStrong
        case .aligned:      return alignmentAligned
        }
    }

    // MARK: - Surfaces

    /// Near-black rather than pure black: on the watch it keeps the composition
    /// from looking like a hole cut in the display, while still letting the
    /// OLED switch most pixels off.
    public static let background = ColorToken(dark: 0x08090B, light: 0xF7F6F3)
    public static let primaryText = ColorToken(dark: 0xEDEEF0, light: 0x16181B)
    public static let secondaryText = ColorToken(dark: 0x9AA0A8, light: 0x5A6068)
    public static let hairline = ColorToken(dark: 0x2A2E34, light: 0xD8D6D0)
}

/// Motion constants.
///
/// The watch composition is driven by continuously varying values, so most
/// movement is the data moving rather than an animation being played. These
/// govern the few places something genuinely transitions.
public enum Motion {
    /// Settling time when the level changes.
    public static let levelTransition: TimeInterval = 0.6
    /// Settling time for the convergence at full alignment.
    public static let convergence: TimeInterval = 0.9
    /// How quickly node positions chase the heading. Short, because this is
    /// the direct-manipulation part of the interface and lag reads as broken.
    public static let headingFollow: TimeInterval = 0.12

    /// Every duration collapses to zero when the system asks for reduced
    /// motion. The composition still changes; it simply stops travelling.
    public static func duration(_ base: TimeInterval, reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : base
    }
}

/// Layout constants for the watch composition.
public enum Layout {
    /// Radius of the orbit ring as a fraction of the smaller screen dimension.
    public static let orbitRadiusFraction: Double = 0.34
    /// How far nodes scatter outward at the lowest state, as a fraction of the
    /// orbit radius.
    public static let maximumScatter: Double = 0.45
    /// Node diameter as a fraction of the smaller screen dimension.
    public static let nodeDiameterFraction: Double = 0.055
}
