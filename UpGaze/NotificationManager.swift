import Foundation
import UserNotifications

enum NotificationAction: String {
    case switchPosture = "SWITCH_POSTURE"
    case snooze = "SNOOZE"
}

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var onAction: ((NotificationAction) -> Void)?

    private static let postureCategory = "POSTURE_DUE"
    private static let postureIdentifier = "posture-due"
    private static let eyeIdentifier = "eye-break"

    private let center = UNUserNotificationCenter.current()
    private var registeredLanguage: L10n.Language?
    private var languageObserver: NSObjectProtocol?

    func configure() {
        center.delegate = self
        registerCategoriesIfNeeded()

        // Action titles are baked into the category, so a language change needs a new registration.
        languageObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.registerCategoriesIfNeeded() }
        }

        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAuthorizationStatus() }
        }
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in self?.authorizationStatus = status }
        }
    }

    func sendPostureDue(current: Posture, minutes: Int) {
        let l10n = L10n.current
        let content = UNMutableNotificationContent()
        content.title = l10n.postureDueTitle(current: current)
        content.body = l10n.postureDueBody(current: current, minutes: minutes)
        content.categoryIdentifier = Self.postureCategory
        deliver(content, identifier: Self.postureIdentifier)
    }

    func sendEyeBreak() {
        let l10n = L10n.current
        let content = UNMutableNotificationContent()
        content.title = l10n.eyeBreakTitle
        content.body = l10n.eyeBreakBody
        deliver(content, identifier: Self.eyeIdentifier)
    }

    func clearPostureDue() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.postureIdentifier])
    }

    func clearEyeBreak() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.eyeIdentifier])
    }

    private func registerCategoriesIfNeeded() {
        let l10n = L10n.current
        guard l10n.language != registeredLanguage else { return }
        registeredLanguage = l10n.language

        let switchAction = UNNotificationAction(
            identifier: NotificationAction.switchPosture.rawValue,
            title: l10n.notificationSwitchAction
        )
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: l10n.notificationSnoozeAction
        )
        let category = UNNotificationCategory(
            identifier: Self.postureCategory,
            actions: [switchAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // Sound is played by TimerManager through NSSound, so it also works when banners are disabled.
    private func deliver(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                NSLog("UpGaze: notification not delivered: %@", error.localizedDescription)
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = NotificationAction(rawValue: response.actionIdentifier)
        Task { @MainActor in
            if let action {
                self.onAction?(action)
            }
        }
        completionHandler()
    }
}
