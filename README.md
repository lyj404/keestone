[中文](README_ZH.md) | **English**

# KeeStone

[![Release](https://img.shields.io/github/v/release/lyj404/keestone)](https://github.com/lyj404/keestone/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20Android-lightgrey)]()

A cross-platform KeePass-compatible password manager built with Flutter.

<p align="center">
  <img src="assets/images/screenshot_en.png" width="600" alt="Desktop">
</p>

## Features

- Full KDBX 3.x / 4.x compatibility (read/write, merge sync)
- WebDAV cloud sync, TOTP, fingerprint unlock, key file dual-factor auth
- CSV / KDBX import & export (Chrome, 1Password, LastPass, Bitwarden, etc.)
- File attachments, entry history, custom fields, tags & groups
- Password generator, auto-lock/save, clipboard auto-clear, expiry reminders
- System tray, keyboard shortcuts, light/dark theme, Chinese/English

## Install

Download from [Releases](https://github.com/lyj404/keestone/releases).

| Platform        | Notes                                                                  |
| --------------- | ---------------------------------------------------------------------- |
| Windows         | Download `KeeStone-*-windows-x64.zip`, extract and run `keestone.exe`  |
| Debian / Ubuntu | `sudo apt install ./keestone_*_amd64.deb`                              |
| Arch Linux      | `yay -S keestone-bin` or `paru -S keestone-bin`                        |
| Android         | Install the APK for your arch (`arm64-v8a` / `armeabi-v7a` / `x86_64`). APKs are not distributed via any app store — download them only from GitHub Releases |

## Build from Source

Requires Flutter / Dart SDK >= 3.13.0

```bash
git clone https://github.com/lyj404/keestone
cd keestone
flutter pub get
flutter run -d windows    # or linux / android
```

## Tech Stack

[Flutter](https://flutter.dev) · [Riverpod](https://pub.dev/packages/flutter_riverpod) · [go_router](https://pub.dev/packages/go_router) · [kpasslib](https://pub.dev/packages/kpasslib) · [WebDAV](https://pub.dev/packages/webdav_client) · [local_auth](https://pub.dev/packages/local_auth)

## Friendly Links

- [LINUX DO Community](https://linux.do/)

## License

[Apache License 2.0](LICENSE)
