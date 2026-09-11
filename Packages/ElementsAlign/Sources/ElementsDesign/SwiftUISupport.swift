import Foundation
import ElementsCore

#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1.0)
    }
}

public extension ColorToken {
    /// Resolves against a colour scheme.
    ///
    /// Explicit rather than relying on a dynamic asset catalogue colour so that
    /// the palette stays a single source of truth in code, testable without a
    /// bundle. The watch composition is dark in both schemes by design, but the
    /// iPhone app honours the system setting.
    func resolved(for scheme: ColorScheme) -> Color {
        Color(scheme == .dark ? dark : light)
    }

    var darkColor: Color { Color(dark) }
    var lightColor: Color { Color(light) }
}

public extension Animation {
    /// An animation that collapses to nothing under Reduce Motion.
    static func elements(_ duration: TimeInterval, reduceMotion: Bool) -> Animation? {
        let resolved = Motion.duration(duration, reduceMotion: reduceMotion)
        guard resolved > 0 else { return nil }
        return .easeInOut(duration: resolved)
    }
}
#endif
