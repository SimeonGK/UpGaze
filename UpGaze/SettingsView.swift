import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.sitMinutes) private var sitMinutes = 40
    @AppStorage(SettingsKey.standMinutes) private var standMinutes = 15
    @AppStorage(SettingsKey.eyeEnabled) private var eyeEnabled = true
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = true
    @AppStorage(L10n.storageKey) private var appLanguage: AppLanguage = .system

    @Localized private var l10n
    @ObservedObject private var notifications = NotificationManager.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginFailure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(l10n.postureSection) {
                Stepper(value: $sitMinutes, in: 5...180, step: 5) {
                    row(l10n.sitting, systemImage: "figure.seated.side", value: l10n.minutes(sitMinutes))
                }
                Stepper(value: $standMinutes, in: 5...120, step: 5) {
                    row(l10n.standing, systemImage: "figure.stand", value: l10n.minutes(standMinutes))
                }
            }

            section(l10n.eyesSection) {
                Toggle(isOn: $eyeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.eyeRule)
                        Text(l10n.eyeRuleDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            section(l10n.generalSection) {
                Toggle(l10n.soundEffects, isOn: $soundEnabled)
                Toggle(l10n.launchAtLogin, isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
                if let launchAtLoginFailure {
                    Text(l10n.launchAtLoginFailed(launchAtLoginFailure))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Picker(l10n.languagePickerLabel, selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Button(l10n.setUpWorkstationEllipsis) {
                    SetupWindowController.shared.show()
                }
            }

            section(l10n.updatesSection) {
                HStack {
                    Text(l10n.currentVersion(updates.currentVersion))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(updates.status == .checking ? l10n.checkingForUpdates : l10n.checkForUpdates) {
                        updates.check()
                    }
                    .disabled(updates.status == .checking)
                }
                updateStatus
            }

            if notifications.authorizationStatus == .denied {
                VStack(alignment: .leading, spacing: 6) {
                    Label(l10n.notificationsOff, systemImage: "bell.slash")
                        .font(.callout.weight(.medium))
                    Text(l10n.notificationsOffDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(l10n.openSystemSettings) {
                        openNotificationSettings()
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            notifications.refreshAuthorizationStatus()
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updates.status {
        case .idle, .checking:
            EmptyView()
        case .upToDate:
            Label(l10n.upToDate, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .updateAvailable(let version):
            HStack {
                Label(l10n.updateAvailable(version), systemImage: "arrow.down.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button(l10n.openDownload) {
                    updates.openDownload()
                }
                .buttonStyle(.borderedProminent)
            }
        case .failed:
            Label(l10n.updateCheckFailed, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func row(_ title: String, systemImage: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginFailure = nil
        } catch {
            launchAtLoginFailure = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
