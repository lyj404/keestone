# KeeStone Autofill — iOS Credential Provider Extension

The extension target is already wired into `ios/Runner.xcodeproj` (target
`CredentialProvider`, embedded in Runner, entitlements and Info.plist set up).
The Swift sources, Info.plist, and entitlements live in this directory.

## One-time Xcode/Apple Developer setup (cannot be done from files alone)

1. Open `ios/Runner.xcworkspace` in Xcode and select the **CredentialProvider**
   target. Under **Signing & Capabilities**, pick your development team and let
   Xcode register the `com.keestone.keestone.CredentialProvider` bundle id with
   the App Group / Keychain capabilities (files
   `CredentialProvider.entitlements` / `Runner.entitlements` already declare
   `group.com.keestone.keestone` for both targets).
2. If Xcode complains about the App Group or keychain access group not being
   registered on your Apple Developer account, add
   `group.com.keestone.keestone` there (Identifiers → App Groups).

## Access-group alignment (IMPORTANT)

The AES snapshot key is written to the shared Keychain by the Dart side via
`flutter_secure_storage` with `IOSOptions(groupId: "group.com.keestone.keestone")`,
which sets `kSecAttrAccessGroup` to that literal string. `SnapshotStore.swift`
reads with the same literal. If on device the extension read fails with
`errSecItemNotFound`, the actual stored access group is most likely
team-prefixed (`<TEAMID>group.com.keestone.keestone`). In that case change
`SnapshotStore.appGroupId` (used as `kSecAttrAccessGroup`) **and** the Dart
`_appGroupId` in `lib/features/autofill/services/autofill_snapshot_service.dart`
to the identical prefixed string, and update the App Group id accordingly.
Both sides must use the exact same string.

## URL scheme (already registered)

The `keestone` URL scheme is registered in `Runner/Info.plist`
(`CFBundleURLTypes`). go_router maps `keestone://unlock` to the `/unlock`
route, which falls back to the last-opened vault. The extension calls
`keestone://unlock` when the snapshot is missing.

## Verify

Build to a device, unlock the vault with autofill enabled, then trigger iOS
autofill in Safari on a login page. KeeStone should appear under
Settings → Passwords → Password Options once enabled.
