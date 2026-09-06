import XCTest
@testable import ElementsCore

final class AlignmentTests: XCTestCase {

    /// Rebuilds the fixture's profile through the real pipeline, so these
    /// tests exercise everything from the birth instant down.
    private func makeChart() -> (PersonalChart, TemporalSnapshot) {
        let fixture = Fixtures.root.alignmentProfile
        let calculator = BaZiCalculator()
        let location = GeoLocation(latitude: 0, longitude: fixture.longitude)
        let profile = PersonalProfile(
            birth: BirthMoment(instant: Fixtures.date(fixture.natalUTC), location: location),
            polarity: fixture.polarity == "yang" ? .yang : .yin)
        let chart = PersonalChart(profile: profile, calculator: calculator)
        let temporal = TemporalSnapshot(instant: Fixtures.date(fixture.nowUTC),
                                        location: location,
                                        calculator: calculator)
        return (chart, temporal)
    }

    func testChartDerivationMatchesFixture() {
        let fixture = Fixtures.root.alignmentProfile
        let (chart, temporal) = makeChart()

        XCTAssertEqual(chart.baZhai.gua.number, fixture.gua)
        XCTAssertEqual(chart.dayMasterElement.identifier.capitalized, fixture.dayMaster)
        XCTAssertEqual(chart.dayMasterStrength, fixture.dayMasterStrength, accuracy: 1e-9)
        XCTAssertEqual(chart.natalBalance, fixture.natalBalance, accuracy: 1e-9)

        XCTAssertEqual(Set(chart.favourableElements.map { $0.identifier.capitalized }),
                       Set(fixture.favourableElements))

        for (name, expected) in fixture.natalDistribution {
            guard let element = Element.allCases.first(
                where: { $0.identifier.capitalized == name }) else {
                return XCTFail("unknown element \(name)")
            }
            XCTAssertEqual(chart.natalDistribution[element], expected, accuracy: 1e-9)
        }

        for (key, indices) in fixture.natalPillars {
            let pillar: Pillar?
            switch key {
            case "year": pillar = chart.pillars.year
            case "month": pillar = chart.pillars.month
            case "day": pillar = chart.pillars.day
            default: pillar = chart.pillars.hour
            }
            XCTAssertEqual([pillar?.stem.rawValue, pillar?.branch.rawValue].compactMap { $0 },
                           indices, "natal \(key)")
        }

        for (key, indices) in fixture.nowPillars {
            let pillar: Pillar?
            switch key {
            case "year": pillar = temporal.pillars.year
            case "month": pillar = temporal.pillars.month
            case "day": pillar = temporal.pillars.day
            default: pillar = temporal.pillars.hour
            }
            XCTAssertEqual([pillar?.stem.rawValue, pillar?.branch.rawValue].compactMap { $0 },
                           indices, "moment \(key)")
        }
    }

    func testAlignmentSweepMatchesFixtures() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()

