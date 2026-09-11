import SwiftUI
import ElementsCore
import ElementsSpatial
import ElementsDesign

/// The watch's primary screen.
///
/// One composition, not a dashboard of cards. The state name is the headline;
/// the number, if shown at all, is secondary — a score to one decimal place
/// would look like a measurement, and this is not one.
struct AlignmentView: View {
    @Bindable var model: WatchAlignmentModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsDebug = false

    var body: some View {
        ZStack {
            Color(Palette.background.dark).ignoresSafeArea()

            if model.needsProfile {
                SetupRequiredView()
            } else if let state = model.state {
                composition(for: state)
            } else {
                ProgressView().tint(Color(Palette.secondaryText.dark))
            }
        }
        .sheet(isPresented: $showsDebug) {
            if let state = model.state, let chart = model.chart {
                WatchDebugView(state: state, chart: chart,
                               heading: model.smoothedHeading,
                               status: model.headingStatus)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private func composition(for state: AlignmentState) -> some View {
        let presentation = AlignmentPresentation(state: state)

        ZStack {
            ElementFieldView(presentation: presentation,
                             heading: model.smoothedHeading ?? 0,
                             level: model.presentationLevel,
                             dominantElement: state.dominantElement)

            VStack(spacing: 2) {
                if presentation.showsBrandConvergence {
                    // The brand phrase is an event, not a label. It appears
                    // only here, at full alignment, and nowhere else.
                    Text("ELEMENTS,")
                        .font(.system(size: 13, weight: .light))
                        .tracking(2.5)
                    Text("ALIGN.")
                        .font(.system(size: 13, weight: .light))
                        .tracking(2.5)
                } else {
                    Text(LocalizedStringKey(model.presentationLevel.localizationKey))
                        .font(.system(size: 15, weight: .light))
                        .tracking(1.5)
                }

                if !state.isHeadingAvailable {
                    Text(LocalizedStringKey(headingHint))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(Palette.secondaryText.dark))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                } else if !presentation.showsBrandConvergence {
                    DirectionCue(state: state)
                }
            }
            .foregroundStyle(Color(Palette.token(for: model.presentationLevel).dark))
            .animation(.elements(Motion.convergence, reduceMotion: reduceMotion),
                       value: presentation.showsBrandConvergence)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.8) { showsDebug = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(model.presentationLevel.localizationKey)))
        .accessibilityValue(Text(accessibilityValue(for: state)))
    }

    private var headingHint: String {
        guard case let .unavailable(reason) = model.headingStatus else {
            return "heading.unavailable.calibrating"
        }
        return "heading.unavailable.\(reason.rawValue)"
    }

    private func accessibilityValue(for state: AlignmentState) -> String {
        guard state.isHeadingAvailable, let degrees = state.degreesToFavourable else {
            return NSLocalizedString("heading.unavailable.short", comment: "")
        }
        let direction = NSLocalizedString(state.favourableDirection.localizationKey, comment: "")
        return String(format: NSLocalizedString("alignment.accessibility.value", comment: ""),
                      direction, Int(abs(degrees).rounded()))
    }
}

/// A restrained pointer towards the favourable direction.
///
/// Deliberately not an arrow that shouts: it is a short mark that rotates, so
/// the information is there for anyone looking for it without turning the face
/// into a navigation instrument.
private struct DirectionCue: View {
    let state: AlignmentState

    var body: some View {
        if let degrees = state.degreesToFavourable {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 7))
                .foregroundStyle(Color(Palette.secondaryText.dark))
                .rotationEffect(.degrees(degrees))
                .opacity(abs(degrees) < 8 ? 0 : 0.8)
                .padding(.top, 3)
        }
    }
}

private struct SetupRequiredView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("ELEMENTS,")
                .font(.system(size: 12, weight: .light)).tracking(2)
            Text("ALIGN.")
                .font(.system(size: 12, weight: .light)).tracking(2)
            Text(LocalizedStringKey("watch.setup.required"))
                .font(.system(size: 11))
                .foregroundStyle(Color(Palette.secondaryText.dark))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .foregroundStyle(Color(Palette.primaryText.dark))
        .padding()
    }
}
