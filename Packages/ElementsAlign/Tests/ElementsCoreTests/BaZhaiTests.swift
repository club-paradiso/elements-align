import XCTest
@testable import ElementsCore

final class BaZhaiTests: XCTestCase {

    func testLifeGuaMatchesFixtures() {
        for testCase in Fixtures.root.lifeGua {
            let polarity: Polarity = testCase.polarity == "yang" ? .yang : .yin
            let gua = LifeGua(baziYear: testCase.baziYear, polarity: polarity)
            XCTAssertEqual(gua.number, testCase.gua,
                           "\(testCase.baziYear) \(testCase.polarity)")
        }
    }

    func testLifeGuaMatchesPerCenturyClassicalRules() {
        // External check of the congruence against the way the rule is usually
        // stated: reduce the last two digits of the year to a single digit,
        // then subtract from 10 (1900s) or 9 (2000s) for yang, or add 5 (1900s)
        // or 6 (2000s) for yin. 5 has no trigram and is reassigned.
        func classical(year: Int, polarity: Polarity) -> Int {
            var reduced = String(year).suffix(2).compactMap { $0.wholeNumberValue }.reduce(0, +)
            while reduced > 9 { reduced = String(reduced).compactMap { $0.wholeNumberValue }.reduce(0, +) }
            var gua: Int
            if year < 2000 {
                gua = polarity == .yang ? 10 - reduced : reduced + 5
            } else {
                gua = polarity == .yang ? 9 - reduced : reduced + 6
            }
            while gua > 9 { gua -= 9 }
            if gua == 0 { gua = 9 }
            if gua == 5 { gua = polarity == .yang ? 2 : 8 }
            return gua
        }

        for year in 1900...2060 {
            for polarity in [Polarity.yang, .yin] {
                XCTAssertEqual(LifeGua(baziYear: year, polarity: polarity).number,
                               classical(year: year, polarity: polarity),
                               "\(year) \(polarity.identifier)")
            }
        }
    }

    func testLifeGuaNeverProducesFive() {
        for year in 1900...2100 {
            for polarity in [Polarity.yang, .yin] {
                let gua = LifeGua(baziYear: year, polarity: polarity)
                XCTAssertNotEqual(gua.number, 5, "5 has no trigram and must be reassigned")
                XCTAssertTrue((1...9).contains(gua.number))
            }
        }
    }

    func testKanMatchesThePublishedClassicalRow() {
        // External check. This is the row every Eight Mansions table prints,
        // and the derivation must reproduce all eight entries.
        let profile = BaZhaiProfile(gua: LifeGua(baziYear: 1972, polarity: .yang))
        XCTAssertEqual(profile.gua.number, 1, "1972 yang should be Kan")

        let expected: [CompassSector: BaZhaiRelation] = [
            .north: .fuWei, .southeast: .shengQi, .east: .tianYi, .south: .yanNian,
            .west: .huoHai, .northeast: .wuGui, .northwest: .liuSha, .southwest: .jueMing,
        ]
        for (sector, relation) in expected {
            XCTAssertEqual(profile.relation(for: sector), relation,
                           "Kan / \(sector.abbreviation)")
        }
    }

    func testBaZhaiSectorsMatchFixtures() {
        for testCase in Fixtures.root.baZhai {
            // Find any year/polarity producing this gua, so the fixture's gua
            // number is what is under test rather than a particular birth year.
            guard let profile = Self.profile(forGua: testCase.gua) else {
                return XCTFail("no year produces gua \(testCase.gua)")
            }
            XCTAssertEqual(profile.gua.isEastGroup, testCase.eastGroup,
                           "east/west group for gua \(testCase.gua)")

            for sector in testCase.sectors {
                guard let compass = CompassSector(rawValue: Int(sector.degrees / 45.0)) else {
                    return XCTFail("bad sector \(sector.degrees)")
                }
                let relation = profile.relation(for: compass)
                XCTAssertEqual(relation.name, sector.relation,
                               "gua \(testCase.gua) at \(compass.abbreviation)")
                XCTAssertEqual(relation.weight, sector.weight, accuracy: 1e-9)
            }
        }
    }

