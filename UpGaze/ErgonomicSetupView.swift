import AppKit
import SwiftUI

enum ErgonomicStep: Int, CaseIterable, Identifiable {
    case chair
    case sittingDesk
    case standingDesk
    case monitor

    var id: Int { rawValue }
}

/// Target heights in whole centimetres, measured from the floor.
struct ErgonomicMeasurements {
    static let heightRange: ClosedRange<Double> = 145...215

    let userHeightCm: Double

    var seatHeight: Int { cm(0.265) }
    var sittingDeskHeight: Int { cm(0.41) }
    var standingDeskHeight: Int { cm(0.60) }
    var sittingMonitorTop: Int { cm(0.70) }
    var standingMonitorTop: Int { cm(0.93) }

    private func cm(_ ratio: Double) -> Int {
        Int((userHeightCm * ratio).rounded())
    }
}

@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    static let shared = SetupWindowController()

    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        if !window.isVisible {
            let view = ErgonomicSetupView { [weak window] in window?.close() }
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
        }
        updateTitle()
        // An LSUIElement app is never frontmost by itself, so the window would open behind other apps.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func updateTitle() {
        window?.title = L10n.current.setupWindowTitle
    }

    func windowWillClose(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: SettingsKey.hasCompletedSetup)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }
}

struct ErgonomicSetupView: View {
    var onFinish: () -> Void = {}

    @AppStorage(SettingsKey.userHeightCm) private var userHeightCm = 178.0
    @Localized private var l10n
    @State private var currentStep: ErgonomicStep = .chair

    private var measurements: ErgonomicMeasurements {
        ErgonomicMeasurements(userHeightCm: userHeightCm)
    }

    var body: some View {
        VStack(spacing: 0) {
            heightBar
            Divider()
            HStack(spacing: 0) {
                stage
                    .frame(width: 340)
                Divider()
                guide
            }
        }
        .frame(width: 680, height: 520)
        .onChange(of: userHeightCm) { _, newValue in
            let range = ErgonomicMeasurements.heightRange
            let clamped = min(max(newValue.rounded(), range.lowerBound), range.upperBound)
            if clamped != newValue { userHeightCm = clamped }
        }
        .onChange(of: l10n) {
            SetupWindowController.shared.updateTitle()
        }
    }

    private var heightBar: some View {
        HStack(spacing: 12) {
            Label(l10n.yourHeight, systemImage: "ruler")
                .font(.headline)
            Slider(value: $userHeightCm, in: ErgonomicMeasurements.heightRange, step: 1)
                .accessibilityLabel(l10n.heightAccessibility)
            TextField(l10n.heightField, value: $userHeightCm, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
            Text(l10n.centimetreUnit)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var stage: some View {
        VStack(spacing: 14) {
            ErgonomicAnimationView(userHeightCm: userHeightCm, activeStep: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 6) {
                measurementRow(l10n.seatHeight, measurements.seatHeight, step: .chair)
                measurementRow(l10n.deskHeightSittingRow, measurements.sittingDeskHeight, step: .sittingDesk)
                measurementRow(l10n.deskHeightStandingRow, measurements.standingDeskHeight, step: .standingDesk)
                measurementRow(l10n.monitorTopSittingRow, measurements.sittingMonitorTop, step: .monitor)
                measurementRow(l10n.monitorTopStandingRow, measurements.standingMonitorTop, step: .monitor)
            }
        }
        .padding(16)
    }

    private func measurementRow(_ label: String, _ value: Int, step: ErgonomicStep) -> some View {
        let active = step == currentStep
        return HStack {
            Text(label)
            Spacer()
            Text(l10n.centimetres(value))
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.callout)
        .foregroundStyle(active ? Color.accentColor : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            active ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.4)),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                ForEach(ErgonomicStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                        .frame(width: step == currentStep ? 28 : 14, height: 5)
                }
                Spacer()
                Text(l10n.stepCounter(currentStep.rawValue + 1, of: ErgonomicStep.allCases.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(l10n.stepTitle(currentStep))
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                ForEach(l10n.stepInstructions(currentStep), id: \.self) { instruction in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(instruction)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(targets, id: \.label) { target in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(l10n.centimetres(target.value))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button(l10n.previous) { go(to: currentStep.rawValue - 1) }
                    .disabled(currentStep == ErgonomicStep.allCases.first)
                Spacer()
                if currentStep == ErgonomicStep.allCases.last {
                    Button(l10n.finish, action: onFinish)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(l10n.next) { go(to: currentStep.rawValue + 1) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var targets: [(label: String, value: Int)] {
        switch currentStep {
        case .chair:
            [(l10n.seatHeight, measurements.seatHeight)]
        case .sittingDesk:
            [(l10n.deskHeightSitting, measurements.sittingDeskHeight)]
        case .standingDesk:
            [(l10n.deskHeightStanding, measurements.standingDeskHeight)]
        case .monitor:
            [
                (l10n.monitorTopSitting, measurements.sittingMonitorTop),
                (l10n.monitorTopStanding, measurements.standingMonitorTop),
            ]
        }
    }

    private func go(to index: Int) {
        guard let step = ErgonomicStep(rawValue: index) else { return }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
            currentStep = step
        }
    }
}
