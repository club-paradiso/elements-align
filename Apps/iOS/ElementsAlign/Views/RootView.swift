import SwiftUI
import ElementsCore
import ElementsProfile
import ElementsDesign

// Explicitly main-actor isolated for the same reason as the watch app:
// OnboardingModel is a @MainActor type constructed in a stored property.
@MainActor
struct RootView: View {
    @State private var onboarding = OnboardingModel()
    @State private var profile: PersonalProfile?
    @State private var isOnboarding = false

    private let store = ProfileStore()
    private let calculator = BaZiCalculator()

    var body: some View {
        Group {
            if isOnboarding || profile == nil {
                OnboardingView(model: onboarding) {
                    profile = store.load()
                    isOnboarding = false
                }
            } else if let profile {
                MainTabs(profile: profile,
                         calculator: calculator,
                         onReset: {
                             store.clear()
                             self.profile = nil
                             onboarding = OnboardingModel()
                             isOnboarding = true
                         })
            }
        }
        .onAppear {
            profile = store.load()
            isOnboarding = profile == nil
        }
    }
}

private struct MainTabs: View {
    let profile: PersonalProfile
    let calculator: BaZiCalculator
    var onReset: () -> Void

    /// Built once when this view appears rather than in `body`. Building a
    /// chart runs the solar-term solver, which must never sit on a render
    /// path -- see Documentation/ARCHITECTURE.md.
    @State private var chart: PersonalChart?

    var body: some View {
        Group {
            if let chart {
                tabs(chart: chart)
            } else {
                ProgressView()
            }
        }
        .task(id: profile) {
            chart = PersonalChart(profile: profile, calculator: calculator)
        }
    }

    private func tabs(chart: PersonalChart) -> some View {
        TabView {
            NavigationStack {
                ChartSummaryView(chart: chart)
                    .navigationTitle(Text(LocalizedStringKey("tab.profile")))
            }
            .tabItem { Label(LocalizedStringKey("tab.profile"), systemImage: "circle.hexagongrid") }

            NavigationStack {
                SettingsView(chart: chart, onReset: onReset)
                    .navigationTitle(Text(LocalizedStringKey("tab.settings")))
            }
            .tabItem { Label(LocalizedStringKey("tab.settings"), systemImage: "gearshape") }
        }
    }
}
