import AppKit
import Combine
import Foundation

enum SettingsKey {
    static let sitMinutes = "sitMinutes"
    static let standMinutes = "standMinutes"
    static let eyeEnabled = "eyeEnabled"
    static let soundEnabled = "soundEnabled"
    static let userHeightCm = "userHeightCm"
    static let hasCompletedSetup = "hasCompletedSetup"

    static let defaults: [String: any Sendable] = [
        sitMinutes: 40,
        standMinutes: 15,
        eyeEnabled: true,
        soundEnabled: true,
    ]
}

enum Posture: String {
    case sitting
    case standing

    var symbol: String {
        switch self {
        case .sitting: "figure.seated.side"
        case .standing: "figure.stand"
        }
    }

    var next: Posture {
        self == .sitting ? .standing : .sitting
    }
}

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    static let snoozeSeconds: TimeInterval = 5 * 60
    static let eyeIntervalSeconds: TimeInterval = 20 * 60
    static let eyeBreakSeconds: TimeInterval = 20

    @Published private(set) var posture: Posture = .sitting
    @Published private(set) var postureSecondsLeft = 0
    @Published private(set) var postureTotalSeconds = 1
    @Published private(set) var isPaused = false
    @Published private(set) var isSuspended = false
    @Published private(set) var isEyeBreak = false
    @Published private(set) var eyeSecondsLeft = Int(TimerManager.eyeIntervalSeconds)
    @Published private(set) var eyeEnabled = true

    var isPostureDue: Bool { postureSecondsLeft == 0 }

    var postureMinutesLeft: Int { (postureSecondsLeft + 59) / 60 }

    var postureProgress: Double {
        1 - Double(postureSecondsLeft) / Double(max(postureTotalSeconds, 1))
    }

    var eyeBreakProgress: Double {
        guard isEyeBreak else { return 0 }
        return 1 - Double(eyeSecondsLeft) / Self.eyeBreakSeconds
    }

    private enum SuspendReason {
        case locked
        case asleep
    }

    private let defaults = UserDefaults.standard
    private let notifications = NotificationManager.shared

    private var postureElapsed: TimeInterval = 0
    private var snoozeExtra: TimeInterval = 0
    private var postureDueHandled = false
    private var eyeElapsed: TimeInterval = 0
    private var suspendReasons: Set<SuspendReason> = []
    private var lastTick: TimeInterval = 0
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var activity: NSObjectProtocol?

    private init() {
        defaults.register(defaults: SettingsKey.defaults)
        eyeEnabled = defaults.bool(forKey: SettingsKey.eyeEnabled)
        publish()
    }

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }

        notifications.onAction = { [weak self] action in
            switch action {
            case .switchPosture: self?.switchPosture()
            case .snooze: self?.snooze()
            }
        }

        // App Nap would otherwise defer the timer by tens of seconds while the popover is closed.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Posture and eye timers"
        )

        observeSystemEvents()

        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        // .common keeps the countdown running while a menu or the popover is tracking events.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeSystemEvents() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter

        func observe(
            _ center: NotificationCenter,
            _ name: Notification.Name,
            _ handler: @escaping @MainActor @Sendable (TimerManager) -> Void
        ) {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handler(self)
                }
            }
            observers.append(token)
        }

        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.setSuspended(.locked, true) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.setSuspended(.locked, false) }
        observe(workspace, NSWorkspace.willSleepNotification) { $0.setSuspended(.asleep, true) }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.setSuspended(.asleep, false) }
        observe(.default, UserDefaults.didChangeNotification) { $0.applySettings() }
    }

    // MARK: - User actions

    func switchPosture() {
        posture = posture.next
        postureElapsed = 0
        snoozeExtra = 0
        postureDueHandled = false
        isPaused = false
        notifications.clearPostureDue()
        publish()
    }

    func snooze() {
        snoozeExtra += Self.snoozeSeconds
        postureDueHandled = false
        notifications.clearPostureDue()
        publish()
    }

    func togglePause() {
        isPaused.toggle()
    }

    func skipEyeBreak() {
        guard isEyeBreak else { return }
        finishEyeBreak(playSound: false)
        publish()
    }

    // MARK: - Ticking

    private var postureTotal: TimeInterval {
        let key = posture == .sitting ? SettingsKey.sitMinutes : SettingsKey.standMinutes
        let minutes = min(max(defaults.integer(forKey: key), 1), 240)
        return TimeInterval(minutes * 60) + snoozeExtra
    }

    private var soundEnabled: Bool {
        defaults.bool(forKey: SettingsKey.soundEnabled)
    }

    private func tick() {
        // systemUptime stands still during sleep, so time asleep is never counted.
        let now = ProcessInfo.processInfo.systemUptime
        let delta = max(now - lastTick, 0)
        lastTick = now

        guard !isPaused, !isSuspended else { return }

        if !postureDueHandled {
            postureElapsed += delta
            if postureElapsed >= postureTotal {
                postureElapsed = postureTotal
                postureDueHandled = true
                notifications.sendPostureDue(current: posture, minutes: Int(postureTotal / 60))
                play("Hero")
            }
        }

        if eyeEnabled {
            eyeElapsed += delta
            if isEyeBreak {
                if eyeElapsed >= Self.eyeBreakSeconds {
                    finishEyeBreak(playSound: true)
                }
            } else if eyeElapsed >= Self.eyeIntervalSeconds {
                eyeElapsed = 0
                isEyeBreak = true
                notifications.sendEyeBreak()
                play("Tink")
            }
        }

        publish()
    }

    private func finishEyeBreak(playSound: Bool) {
        eyeElapsed = 0
        isEyeBreak = false
        notifications.clearEyeBreak()
        if playSound { play("Glass") }
    }

    private func applySettings() {
        let enabled = defaults.bool(forKey: SettingsKey.eyeEnabled)
        if enabled != eyeEnabled {
            eyeEnabled = enabled
            eyeElapsed = 0
            if isEyeBreak {
                isEyeBreak = false
                notifications.clearEyeBreak()
            }
        }
        if postureElapsed < postureTotal {
            postureDueHandled = false
        }
        publish()
    }

    private func setSuspended(_ reason: SuspendReason, _ active: Bool) {
        if active {
            suspendReasons.insert(reason)
        } else {
            suspendReasons.remove(reason)
        }
        let suspended = !suspendReasons.isEmpty
        if suspended != isSuspended {
            isSuspended = suspended
        }
    }

    /// Assigns only on change: every @Published write re-renders the menu bar label.
    private func publish() {
        let total = Int(postureTotal.rounded())
        let left = max(Int((postureTotal - postureElapsed).rounded(.up)), 0)
        let eyeTotal = isEyeBreak ? Self.eyeBreakSeconds : Self.eyeIntervalSeconds
        let eyeLeft = max(Int((eyeTotal - eyeElapsed).rounded(.up)), 0)

        if postureTotalSeconds != total { postureTotalSeconds = total }
        if postureSecondsLeft != left { postureSecondsLeft = left }
        if eyeSecondsLeft != eyeLeft { eyeSecondsLeft = eyeLeft }
    }

    private func play(_ name: String) {
        guard soundEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
