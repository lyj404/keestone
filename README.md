[中文](README_ZH.md) | **English**

# KeeStone

[![Release](https://img.shields.io/github/v/release/lyj404/keestone)](https://github.com/lyj404/keestone/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android-lightgrey)]()

A cross-platform KeePass-compatible password manager built with Flutter.

<p align="center">
  <img src="assets/images/screenshot_en.png" width="600" alt="Desktop">
</p>

## Features

- Full KDBX 3.x / 4.x compatibility (read/write, merge sync)
- Cloud sync via WebDAV or Git (GitHub / Gitee / GitLab), TOTP, fingerprint
  unlock, key file dual-factor auth
- CSV / KDBX import & export (Chrome, 1Password, LastPass, Bitwarden, etc.)
- File attachments, entry history, custom fields, tags & groups
- Password generator, auto-lock/save, clipboard auto-clear, expiry reminders
- Local password health audit (weak / reused / expired passwords; no network)
- System tray, keyboard shortcuts, light/dark theme, Chinese/English

## Install

Download version 0.9.6 for your platform:
| Platform | Download |
| --- | --- |
| ![Windows](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white) | ZIP: [![x64](https://img.shields.io/badge/x64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-windows-x64.zip) [![ARM64](https://img.shields.io/badge/ARM64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-windows-arm64.zip)<br>Installer: [![x64](https://img.shields.io/badge/x64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-windows-x64-setup.exe) [![ARM64](https://img.shields.io/badge/ARM64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-windows-arm64-setup.exe) |
| ![Debian%20%2F%20Ubuntu](https://img.shields.io/badge/Debian%20%2F%20Ubuntu-A81D33?style=flat-square&logo=debian&logoColor=white) | [![amd64](https://img.shields.io/badge/amd64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/keestone_0.9.6_amd64.deb) [![arm64](https://img.shields.io/badge/arm64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/keestone_0.9.6_arm64.deb) |
| ![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white) | `yay -S keestone-bin` or `paru -S keestone-bin` |
| ![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white) | [![Apple%20Silicon](https://img.shields.io/badge/Apple%20Silicon-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-macos-arm64.zip) [![Intel](https://img.shields.io/badge/Intel-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-macos-x64.zip) |
| ![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white) | [![arm64--v8a](https://img.shields.io/badge/arm64--v8a-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-android-arm64-v8a.apk) [![armeabi--v7a](https://img.shields.io/badge/armeabi--v7a-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-android-armeabi-v7a.apk) [![x86__64](https://img.shields.io/badge/x86__64-555?style=flat-square)](https://github.com/lyj404/keestone/releases/download/v0.9.6/KeeStone-v0.9.6-android-x86_64.apk) |

macOS builds are provided for Apple Silicon (arm64) and Intel (x64). The author
does not own an Apple device, so macOS builds have limited device testing and
may contain bugs. Bug reports and feedback are welcome via [GitHub Issues](https://github.com/lyj404/keestone/issues).

## Build from Source

Requires Flutter / Dart SDK >= 3.13.0

```bash
git clone https://github.com/lyj404/keestone
cd keestone
flutter pub get
flutter run -d windows    # or linux / macos / android
```

## Tech Stack

[Flutter](https://flutter.dev) · [Riverpod](https://pub.dev/packages/flutter_riverpod) · [go_router](https://pub.dev/packages/go_router) · [kpasslib](https://pub.dev/packages/kpasslib) · [WebDAV](https://pub.dev/packages/webdav_client) · [local_auth](https://pub.dev/packages/local_auth)

## Logs

When reporting a bug, attaching the log file helps a lot. KeeStone records
**warning and error** level messages, rotating at 2 MB per file with 5
generations kept (10 MB total) — the oldest files are removed automatically.

Log files are named `keestone-error.log` (plus older generations
`.1`–`.4`), located at:

| Platform | Location |
| -------- | -------- |
| Windows | `C:\Users\<user>\Documents\KeeStone\logs\`¹ |
| Linux | `~/Documents/KeeStone/logs/` |
| macOS | `~/Library/Containers/com.keestone.keestone/Data/Documents/KeeStone/logs/` (app sandbox) |
| Android | `/storage/emulated/0/Android/data/com.keestone.keestone/files/KeeStone/logs/` |

¹ Follows the system "Documents" known folder, which may differ if it has been
relocated.

On **macOS and Android**, where the path is hard to reach manually, use
**Settings → General → Export Logs** to share the log files via the system
share sheet.

## Password Health

Open **Password Health** from Tools, the overflow menu, or Settings (available on desktop and mobile). The scan is fully local — nothing leaves the device.

| Check | Description |
| ----- | ----------- |
| Empty password | Entry has no password |
| Weak / fair password | Strength score is weak or fair |
| Reused password | The same password is used by two or more entries |
| Expired | Expiry date is in the past |
| Expiring soon | Expires within 7 days |

Results are ranked by severity. Tap a finding to open the entry and fix it. The report never includes plaintext passwords.

## Cloud Sync

KeeStone supports two mutually exclusive sync backends; enabling one disables
the other.

- **WebDAV** — any standards-compliant server (Nextcloud, Jianguoyun, etc.).
- **Git** — stores the database in a private Gist (GitHub / Gitee) or
  Snippet (GitLab, including self-hosted). No repository needed: the first
  sync creates the gist/snippet automatically and later syncs update it.
  Requires a personal access token with gist/snippet write permission.
  Conflict detection works the same as WebDAV: when the remote copy changed
  since the last sync, a diff dialog lets you choose to download the cloud
  version or overwrite it.

## Friendly Links

- [LINUX DO Community](https://linux.do/)

## License

[Apache License 2.0](LICENSE)
