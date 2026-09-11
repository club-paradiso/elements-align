import SwiftUI
import ElementsCore
import ElementsDesign

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

    var body: some View {
        let chart = PersonalChart(profile: profile, calculator: calculator)
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
