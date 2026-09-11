import SwiftUI
import ElementsCore
import ElementsSpatial
import ElementsDesign

/// Developer inspector, reached by long-pressing the composition.
///
/// Its job is to make a score explainable rather than assertable: every input
/// and every component is visible, so it is possible to say why a particular
/// state was produced. It is deliberately plain, and deliberately not on any
/// path a normal user walks.
struct WatchDebugView: View {
    let state: AlignmentState
    let chart: PersonalChart
    let heading: Double?
    let status: HeadingStatus

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                section("Heading") {
                    row("smoothed", heading.map { String(format: "%.1f deg", $0) } ?? "none")
                    row("status", statusText)
                    row("sector", heading.map {
                        CompassSector.containing(heading: $0).abbreviation } ?? "-")
                    row("relation", state.headingRelation?.name ?? "-")
                    row("to ShengQi", state.degreesToFavourable.map {
                        String(format: "%+.1f deg", $0) } ?? "-")
                }

                section("Components") {
                    row("spatial", String(format: "%.4f x %.2f",
                                          state.spatialScore, AlignmentEngine.spatialWeight))
                    row("temporal", String(format: "%.4f x %.2f",
                                           state.temporalScore, AlignmentEngine.temporalWeight))
                    row("personal", String(format: "%.4f x %.2f",
                                           state.personalScore, AlignmentEngine.personalWeight))
                    row("score", String(format: "%.2f", state.score))
                    row("level", state.level.identifier)
                }

                section("Natal chart") {
                    row("year", chart.pillars.year.name)
                    row("month", chart.pillars.month.name)
                    row("day", chart.pillars.day.name)
                    row("hour", chart.pillars.hour?.name ?? "unknown")
                    row("precision", chart.pillars.precision.rawValue)
                    row("boundary", String(format: "%.1f min",
                                           chart.pillars.boundaryProximityMinutes))
                }

                section("Interpretation") {
                    row("day master", "\(chart.dayMaster.name) / \(chart.dayMasterElement.identifier)")
                    row("strength", String(format: "%.3f (%@)", chart.dayMasterStrength,
                                           chart.isDayMasterStrong ? "strong" : "weak"))
                    row("favourable", chart.favourableElements
                        .map(\.identifier).sorted().joined(separator: ", "))
                    row("balance", String(format: "%.3f", chart.natalBalance))
                    row("gua", "\(chart.baZhai.gua.number) \(chart.baZhai.gua.trigram.name)")
                    row("group", chart.baZhai.gua.isEastGroup ? "East" : "West")
                }

                section("Ba Zhai sectors") {
                    ForEach(chart.baZhai.sectors, id: \.sector) { entry in
                        row(entry.sector.abbreviation,
                            "\(entry.relation.name) \(String(format: "%+.2f", entry.relation.weight))")
                    }
                }

                section("Moment") {
                    row("dominant", state.dominantElement.identifier)
                }
            }
            .padding(.horizontal, 4)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var statusText: String {
        switch status {
        case .available: return "available"
        case let .unavailable(reason): return reason.rawValue
        }
    }

    @ViewBuilder
    private func section(_ title: String,
                         @ViewBuilder content: () -> some View) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(Palette.primaryText.dark))
            .padding(.top, 4)
        content()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .foregroundStyle(Color(Palette.secondaryText.dark))
            Spacer(minLength: 2)
            Text(value)
                .foregroundStyle(Color(Palette.primaryText.dark))
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 10, design: .monospaced))
    }
}
