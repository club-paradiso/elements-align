import SwiftUI
import ElementsCore

/// Engine inspector on iPhone.
///
/// Shows every input and intermediate value, including a full sweep of the
/// compass, so the engine's behaviour can be checked without a watch on the
/// wrist. Reached only from Settings; it never appears in the consumer flow.
struct PhoneDebugView: View {
    let chart: PersonalChart
    @Environment(\.dismiss) private var dismiss

    private let calculator = BaZiCalculator()
    private let engine = AlignmentEngine()
    @State private var heading: Double = 135

    var body: some View {
        let temporal = TemporalSnapshot(instant: Date(),
                                        location: chart.profile.birth.location,
                                        calculator: calculator,
                                        options: chart.profile.options)
        let state = engine.evaluate(AlignmentContext(chart: chart,
                                                     temporal: temporal,
                                                     heading: heading))
        List {
            Section("Heading") {
                VStack(alignment: .leading) {
                    Slider(value: $heading, in: 0...359)
                    Text(String(format: "%.0f deg  %@  %@", heading,
                                CompassSector.containing(heading: heading).abbreviation,
                                state.headingRelation?.name ?? "-"))
                        .font(.caption.monospaced())
                }
            }

            Section("Components") {
                mono("spatial", String(format: "%.5f", state.spatialScore))
                mono("temporal", String(format: "%.5f", state.temporalScore))
                mono("personal", String(format: "%.5f", state.personalScore))
                mono("score", String(format: "%.3f", state.score))
                mono("level", state.level.identifier)
            }

            Section("Natal pillars") {
                mono("year", chart.pillars.year.name + " " + chart.pillars.year.chineseName)
                mono("month", chart.pillars.month.name + " " + chart.pillars.month.chineseName)
                mono("day", chart.pillars.day.name + " " + chart.pillars.day.chineseName)
                mono("hour", chart.pillars.hour.map { $0.name + " " + $0.chineseName } ?? "unknown")
                mono("precision", chart.pillars.precision.rawValue)
                mono("boundary min", String(format: "%.2f", chart.pillars.boundaryProximityMinutes))
            }

            Section("Moment pillars") {
                mono("year", temporal.pillars.year.name)
                mono("month", temporal.pillars.month.name)
                mono("day", temporal.pillars.day.name)
                mono("hour", temporal.pillars.hour?.name ?? "-")
                mono("dominant", temporal.dominantElement.identifier)
                mono("valid until", temporal.validUntil.formatted(date: .omitted, time: .standard))
            }

            Section("Natal elements") {
                ForEach(Element.allCases, id: \.self) { element in
                    mono(element.identifier,
                         String(format: "%.4f", chart.natalDistribution[element]))
                }
            }

            Section("Interpretation") {
                mono("day master", chart.dayMaster.name)
                mono("strength", String(format: "%.4f %@", chart.dayMasterStrength,
                                        chart.isDayMasterStrong ? "(strong)" : "(weak)"))
                mono("favourable", chart.favourableElements.map(\.identifier).sorted()
                        .joined(separator: ", "))
                mono("balance", String(format: "%.4f", chart.natalBalance))
                mono("gua", "\(chart.baZhai.gua.number) \(chart.baZhai.gua.trigram.name)")
            }

            Section("Ba Zhai") {
                ForEach(chart.baZhai.sectors, id: \.sector) { entry in
                    mono(entry.sector.abbreviation,
                         "\(entry.relation.name) \(entry.relation.chineseName) "
                         + String(format: "%+.2f", entry.relation.weight))
                }
            }

            Section("Compass sweep") {
                ForEach(Array(stride(from: 0, to: 360, by: 15)), id: \.self) { degrees in
                    let swept = engine.evaluate(AlignmentContext(
                        chart: chart, temporal: temporal, heading: Double(degrees)))
                    mono("\(degrees) deg",
                         String(format: "%.1f  %@", swept.score, swept.level.identifier))
                }
            }
        }
        .navigationTitle("Engine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("action.done")) { dismiss() }
            }
        }
    }

    private func mono(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.caption.monospaced())
    }
}