    /// Finds a profile with the requested gua number.
    static func profile(forGua gua: Int) -> BaZhaiProfile? {
        for year in 1900...2000 {
            for polarity in [Polarity.yang, .yin] {
                let candidate = LifeGua(baziYear: year, polarity: polarity)
                if candidate.number == gua { return BaZhaiProfile(gua: candidate) }
            }
        }
        return nil
    }

    func testEveryGuaHasFourAuspiciousAndFourInauspiciousSectors() {
        for gua in [1, 2, 3, 4, 6, 7, 8, 9] {
            guard let profile = Self.profile(forGua: gua) else {
                return XCTFail("no year produces gua \(gua)")
            }
            let relations = profile.sectors.map(\.relation)
            XCTAssertEqual(Set(relations).count, 8,
                           "gua \(gua) must map the eight sectors to eight distinct relations")
            XCTAssertEqual(relations.filter(\.isAuspicious).count, 4, "gua \(gua)")
        }
    }

    func testRelationPairingIsSymmetric() {
        // A structural property of the classical system: if your relationship
        // to another trigram's direction is Sheng Qi, theirs to yours is too.
        // The XOR derivation guarantees it; this asserts the guarantee holds.
        for gua in [1, 2, 3, 4, 6, 7, 8, 9] {
            guard let mine = Self.profile(forGua: gua) else { continue }
            for sector in CompassSector.allCases {
                let relation = mine.relation(for: sector)
                let theirTrigram = sector.trigram
                guard let theirs = Self.profileForTrigram(theirTrigram) else { continue }
                let back = theirs.relation(for: mine.gua.trigram.direction)
                XCTAssertEqual(relation, back,
                               "gua \(gua) vs \(theirTrigram.name) is asymmetric")
            }
        }
    }

    static func profileForTrigram(_ trigram: Trigram) -> BaZhaiProfile? {
        for year in 1900...2000 {
            for polarity in [Polarity.yang, .yin] {
                let candidate = LifeGua(baziYear: year, polarity: polarity)
                if candidate.trigram == trigram { return BaZhaiProfile(gua: candidate) }
            }
        }
        return nil
    }

    func testFuWeiIsAlwaysYourOwnDirection() {
        for gua in [1, 2, 3, 4, 6, 7, 8, 9] {
            guard let profile = Self.profile(forGua: gua) else { continue }
            XCTAssertEqual(profile.relation(for: profile.gua.trigram.direction), .fuWei)
        }
    }

    // MARK: - Continuous directional value

    func testDirectionalValueMatchesFixtures() {
        for testCase in Fixtures.root.directionalValue {
            guard let profile = Self.profile(forGua: testCase.gua) else {
                return XCTFail("no year produces gua \(testCase.gua)")
            }
            XCTAssertEqual(profile.directionalValue(heading: testCase.heading),
                           testCase.value, accuracy: 1e-9,
                           "gua \(testCase.gua) at \(testCase.heading) degrees")
        }
    }

    func testDirectionalValuePeaksExactlyOnSectorCentres() {
        guard let profile = Self.profile(forGua: 1) else { return XCTFail() }
        for sector in CompassSector.allCases {
            let atCentre = profile.directionalValue(heading: sector.centerDegrees)
            XCTAssertEqual(atCentre, profile.relation(for: sector).weight, accuracy: 1e-9,
                           "value at \(sector.abbreviation) centre must be the sector's own weight")
        }
    }

