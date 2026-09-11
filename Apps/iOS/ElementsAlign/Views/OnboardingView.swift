import SwiftUI
import ElementsCore
import ElementsDesign

/// The onboarding flow.
///
/// Short by design. The product's claim is that it responds to where you are
/// and when; asking a long list of questions before showing anything would
/// contradict that.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: model.step)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            VStack(spacing: 14) {
                Text("ELEMENTS,").font(.system(size: 22, weight: .light)).tracking(4)
                Text("ALIGN.").font(.system(size: 22, weight: .light)).tracking(4)
                Text(LocalizedStringKey("onboarding.welcome.body"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

        case .birthDate:
            step(title: "onboarding.birthDate.title",
                 note: "onboarding.birthDate.note") {
                DatePicker("", selection: $model.birthDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }

        case .birthTime:
            step(title: "onboarding.birthTime.title",
                 note: model.birthTimeIsKnown
                    ? "onboarding.birthTime.note"
                    : "onboarding.birthTime.unknownNote") {
                VStack(spacing: 12) {
                    Toggle(LocalizedStringKey("onboarding.birthTime.known"),
                           isOn: $model.birthTimeIsKnown)
                    if model.birthTimeIsKnown {
                        DatePicker("", selection: $model.birthTime,
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                }
            }

        case .birthPlace:
            step(title: "onboarding.birthPlace.title",
                 note: "onboarding.birthPlace.note") {
                VStack(spacing: 10) {
                    BirthPlacePicker(selection: $model.place,
                                     manualLongitude: $model.manualLongitude,
                                     manualTimeZone: $model.manualTimeZoneIdentifier)
                    // The offset actually applied. Worth showing: it is how a
                    // user born in Korea in 1955 finds out the app knows the
                    // country was on UTC+8:30 at the time.
                    if let offset = model.utcOffsetDescription {
                        Text("\(model.timeZoneIdentifier)  ·  \(offset)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case .polarity:
            step(title: "onboarding.polarity.title",
                 note: "onboarding.polarity.note") {
                Picker("", selection: $model.polarity) {
                    Text(LocalizedStringKey("polarity.yang")).tag(Polarity.yang)
                    Text(LocalizedStringKey("polarity.yin")).tag(Polarity.yin)
                }
                .pickerStyle(.segmented)
            }

        case .permissions:
            step(title: "onboarding.permissions.title",
                 note: "onboarding.permissions.note") {
                Image(systemName: "location.north.line")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(.secondary)
            }

        case .summary:
            ChartSummaryView(chart: model.previewChart)
        }
    }

    @ViewBuilder
    private func step(title: String, note: String,
                      @ViewBuilder control: () -> some View) -> some View {
        VStack(spacing: 16) {
            Text(LocalizedStringKey(title))
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
            control()
            Text(LocalizedStringKey(note))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var controls: some View {
        HStack {
            if model.step != .welcome {
                Button(LocalizedStringKey("action.back")) { model.retreat() }
                    .buttonStyle(.bordered)
            }
            Spacer()
            Button(model.step == .summary
                   ? LocalizedStringKey("action.begin")
                   : LocalizedStringKey("action.continue")) {
                if model.step == .summary {
                    model.finish()
                    onFinish()
                } else {
                    model.advance()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// Offline place selection, with a manual longitude escape hatch.
private struct BirthPlacePicker: View {
    @Binding var selection: BirthPlace?
    @Binding var manualLongitude: Double?
    @Binding var manualTimeZone: String
    @State private var query = ""
    @State private var usesManual = false
    @State private var longitudeText = ""

    var body: some View {
        VStack(spacing: 10) {
            Toggle(LocalizedStringKey("onboarding.birthPlace.manual"), isOn: $usesManual)
                .onChange(of: usesManual) { _, isOn in
                    manualLongitude = isOn ? Double(longitudeText) : nil
                }

            if usesManual {
                TextField(LocalizedStringKey("onboarding.birthPlace.longitude"),
                          text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: longitudeText) { _, text in
                        manualLongitude = Double(text).map { min(max($0, -180), 180) }
                    }
                // A longitude alone cannot resolve a wall-clock reading: we
                // also have to know whose clocks were being read.
                Picker(LocalizedStringKey("onboarding.birthPlace.timeZone"),
                       selection: $manualTimeZone) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(identifier).tag(identifier)
                    }
                }
                .pickerStyle(.navigationLink)
            } else {
                TextField(LocalizedStringKey("onboarding.birthPlace.search"), text: $query)
                    .textFieldStyle(.roundedBorder)
                List(BirthPlace.search(query)) { place in
                    Button {
                        selection = place
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.displayName)
                                Text(place.timeZoneIdentifier)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection?.id == place.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(maxHeight: 220)
            }
        }
    }
}