        for testCase in Fixtures.root.alignmentSweep {
            let state = engine.evaluate(
                AlignmentContext(chart: chart, temporal: temporal, heading: testCase.heading))
            let at = "heading \(testCase.heading)"
            XCTAssertEqual(state.score, testCase.score, accuracy: 1e-9, at)
            XCTAssertEqual(state.spatialScore, testCase.spatial, accuracy: 1e-9, at)
            XCTAssertEqual(state.temporalScore, testCase.temporal, accuracy: 1e-9, at)
            XCTAssertEqual(state.personalScore, testCase.personal, accuracy: 1e-9, at)
            XCTAssertEqual(state.level.identifier, testCase.level, at)
        }
    }

    // MARK: - Properties the product depends on

    func testRotatingAFullCircleCrossesSeveralLevels() {
        // The central interaction. If turning the body does not move the state,
        // there is no product.
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        var levels = Set<AlignmentLevel>()
        var scores: [Double] = []
        for heading in stride(from: 0.0, to: 360.0, by: 5.0) {
            let state = engine.evaluate(
                AlignmentContext(chart: chart, temporal: temporal, heading: heading))
            levels.insert(state.level)
            scores.append(state.score)
        }
        XCTAssertGreaterThanOrEqual(levels.count, 3,
                                    "a full rotation should cross at least three levels")
        guard let low = scores.min(), let high = scores.max() else { return XCTFail() }
        XCTAssertGreaterThan(high - low, 20.0,
                             "best and worst directions should be clearly different")
    }

    func testScoreIsHighestFacingTheMostFavourableDirection() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()

        let best = engine.evaluate(AlignmentContext(
            chart: chart, temporal: temporal,
            heading: chart.baZhai.primaryDirection.centerDegrees))

        for heading in stride(from: 0.0, to: 360.0, by: 1.0) {
            let state = engine.evaluate(
                AlignmentContext(chart: chart, temporal: temporal, heading: heading))
            XCTAssertLessThanOrEqual(state.score, best.score + 1e-9,
                                     "no heading should beat Sheng Qi")
        }
        XCTAssertEqual(best.headingRelation, .shengQi)
        XCTAssertEqual(best.degreesToFavourable ?? .nan, 0, accuracy: 1e-9)
    }

    func testUnfavourableDirectionsAreCompressedNotPunished() {
        // The traditional ordering must survive, but the worst direction should
        // land well above zero: this product does not tell people that where
        // they are standing is bad for them.
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        var worst = 1.0
        for heading in stride(from: 0.0, to: 360.0, by: 1.0) {
            worst = min(worst, engine.spatialComponent(heading: heading,
                                                       baZhai: chart.baZhai))
        }
        XCTAssertEqual(worst, AlignmentEngine.unfavourableCompression, accuracy: 1e-9)
        XCTAssertGreaterThan(worst, 0.2)
    }

    func testSpatialComponentPreservesTraditionalOrdering() {
        let (chart, _) = makeChart()
        let engine = AlignmentEngine()
        let ranked = chart.baZhai.sectors
            .map { ($0.relation, engine.spatialComponent(heading: $0.sector.centerDegrees,
                                                         baZhai: chart.baZhai)) }
            .sorted { $0.1 > $1.1 }
        let expected: [BaZhaiRelation] = [.shengQi, .tianYi, .yanNian, .fuWei,
                                          .huoHai, .liuSha, .wuGui, .jueMing]
        XCTAssertEqual(ranked.map(\.0), expected,
                       "spatial scores must rank the eight relations traditionally")
    }

    func testMissingHeadingFallsBackToNeutralAndSaysSo() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        let state = engine.evaluate(
            AlignmentContext(chart: chart, temporal: temporal, heading: nil))

        XCTAssertFalse(state.isHeadingAvailable)
        XCTAssertEqual(state.spatialScore, 0.5, accuracy: 1e-9)
        XCTAssertNil(state.headingRelation)
        XCTAssertNil(state.degreesToFavourable)
    }

    func testEvaluationIsDeterministic() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        let context = AlignmentContext(chart: chart, temporal: temporal, heading: 137.5)
        let first = engine.evaluate(context)
        for _ in 0..<50 {
            XCTAssertEqual(engine.evaluate(context), first)
        }
    }

    func testScoreStaysWithinBounds() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        for heading in stride(from: -720.0, through: 1080.0, by: 3.0) {
            let state = engine.evaluate(
                AlignmentContext(chart: chart, temporal: temporal, heading: heading))
            XCTAssertGreaterThanOrEqual(state.score, 0)
            XCTAssertLessThanOrEqual(state.score, 100)
        }
    }

    func testHeadingWrapsRatherThanClamping() {
        let (chart, temporal) = makeChart()
        let engine = AlignmentEngine()
        for heading in stride(from: 0.0, to: 360.0, by: 7.0) {
            let base = engine.evaluate(
                AlignmentContext(chart: chart, temporal: temporal, heading: heading))
            for turns in [-720.0, -360.0, 360.0, 720.0] {
                let wrapped = engine.evaluate(AlignmentContext(
                    chart: chart, temporal: temporal, heading: heading + turns))
                XCTAssertEqual(wrapped.score, base.score, accuracy: 1e-9)
            }
        }
    }

    // MARK: - Levels

    func testLevelThresholdsAreOrderedAndContiguous() {
        let levels = AlignmentLevel.allCases
        for (earlier, later) in zip(levels, levels.dropFirst()) {
            XCTAssertLessThan(earlier.lowerBound, later.lowerBound)
            XCTAssertLessThan(earlier, later)
            // The boundary itself belongs to the higher level.
            XCTAssertEqual(AlignmentLevel.forScore(later.lowerBound), later)
            XCTAssertEqual(AlignmentLevel.forScore(later.lowerBound - 0.001), earlier)
        }
        XCTAssertEqual(AlignmentLevel.forScore(0), .low)
        XCTAssertEqual(AlignmentLevel.forScore(100), .aligned)
        XCTAssertEqual(AlignmentLevel.forScore(-50), .low)
    }

    func testOnlyStrongAndAlignedAreElevated() {
        XCTAssertFalse(AlignmentLevel.neutral.isElevated)
        XCTAssertFalse(AlignmentLevel.favourable.isElevated)
        XCTAssertTrue(AlignmentLevel.strong.isElevated)
        XCTAssertTrue(AlignmentLevel.aligned.isElevated)
    }
}
