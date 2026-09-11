import SwiftUI
import ElementsCore

struct SettingsView: View {
    let chart: PersonalChart
    var onReset: () -> Void

    @State private var showsDebug = false
    @State private var confirmsReset = false

    var body: some View {
        List {
            Section(LocalizedStringKey("settings.about.title")) {
                Text(LocalizedStringKey("about.what"))
                    .font(.footnote)
                Text(LocalizedStringKey("about.disclaimer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("settings.privacy.title")) {
                Text(LocalizedStringKey("about.privacy"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("settings.calculation.title")) {
                LabeledContent(LocalizedStringKey("settings.lateZi"),
                               value: chart.profile.options.lateZiPolicy.rawValue)
                LabeledContent(LocalizedStringKey("settings.solarTime"),
                               value: chart.profile.options.usesEquationOfTime
                                   ? NSLocalizedString("settings.solarTime.apparent", comment: "")
                                   : NSLocalizedString("settings.solarTime.mean", comment: ""))
                Text(LocalizedStringKey("settings.calculation.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(LocalizedStringKey("settings.debug")) { showsDebug = true }
                Button(LocalizedStringKey("settings.delete"), role: .destructive) {
                    confirmsReset = true
                }
            }
        }
        .sheet(isPresented: $showsDebug) {
            NavigationStack { PhoneDebugView(chart: chart) }
        }
        .confirmationDialog(LocalizedStringKey("settings.delete.confirm"),
                            isPresented: $confirmsReset, titleVisibility: .visible) {
            Button(LocalizedStringKey("settings.delete"), role: .destructive, action: onReset)
            Button(LocalizedStringKey("action.cancel"), role: .cancel) {}
        }
    }
}
