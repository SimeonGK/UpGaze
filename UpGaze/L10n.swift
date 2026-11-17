import SwiftUI

/// The user's language choice as stored in `UserDefaults`.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case nl
    case en

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Systeem / System"
        case .nl: "Nederlands"
        case .en: "English"
        }
    }
}

/// All user-facing text, in Dutch and English.
///
/// Views read it through `@Localized`, which re-renders them when the language setting changes.
/// Code outside SwiftUI uses `L10n.current`.
struct L10n: Equatable, Sendable {
    enum Language: String, Sendable {
        case dutch = "nl"
        case english = "en"
    }

    static let storageKey = "appLanguage"

    /// Dutch when the first preferred system language is Dutch, English for everything else.
    static let systemLanguage: Language = {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("nl") ? .dutch : .english
    }()

    static var current: L10n {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return L10n(setting: AppLanguage(rawValue: stored) ?? .system)
    }

    let language: Language

    init(language: Language) {
        self.language = language
    }

    init(setting: AppLanguage) {
        switch setting {
        case .system: language = Self.systemLanguage
        case .nl: language = .dutch
        case .en: language = .english
        }
    }

    private func tr(_ dutch: String, _ english: String) -> String {
        language == .dutch ? dutch : english
    }

    // MARK: - Shared

    var languagePickerLabel: String { "Language / Taal" }
    var sitting: String { tr("Zitten", "Sitting") }
    var standing: String { tr("Staan", "Standing") }
    var setUpWorkstation: String { tr("Werkplek instellen", "Set up workstation") }

    func postureName(_ posture: Posture) -> String {
        posture == .sitting ? sitting : standing
    }

    func centimetres(_ value: Int) -> String { "\(value) cm" }
    func minutes(_ value: Int) -> String { "\(value) min" }
    func seconds(_ value: Int) -> String { "\(value) s" }

    // MARK: - Menu bar

    func menuBarMinutes(_ value: Int) -> String { "\(value)m" }
    func menuBarSeconds(_ value: Int) -> String { "\(value)s" }

    func menuBarPostureStatus(_ posture: Posture, minutesLeft: Int) -> String {
        tr(
            "\(postureName(posture)), nog \(minutesLeft) minuten",
            "\(postureName(posture)), \(minutesLeft) minutes left"
        )
    }

    func menuBarPausedStatus(_ posture: Posture, minutesLeft: Int) -> String {
        tr(
            "Gepauzeerd: \(postureName(posture).lowercased()), nog \(minutesLeft) minuten",
            "Paused: \(postureName(posture).lowercased()), \(minutesLeft) minutes left"
        )
    }

    func menuBarEyeBreakStatus(secondsLeft: Int) -> String {
        tr("Oogpauze, nog \(secondsLeft) seconden", "Eye break, \(secondsLeft) seconds left")
    }

    // MARK: - Popover

    var timerTab: String { "Timer" }
    var settingsTab: String { tr("Instellingen", "Settings") }
    var viewPicker: String { tr("Weergave", "View") }
    var quit: String { tr("Stop UpGaze", "Quit UpGaze") }
    var switchNow: String { tr("Nu wisselen", "Switch now") }
    var pause: String { tr("Pauzeren", "Pause") }
    var resume: String { tr("Hervatten", "Resume") }
    var snoozeFiveMinutes: String { "+5 min" }
    var snoozeHelp: String { tr("Stel het wisselen 5 minuten uit", "Postpone switching by 5 minutes") }
    var paused: String { tr("Gepauzeerd", "Paused") }
    var timeToStand: String { tr("Tijd om te staan", "Time to stand") }
    var timeToSit: String { tr("Tijd om te zitten", "Time to sit") }
    var untilStanding: String { tr("tot je gaat staan", "until you stand") }
    var untilSitting: String { tr("tot je gaat zitten", "until you sit") }
    var lookFarAway: String { tr("Kijk 6 meter ver weg", "Look 6 m (20 ft) away") }
    var relaxYourEyes: String {
        tr("Ontspan je ogen tot de teller op nul staat.", "Relax your eyes until the counter reaches zero.")
    }
    var skip: String { tr("Overslaan", "Skip") }
    var nextEyeBreak: String { tr("Volgende oogpauze", "Next eye break") }

    // MARK: - Notifications

