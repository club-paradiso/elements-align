import SwiftUI
import ElementsCore
import ElementsDesign

/// Shows what the user's answers produced.
///
/// Uses the vocabulary a reader can actually follow: "Four Pillars" before
/// "BaZi", "Five Elements" rather than "Wu Xing". Nobody should have to learn
/// the technical terms before the product becomes useful to them.
struct ChartSummaryView: View {
    let chart: PersonalChart
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                elementBars
                pillarsGrid
                directions
                if chart.pillars.isNearMonthBoundary { boundaryNotice }
                if chart.pillars.precision == .dayOnly { precisionNotice }
                if let timeZoneNotice { timeZoneNotice }
                disclaimer
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey("summary.dayMaster.title"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.token(for: chart.dayMasterElement).resolved(for: scheme))
                    .frame(width: 14, height: 14)
                Text(LocalizedStringKey(chart.dayMasterElement.localizationKey))
                    .font(.title2.weight(.medium))
                Text(chart.dayMaster.chineseName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text(LocalizedStringKey(chart.isDayMasterStrong
                                    ? "summary.dayMaster.strong"
                                    : "summary.dayMaster.weak"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var elementBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("summary.elements.title"))
                .font(.headline)
            ForEach(Element.allCases, id: \.self) { element in
                HStack(spacing: 10) {
                    Text(LocalizedStringKey(element.localizationKey))
                        .font(.subheadline)
                        .frame(width: 60, alignment: .leading)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Palette.hairline.resolved(for: scheme))
                                .frame(height: 6)
                            Capsule()
                                .fill(Palette.token(for: element).resolved(for: scheme))
                                .frame(width: geometry.size.width
                                       * chart.natalDistribution[element], height: 6)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 14)
                    Text("\(Int((chart.natalDistribution[element] * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    private var pillarsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("summary.pillars.title"))
                .font(.headline)
            HStack(spacing: 10) {
                pillar("summary.pillars.year", chart.pillars.year)
                pillar("summary.pillars.month", chart.pillars.month)
                pillar("summary.pillars.day", chart.pillars.day)
                pillar("summary.pillars.hour", chart.pillars.hour)
            }
        }
    }

    private func pillar(_ titleKey: String, _ pillar: Pillar?) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let pillar {
                Text(pillar.chineseName).font(.title3)
                Text(pillar.name).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("—").font(.title3).foregroundStyle(.secondary)
                Text(LocalizedStringKey("summary.pillars.unknown"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Palette.hairline.resolved(for: scheme).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var directions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("summary.directions.title"))
                .font(.headline)
            Text(LocalizedStringKey(chart.baZhai.gua.groupLocalizationKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(chart.baZhai.auspiciousSectors, id: \.sector) { entry in
                HStack {
                    Text(LocalizedStringKey(entry.sector.localizationKey))
                        .frame(width: 96, alignment: .leading)
                    Text(LocalizedStringKey(entry.relation.localizationKey))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.relation.chineseName)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    /// Shown only when the wall-clock reading did not map to one instant.
    /// A clean reading needs no explanation.
    @ViewBuilder
    private var timeZoneNotice: (some View)? {
        switch chart.profile.birth.timeResolution {
        case .unique:
            EmptyView().hidden()
        case .ambiguous:
            notice("summary.notice.ambiguousTime")
        case .skipped:
            notice("summary.notice.skippedTime")
        case .unknownTimeZone:
            notice("summary.notice.unknownTimeZone")
        }
    }

    private var boundaryNotice: some View {
        notice("summary.notice.boundary")
    }

    private var precisionNotice: some View {
        notice("summary.notice.precision")
    }

    private func notice(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.hairline.resolved(for: scheme).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var disclaimer: some View {
        Text(LocalizedStringKey("about.disclaimer"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
