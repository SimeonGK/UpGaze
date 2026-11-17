# UpGaze

A small, free macOS menu bar app that helps prevent lower back pain and eye strain. It alternates
sitting and standing on a timer and reminds you of the 20-20-20 rule: every 20 minutes, look at
something 6 metres (20 feet) away for 20 seconds.

## [Download UpGaze.dmg](https://github.com/SimeonGK/UpGaze/releases/latest/download/UpGaze.dmg)

Requires macOS 14 or later. Runs on Apple silicon and Intel Macs.

## Opening UpGaze for the first time

UpGaze is not signed with a paid Apple developer certificate, so macOS asks you to confirm once
that you trust it.

1. Open `UpGaze.dmg`, drag **UpGaze** to **Applications**, and try to open it once. macOS shows a
   warning and does not open the app. Click **Done**.
2. Open **System Settings → Privacy & Security** and scroll down to the **Security** section.
3. Next to the message about UpGaze, click **Open Anyway** and confirm.

After that UpGaze opens normally. It lives in the menu bar only; there is no Dock icon.

## Features

- **Sit / stand timer.** 40 minutes sitting and 15 minutes standing by default, both adjustable.
  The menu bar shows the current posture and the minutes left, for example `38m`. Switch now,
  pause, or snooze 5 minutes from the popover or straight from the notification.
- **20-20-20 eye rule.** Every 20 minutes a gentle reminder, then a 20-second countdown in the
  menu bar and the popover, with a sound at the start and the end.
- **Workstation setup.** Enter your height and get personal target heights for your chair, desk
  (sitting and standing) and monitor, explained in four steps with an animated illustration.
- **Dutch and English.** Follows the macOS system language; can be switched in Settings without
  a restart.
- **Pauses when you are away.** Both timers pause when the screen locks or the Mac sleeps, and
  resume on unlock.
- **Launch at login**, optional.
- **Update check.** Settings has a button that compares your version with the latest release.

## Building from source

You need Xcode 16 or later.

```bash
git clone https://github.com/SimeonGK/UpGaze.git
```

```bash
open UpGaze/UpGaze.xcodeproj
```

Press **Run** (`Cmd + R`). The project signs ad hoc ("Sign to Run Locally"), so no Apple developer
account is needed. Launch at login works reliably only when the app is in `/Applications`.

## Releasing

Pushing a version tag such as `v1.0.0` builds a universal app, packages it as `UpGaze.dmg` and
publishes a GitHub release with it and its SHA-256 checksum. The app's version is taken from the
tag. A tag with a suffix, such as `v1.1.0-beta`, is published as a pre-release and is not offered
by the download link or the in-app update check.

```bash
git tag v1.0.0
```

```bash
git push origin v1.0.0
```

## Project layout

| File | Purpose |
| --- | --- |
| `UpGaze/PostureEyeApp.swift` | App entry point, `MenuBarExtra` scene and menu bar label |
| `UpGaze/TimerManager.swift` | Posture and eye timers, lock and sleep handling, sounds |
| `UpGaze/NotificationManager.swift` | Notification permission, delivery and action handling |
| `UpGaze/MenuBarPopoverView.swift` | Popover with the timer view |
| `UpGaze/SettingsView.swift` | Settings tab |
| `UpGaze/ErgonomicSetupView.swift` | Workstation setup wizard, its window and the height calculations |
| `UpGaze/ErgonomicAnimationView.swift` | Illustration shown next to the wizard steps |
| `UpGaze/L10n.swift` | All user-facing text in Dutch and English, and the language setting |
| `UpGaze/UpdateChecker.swift` | Compares the app version with the latest GitHub release |
| `.github/workflows/release.yml` | Builds and publishes `UpGaze.dmg` for every `v*` tag |

## Privacy

UpGaze collects nothing. The only network request it makes is to the GitHub API, and only when
you click **Check for Updates**.

## License

MIT, see [LICENSE](LICENSE).