    var notificationSwitchAction: String { tr("Wissel houding", "Switch posture") }
    var notificationSnoozeAction: String { "Snooze 5 min" }
    var eyeBreakTitle: String { tr("Oogpauze", "Eye break") }
    var eyeBreakBody: String {
        tr(
            "Kijk 20 seconden naar iets op minstens 6 meter afstand.",
            "Look at something at least 6 metres (20 feet) away for 20 seconds."
        )
    }

    /// Title for the notification that ends a period in `current` posture.
    func postureDueTitle(current: Posture) -> String {
        current == .sitting ? timeToStand : timeToSit
    }

    func postureDueBody(current: Posture, minutes: Int) -> String {
        switch current {
        case .sitting:
            tr(
                "Je zit al \(minutes) minuten. Zet je bureau omhoog en ga even staan.",
                "You've been sitting for \(minutes) minutes. Raise your desk and stand for a while."
            )
        case .standing:
            tr(
                "Je staat al \(minutes) minuten. Je mag weer gaan zitten.",
                "You've been standing for \(minutes) minutes. You can sit down again."
            )
        }
    }

    // MARK: - Settings

    var postureSection: String { tr("Houding", "Posture") }
    var eyesSection: String { tr("Ogen", "Eyes") }
    var generalSection: String { tr("Algemeen", "General") }
    var eyeRule: String { tr("20-20-20-regel", "20-20-20 rule") }
    var eyeRuleDescription: String {
        tr(
            "Elke 20 minuten 20 seconden naar 6 meter afstand kijken",
            "Every 20 minutes, look 6 metres (20 feet) away for 20 seconds"
        )
    }
    var soundEffects: String { tr("Geluidseffecten", "Sound effects") }
    var launchAtLogin: String { tr("Start bij inloggen", "Launch at login") }
    var setUpWorkstationEllipsis: String { tr("Werkplek instellen…", "Set up workstation…") }
    var notificationsOff: String { tr("Meldingen staan uit", "Notifications are off") }
    var notificationsOffDescription: String {
        tr(
            "Zet meldingen voor UpGaze aan om een seintje te krijgen wanneer het tijd is om te wisselen.",
            "Turn on notifications for UpGaze to get a nudge when it's time to switch."
        )
    }
    var openSystemSettings: String { tr("Open Systeeminstellingen", "Open System Settings") }

    func launchAtLoginFailed(_ reason: String) -> String {
        tr("Kon 'Start bij inloggen' niet wijzigen: \(reason)", "Couldn't change launch at login: \(reason)")
    }

    // MARK: - Updates

    var updatesSection: String { "Updates" }
    var checkForUpdates: String { tr("Controleer op updates", "Check for Updates") }
    var checkingForUpdates: String { tr("Controleren…", "Checking…") }
    var upToDate: String { tr("Je hebt de nieuwste versie.", "You're up to date.") }
    var openDownload: String { tr("Open download", "Open Download") }
    var updateCheckFailed: String {
        tr(
            "Controleren op updates is mislukt. Probeer het later opnieuw.",
            "Couldn't check for updates. Try again later."
        )
    }

    func currentVersion(_ version: String) -> String {
        tr("Versie \(version)", "Version \(version)")
    }

    func updateAvailable(_ version: String) -> String {
        tr("Versie \(version) is beschikbaar.", "Version \(version) is available.")
    }

    // MARK: - Workstation setup

    var setupWindowTitle: String { tr("Werkplek instellen", "Workstation setup") }
    var yourHeight: String { tr("Je lengte", "Your height") }
    var heightField: String { tr("Lengte", "Height") }
    var heightAccessibility: String { tr("Lengte in centimeters", "Height in centimetres") }
    var centimetreUnit: String { "cm" }
    var seatHeight: String { tr("Zithoogte stoel", "Chair seat height") }
    var deskHeightSittingRow: String { tr("Bureauhoogte (zittend)", "Desk height (sitting)") }
    var deskHeightStandingRow: String { tr("Bureauhoogte (staand)", "Desk height (standing)") }
    var monitorTopSittingRow: String { tr("Bovenrand beeldscherm (zittend)", "Monitor top edge (sitting)") }
    var monitorTopStandingRow: String { tr("Bovenrand beeldscherm (staand)", "Monitor top edge (standing)") }
    var deskHeightSitting: String { tr("Bureauhoogte zittend", "Desk height, sitting") }
    var deskHeightStanding: String { tr("Bureauhoogte staand", "Desk height, standing") }
    var monitorTopSitting: String { tr("Bovenrand zittend", "Top edge, sitting") }
    var monitorTopStanding: String { tr("Bovenrand staand", "Top edge, standing") }
    var previous: String { tr("Vorige", "Back") }
    var next: String { tr("Volgende", "Next") }
    var finish: String { tr("Afronden", "Finish") }

