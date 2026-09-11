import XCTest
@testable import ElementsDesign
import ElementsCore

final class PaletteTests: XCTestCase {

    func testHexInitialiser() {
        let white = RGB(0xFFFFFF)
        XCTAssertEqual(white.red, 1.0, accuracy: 1e-9)
        XCTAssertEqual(white.green, 1.0, accuracy: 1e-9)
        XCTAssertEqual(white.blue, 1.0, accuracy: 1e-9)

        let black = RGB(0x000000)
        XCTAssertEqual(black.relativeLuminance, 0.0, accuracy: 1e-9)

        let red = RGB(0xFF0000)
        XCTAssertEqual(red.red, 1.0, accuracy: 1e-9)
        XCTAssertEqual(red.green, 0.0, accuracy: 1e-9)
    }

    func testContrastRatioBounds() {
        XCTAssertEqual(RGB(0xFFFFFF).contrastRatio(against: RGB(0x000000)), 21.0, accuracy: 0.01)
        XCTAssertEqual(RGB(0x808080).contrastRatio(against: RGB(0x808080)), 1.0, accuracy: 1e-9)
    }

    func testElementColoursMeetContrastOnTheWatchBackground() {
        // The watch composition is drawn on the dark surface. Element nodes are
        // graphical rather than body text, so the bar is the 3:1 WCAG
        // requirement for non-text contrast.
        let background = Palette.background.dark
        for element in Element.allCases {
            let colour = Palette.token(for: element).dark
            XCTAssertGreaterThan(colour.contrastRatio(against: background), 3.0,
                                 "\(element.identifier) is not legible on the watch face")
        }
    }

    func testAlignmentColoursMeetContrastOnTheWatchBackground() {
        let background = Palette.background.dark
        for level in AlignmentLevel.allCases {
            let colour = Palette.token(for: level).dark
            XCTAssertGreaterThan(colour.contrastRatio(against: background), 3.0,
                                 "\(level.identifier) is not legible on the watch face")
        }
    }

    func testTextMeetsFullTextContrastInBothSchemes() {
        XCTAssertGreaterThan(
            Palette.primaryText.dark.contrastRatio(against: Palette.background.dark), 4.5)
        XCTAssertGreaterThan(
            Palette.primaryText.light.contrastRatio(against: Palette.background.light), 4.5)
        XCTAssertGreaterThan(
            Palette.secondaryText.dark.contrastRatio(against: Palette.background.dark), 4.5)
        XCTAssertGreaterThan(
            Palette.secondaryText.light.contrastRatio(against: Palette.background.light), 4.5)
    }

    func testAlignmentRampBrightensWithLevel() {
        // The ramp should recede at the bottom and lift at the top, so that
        // higher states read as more present without relying on hue alone.
        let luminances = AlignmentLevel.allCases.map {
            Palette.token(for: $0).dark.relativeLuminance
        }
        for (lower, higher) in zip(luminances, luminances.dropFirst()) {
            XCTAssertLessThan(lower, higher,
                              "the dark alignment ramp must increase monotonically")
        }
    }

    func testEveryElementHasAPerceptuallyDistinctColour() {
        // Measured as Lab distance, not contrast ratio. Wood and Fire sit at
        // almost identical luminance, so their contrast ratio is about 1.04
        // even though they are obviously different colours; contrast ratio is
        // the wrong instrument for this question.
        let colours = Element.allCases.map { Palette.token(for: $0).dark }
        for (index, first) in colours.enumerated() {
            for second in colours.dropFirst(index + 1) {
                XCTAssertGreaterThan(first.perceptualDistance(to: second), 15.0,
                                     "two element colours are too close together")
            }
        }
    }

    func testAlignmentRampDarkensMonotonicallyInLightMode() {
        let luminances = AlignmentLevel.allCases.map {
            Palette.token(for: $0).light.relativeLuminance
        }
        for (lighter, darker) in zip(luminances, luminances.dropFirst()) {
            XCTAssertGreaterThan(lighter, darker,
                                 "the light alignment ramp must darken monotonically")
        }
    }

    func testAlignmentColoursMeetContrastInLightMode() {
        let background = Palette.background.light
        for level in AlignmentLevel.allCases {
            XCTAssertGreaterThan(
                Palette.token(for: level).light.contrastRatio(against: background), 3.0,
                "\(level.identifier) is not legible in light mode")
        }
    }

    func testPerceptualDistanceBasics() {
        XCTAssertEqual(RGB(0x336699).perceptualDistance(to: RGB(0x336699)), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(RGB(0x000000).perceptualDistance(to: RGB(0xFFFFFF)), 99.0)
    }

    func testMixing() {
        let mixed = RGB(0x000000).mixed(with: RGB(0xFFFFFF), amount: 0.5)
        XCTAssertEqual(mixed.red, 0.5, accuracy: 1e-9)
        // Out-of-range amounts clamp rather than overshoot.
        XCTAssertEqual(RGB(0x000000).mixed(with: RGB(0xFFFFFF), amount: 5).red, 1.0, accuracy: 1e-9)
        XCTAssertEqual(RGB(0x000000).mixed(with: RGB(0xFFFFFF), amount: -5).red, 0.0, accuracy: 1e-9)
    }

    func testReducedMotionCollapsesEveryDuration() {
        XCTAssertEqual(Motion.duration(Motion.levelTransition, reduceMotion: true), 0)
        XCTAssertEqual(Motion.duration(Motion.convergence, reduceMotion: true), 0)
        XCTAssertGreaterThan(Motion.duration(Motion.levelTransition, reduceMotion: false), 0)
    }
}

final class AlignmentPresentationTests: XCTestCase {

