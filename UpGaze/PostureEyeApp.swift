import AppKit
import SwiftUI

@main
struct UpGazeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var timers = TimerManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(timers)
        } label: {
            MenuBarLabel(timers: timers)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationManager.shared.configure()
        TimerManager.shared.start()
        if !UserDefaults.standard.bool(forKey: SettingsKey.hasCompletedSetup) {
            SetupWindowController.shared.show()
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var timers: TimerManager
    @Localized private var l10n

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .help(status)
        .accessibilityLabel(status)
    }

    private var symbol: String {
        if timers.isEyeBreak { return "eye" }
        if timers.isPaused { return "pause.fill" }
        return timers.posture.symbol
    }

    private var text: String {
        if timers.isEyeBreak { return l10n.menuBarSeconds(timers.eyeSecondsLeft) }
        return l10n.menuBarMinutes(timers.postureMinutesLeft)
    }

    private var status: String {
        if timers.isEyeBreak {
            return l10n.menuBarEyeBreakStatus(secondsLeft: timers.eyeSecondsLeft)
        }
        if timers.isPaused {
            return l10n.menuBarPausedStatus(timers.posture, minutesLeft: timers.postureMinutesLeft)
        }
        return l10n.menuBarPostureStatus(timers.posture, minutesLeft: timers.postureMinutesLeft)
    }
}