    func stepCounter(_ step: Int, of total: Int) -> String {
        tr("Stap \(step) van \(total)", "Step \(step) of \(total)")
    }

    func stepTitle(_ step: ErgonomicStep) -> String {
        switch step {
        case .chair: tr("Bureaustoel & onderrug", "Office chair & lower back")
        case .sittingDesk: tr("Bureauhoogte zittend", "Desk height, sitting")
        case .standingDesk: tr("Bureauhoogte staand", "Desk height, standing")
        case .monitor: tr("Beeldscherm & ogen", "Monitor & eyes")
        }
    }

    func stepInstructions(_ step: ErgonomicStep) -> [String] {
        switch step {
        case .chair:
            [
                tr(
                    "Zet beide voeten plat op de grond, met je knieën in een hoek van 90°–100°.",
                    "Place both feet flat on the floor, with your knees at an angle of 90°–100°."
                ),
                tr(
                    "Houd 2–3 vingers ruimte tussen de rand van de zitting en je knieholtes.",
                    "Leave 2–3 fingers of space between the edge of the seat and the back of your knees."
                ),
                tr(
                    "Stel de lendensteun zo in dat hij de holte van je onderrug vult.",
                    "Adjust the lumbar support so it fills the curve of your lower back."
                ),
                tr(
                    "Kantel de rugleuning licht naar achteren (100°–110°). Dat haalt druk van je onderrug.",
                    "Recline the backrest slightly (100°–110°). This takes pressure off your lower back."
                ),
            ]
        case .sittingDesk:
            [
                tr(
                    "Laat je schouders ontspannen hangen en trek ze niet op.",
                    "Let your shoulders hang relaxed and don't shrug them."
                ),
                tr(
                    "Buig je ellebogen 90° en houd ze dicht bij je lichaam.",
                    "Bend your elbows to 90° and keep them close to your body."
                ),
                tr(
                    "Laat je onderarmen licht op het bureaublad rusten, met rechte polsen.",
                    "Rest your forearms lightly on the desk, with straight wrists."
                ),
            ]
        case .standingDesk:
            [
                tr(
                    "Sta rechtop en verdeel je gewicht gelijk over beide voeten.",
                    "Stand upright with your weight evenly on both feet."
                ),
                tr(
                    "Houd je knieën losjes en zet ze niet op slot.",
                    "Keep your knees loose and don't lock them."
                ),
                tr(
                    "Zet het bureau zo hoog dat je ellebogen weer 90° gebogen zijn.",
                    "Raise the desk until your elbows are bent at 90° again."
                ),
            ]
        case .monitor:
            [
                tr(
                    "Zet de bovenrand van je beeldscherm op ooghoogte.",
                    "Set the top edge of your monitor at eye level."
                ),
                tr(
                    "Plaats het scherm op ongeveer een armlengte afstand (50–70 cm).",
                    "Place the screen about an arm's length away (50–70 cm)."
                ),
                tr(
                    "Zo blijft je nek recht en zak je niet onderuit, wat ook je onderrug ontziet.",
                    "This keeps your neck straight and stops you slouching, which also spares your lower back."
                ),
            ]
        }
    }

    // MARK: - Workstation animation

    var replayAnimation: String { tr("Speel animatie opnieuw", "Replay animation") }
    var posturePreview: String { tr("Zit / Sta preview", "Sit / stand preview") }
    var showSittingPosture: String { tr("Toon de zithouding", "Show the sitting posture") }
    var showStandingPosture: String { tr("Toon de stahouding", "Show the standing posture") }
    var armsLength: String { tr("1 armlengte (50–70 cm)", "1 arm's length (50–70 cm)") }

    func sceneAccessibility(_ stepTitle: String) -> String {
        tr("Illustratie van de werkplek: \(stepTitle)", "Illustration of the workstation: \(stepTitle)")
    }
}

/// Gives a view the strings for the current language and re-renders it when the setting changes.
@propertyWrapper
struct Localized: DynamicProperty {
    @AppStorage(L10n.storageKey) private var setting: AppLanguage = .system

    var wrappedValue: L10n {
        L10n(setting: setting)
    }
}