    private func state(score: Double) -> AlignmentState {
        AlignmentState(score: score,
                       level: AlignmentLevel.forScore(score),
                       spatialScore: 0.5, temporalScore: 0.5, personalScore: 0.5,
                       dominantElement: .water,
                       favourableDirection: .southeast,
                       headingRelation: .shengQi,
                       degreesToFavourable: 0,
                       isHeadingAvailable: true)
    }

    func testCompositionDispersesAtLowScoresAndConvergesAtHighOnes() {
        // The central visual behaviour of the product, asserted rather than
        // eyeballed in a simulator.
        let low = AlignmentPresentation(state: state(score: 20))
        let high = AlignmentPresentation(state: state(score: 95))

        XCTAssertLessThan(low.convergence, high.convergence)
        XCTAssertGreaterThan(low.scatter, high.scatter)
        XCTAssertLessThan(low.linkOpacity, high.linkOpacity)
    }

    func testConvergenceIsMonotonicInScore() {
        var previous = -1.0
        for score in stride(from: 0.0, through: 100.0, by: 1.0) {
            let convergence = AlignmentPresentation(state: state(score: score)).convergence
            XCTAssertGreaterThanOrEqual(convergence, previous)
            XCTAssertGreaterThanOrEqual(convergence, 0)
            XCTAssertLessThanOrEqual(convergence, 1)
            previous = convergence
        }
    }

    func testBrandConvergenceIsReservedForFullAlignment() {
        for score in stride(from: 0.0, to: AlignmentLevel.aligned.lowerBound, by: 1.0) {
            XCTAssertFalse(AlignmentPresentation(state: state(score: score)).showsBrandConvergence,
                           "the brand moment must not fire below aligned")
        }
        XCTAssertTrue(
            AlignmentPresentation(state: state(score: 90)).showsBrandConvergence)
    }

    func testScatterAndOpacityStayInRange() {
        for score in stride(from: -20.0, through: 120.0, by: 0.5) {
            let presentation = AlignmentPresentation(state: state(score: score))
            XCTAssertGreaterThanOrEqual(presentation.scatter, 0)
            XCTAssertLessThanOrEqual(presentation.scatter, Layout.maximumScatter)
            XCTAssertGreaterThanOrEqual(presentation.linkOpacity, 0)
            XCTAssertLessThanOrEqual(presentation.linkOpacity, 1)
        }
    }

    func testNodeAnglesAreAnchoredToTheCompass() {
        // Turning the wrist must move the ring past the wearer: the composition
        // is fixed to the world, which is what makes it read as spatial.
        let a = AlignmentPresentation.nodeAngle(index: 0, count: 5, heading: 0, convergence: 0)
        let b = AlignmentPresentation.nodeAngle(index: 0, count: 5, heading: 90, convergence: 0)
        XCTAssertEqual(Angle.signedDifference(from: a, to: b), -90, accuracy: 1e-9)
    }

    func testNodeAnglesAreNormalisedAndDistinctWhenDispersed() {
        var angles: [Double] = []
        for index in 0..<5 {
            let angle = AlignmentPresentation.nodeAngle(
                index: index, count: 5, heading: 137, convergence: 0)
            XCTAssertGreaterThanOrEqual(angle, 0)
            XCTAssertLessThan(angle, 360)
            angles.append(angle)
        }
        XCTAssertEqual(Set(angles.map { Int($0.rounded()) }).count, 5,
                       "dispersed nodes should occupy distinct positions")
    }

    func testNodesDrawTogetherAsConvergenceRises() {
        // Measured as the separation between adjacent nodes. Measuring first
        // against last would be wrong: those are the two ends of the ring, so
        // their wrapped distance grows as the nodes gather.
        func adjacentSeparation(_ convergence: Double) -> Double {
            let first = AlignmentPresentation.nodeAngle(
                index: 0, count: 5, heading: 0, convergence: convergence)
            let second = AlignmentPresentation.nodeAngle(
                index: 1, count: 5, heading: 0, convergence: convergence)
            return Angle.distance(first, second)
        }
        XCTAssertEqual(adjacentSeparation(0), 72, accuracy: 1e-9)
        XCTAssertLessThan(adjacentSeparation(1.0), adjacentSeparation(0.0),
                          "nodes should gather as the composition converges")
    }

    func testZeroNodeCountDoesNotDivideByZero() {
        XCTAssertEqual(
            AlignmentPresentation.nodeAngle(index: 0, count: 0, heading: 0, convergence: 0), 0)
    }
}
