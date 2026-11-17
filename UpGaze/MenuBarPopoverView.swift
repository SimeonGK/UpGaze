import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    private enum Tab: CaseIterable, Identifiable {
        case timer
        case settings

        var id: Self { self }
    }

    @EnvironmentObject private var timers: TimerManager
    @Localized private var l10n
    @State private var tab: Tab = .timer

    var body: some View {
        VStack(spacing: 14) {
            Picker(l10n.viewPicker, selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab == .timer ? l10n.timerTab : l10n.settingsTab).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .timer:
                PostureCard()
                if timers.eyeEnabled {
                    EyeCard()
                }
            case .settings:
                SettingsView()
            }

            Divider()

            HStack {
                Button(l10n.setUpWorkstation) {
                    SetupWindowController.shared.show()
                }
                .buttonStyle(.link)
                .font(.caption)
                Spacer()
                Button(l10n.quit) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

private struct PostureCard: View {
    @EnvironmentObject private var timers: TimerManager
    @Localized private var l10n

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: timers.postureProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: timers.postureProgress)

                VStack(spacing: 2) {
                    Image(systemName: timers.posture.symbol)
                        .font(.title2)
                        .foregroundStyle(tint)
                    Text(l10n.postureName(timers.posture))
                        .font(.headline)
                    Text(clock(timers.postureSecondsLeft))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            .padding(.top, 4)

            Button {
                timers.switchPosture()
            } label: {
                Label(l10n.switchNow, systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 8) {
                Button {
                    timers.togglePause()
                } label: {
                    Label(
                        timers.isPaused ? l10n.resume : l10n.pause,
                        systemImage: timers.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }

                Button {
                    timers.snooze()
                } label: {
                    Label(l10n.snoozeFiveMinutes, systemImage: "moon.zzz")
                        .frame(maxWidth: .infinity)
                }
                .help(l10n.snoozeHelp)
            }
            .controlSize(.large)
        }
    }

    private var tint: Color {
        timers.posture == .sitting ? .blue : .green
    }

    private var statusText: String {
        if timers.isPaused { return l10n.paused }
        if timers.isPostureDue {
            return timers.posture == .sitting ? l10n.timeToStand : l10n.timeToSit
        }
        return timers.posture == .sitting ? l10n.untilStanding : l10n.untilSitting
    }
}

private struct EyeCard: View {
    @EnvironmentObject private var timers: TimerManager
    @Localized private var l10n

    var body: some View {
        Group {
            if timers.isEyeBreak {
                VStack(spacing: 8) {
                    HStack {
                        Label(l10n.lookFarAway, systemImage: "eye")
                            .font(.headline)
                        Spacer()
                        Text(l10n.seconds(timers.eyeSecondsLeft))
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    ProgressView(value: timers.eyeBreakProgress)
                        .animation(.linear(duration: 0.3), value: timers.eyeBreakProgress)
                    HStack {
                        Text(l10n.relaxYourEyes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(l10n.skip) {
                            timers.skipEyeBreak()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            } else {
                HStack {
                    Label(l10n.nextEyeBreak, systemImage: "eye")
                    Spacer()
                    Text(clock(timers.eyeSecondsLeft))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private func clock(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