    func testDirectionalValueIsContinuousAcrossTheWrap() {
        guard let profile = Self.profile(forGua: 7) else { return XCTFail() }
        let justBefore = profile.directionalValue(heading: 359.999)
        let atZero = profile.directionalValue(heading: 0)
        XCTAssertEqual(justBefore, atZero, accuracy: 1e-4,
                       "the value must not jump at the 0/360 seam")

        // And nowhere else either: no step larger than a small bound between
        // adjacent tenth-degree samples.
        var previous = profile.directionalValue(heading: 0)
        for step in 1...3600 {
            let value = profile.directionalValue(heading: Double(step) / 10.0)
            XCTAssertLessThan(abs(value - previous), 0.02,
                              "discontinuity near \(Double(step) / 10.0) degrees")
            previous = value
        }
    }

    func testDirectionalValueStaysInRange() {
        for gua in [1, 2, 3, 4, 6, 7, 8, 9] {
            guard let profile = Self.profile(forGua: gua) else { continue }
            for step in 0...3600 {
                let value = profile.directionalValue(heading: Double(step) / 10.0)
                XCTAssertGreaterThanOrEqual(value, -1.0)
                XCTAssertLessThanOrEqual(value, 1.0)
            }
        }
    }

    func testPrimaryDirectionIsShengQi() {
        for gua in [1, 2, 3, 4, 6, 7, 8, 9] {
            guard let profile = Self.profile(forGua: gua) else { continue }
            XCTAssertEqual(profile.relation(for: profile.primaryDirection), .shengQi)
        }
    }

    // MARK: - Sectors

    func testCompassSectorBoundaries() {
        // Sectors are centred on multiples of 45 degrees, so each spans 22.5
        // degrees either side of its centre.
        XCTAssertEqual(CompassSector.containing(heading: 0), .north)
        XCTAssertEqual(CompassSector.containing(heading: 22.4), .north)
        XCTAssertEqual(CompassSector.containing(heading: 22.6), .northeast)
        XCTAssertEqual(CompassSector.containing(heading: 337.6), .north)
        XCTAssertEqual(CompassSector.containing(heading: 337.4), .northwest)
        XCTAssertEqual(CompassSector.containing(heading: 359.9), .north)
        XCTAssertEqual(CompassSector.containing(heading: 180), .south)
        // Values outside [0,360) must fold, not crash or clamp.
        XCTAssertEqual(CompassSector.containing(heading: 720), .north)
        XCTAssertEqual(CompassSector.containing(heading: -90), .west)
    }

    func testTrigramDirectionsAreTheLaterHeavenArrangement() {
        XCTAssertEqual(Trigram.kan.direction, .north)
        XCTAssertEqual(Trigram.li.direction, .south)
        XCTAssertEqual(Trigram.zhen.direction, .east)
        XCTAssertEqual(Trigram.dui.direction, .west)
        XCTAssertEqual(Trigram.qian.direction, .northwest)
        XCTAssertEqual(Trigram.kun.direction, .southwest)
        XCTAssertEqual(Trigram.gen.direction, .northeast)
        XCTAssertEqual(Trigram.xun.direction, .southeast)
        // Every sector is claimed exactly once.
        XCTAssertEqual(Set(Trigram.allCases.map(\.direction)).count, 8)
    }

    func testTrigramLineEncoding() {
        XCTAssertEqual(Trigram.qian.rawValue, 0b111)
        XCTAssertEqual(Trigram.kun.rawValue, 0b000)
        XCTAssertTrue(Trigram.kan.middleLineIsYang)
        XCTAssertFalse(Trigram.kan.bottomLineIsYang)
        XCTAssertFalse(Trigram.kan.topLineIsYang)
        XCTAssertTrue(Trigram.gen.topLineIsYang)
    }

    func testRelationMasksAreDistinctAndCoverAllEight() {
        XCTAssertEqual(Set(BaZhaiRelation.allCases.map(\.lineMask)).count, 8)
        XCTAssertEqual(BaZhaiRelation.fuWei.lineMask, 0)
        XCTAssertEqual(BaZhaiRelation.yanNian.lineMask, 0b111)
    }
}
