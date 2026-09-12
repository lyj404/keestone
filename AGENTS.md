<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Commands

- Lint / static analysis: `flutter analyze`
- Tests: `flutter test`
- Regenerate localizations after editing `lib/l10n/*.arb`: `flutter gen-l10n`
- Full check before committing: `flutter analyze && flutter test`

## Upgrade baseline

- Flutter SDK: 3.47.x (Impeller is the default renderer on Windows, Linux, and macOS)
- Dart SDK: 3.13.x
- Android compile/target SDK: Flutter-provided values (currently API 36)
- Android minimum SDK: Flutter-provided value (currently API 24)
- Android project toolchain: AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0
- Android Kotlin: built-in Kotlin enabled (`android.builtInKotlin=true`); app no longer applies `kotlin-android`
- `android.newDsl=false` remains until Flutter fully migrates off legacy AGP DSL types
- Android root `build.gradle.kts` forces plugin `compileSdk = 36` (file_picker et al. still ship android-34)
- `kotlin.incremental=false` is required when pub cache and the project live on different drives
- Android Java compile target: Java 17 (AGP 9 requires JDK 17+; local vfox Java is 17.0.2)
- iOS deployment target: iOS 15
- macOS deployment target: macOS 12
- Material widgets: `material_ui` 1.x

### Pending platform work

- Before adopting Xcode 27/iOS 27, migrate the custom UIKit entry point in `ios/Runner/AppDelegate.swift` to the UIScene lifecycle.
- When Flutter drops legacy DSL support, remove `android.newDsl=false`.
- Validate `flutter build appbundle` with AGP 9.0.1 + Java 17 before release.
