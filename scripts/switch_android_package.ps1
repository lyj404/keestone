# Switch Android applicationId + launcher label for side-by-side test installs.
# Does NOT touch pubspec name, namespace, or Kotlin packages.
#
# Usage (from repo root):
#   powershell -File scripts/switch_android_package.ps1 -Mode prod
#   powershell -File scripts/switch_android_package.ps1 -Mode test
#   powershell -File scripts/switch_android_package.ps1 -Mode status
#
# After -Mode test:
#   flutter clean && flutter pub get
#   flutter build apk --debug
#   # or: flutter run
# Then install build\app\outputs\flutter-apk\app-debug.apk (signed). Release
# APKs are unsigned unless android/key.properties is configured.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('prod', 'test', 'status')]
    [string]$Mode,

    # Optional suffix when using -Mode test (default: .test)
    [string]$TestSuffix = '.test'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
    $root = Get-Location
}

$gradlePath = Join-Path $root 'android/app/build.gradle.kts'
$manifestPath = Join-Path $root 'android/app/src/main/AndroidManifest.xml'

function Read-Text([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Missing file: $Path" }
    return [System.IO.File]::ReadAllText($Path)
}

function Write-Text([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content)
}

function Get-CurrentApplicationId([string]$GradleText) {
    if ($GradleText -match 'applicationId\s*=\s*"([^"]+)"') {
        return $Matches[1]
    }
    return $null
}

function Get-CurrentLabel([string]$ManifestText) {
    if ($ManifestText -match 'android:label="([^"]+)"') {
        return $Matches[1]
    }
    return $null
}

function Set-ApplicationId([string]$GradleText, [string]$NewId) {
    $updated = [regex]::Replace(
        $GradleText,
        'applicationId\s*=\s*"[^"]+"',
        "applicationId = `"$NewId`"",
        1
    )
    if ($updated -eq $GradleText) {
        throw 'applicationId assignment not found in build.gradle.kts'
    }
    return $updated
}

function Set-Label([string]$ManifestText, [string]$NewLabel) {
    $updated = [regex]::Replace(
        $ManifestText,
        'android:label="[^"]+"',
        "android:label=`"$NewLabel`"",
        1
    )
    if ($updated -eq $ManifestText) {
        throw 'android:label not found in AndroidManifest.xml'
    }
    return $updated
}

$gradle = Read-Text $gradlePath
$manifest = Read-Text $manifestPath
$prodId = 'com.keestone.keestone'
$prodLabel = 'keestone'
$testId = "$prodId$TestSuffix"
$testLabel = "keestone$TestSuffix"

switch ($Mode) {
    'status' {
        Write-Host "applicationId: $(Get-CurrentApplicationId $gradle)"
        Write-Host "label:         $(Get-CurrentLabel $manifest)"
        Write-Host "pubspec name:  $((Get-Content (Join-Path $root 'pubspec.yaml') | Select-String '^name:').Line)"
        exit 0
    }
    'prod' {
        $newId = $prodId
        $newLabel = $prodLabel
    }
    'test' {
        $newId = $testId
        $newLabel = $testLabel
    }
}

Write-Host "Switching to $Mode"
Write-Host "  applicationId -> $newId"
Write-Host "  label         -> $newLabel"

Write-Text $gradlePath (Set-ApplicationId $gradle $newId)
Write-Text $manifestPath (Set-Label $manifest $newLabel)

Write-Host 'Done. Next:'
Write-Host '  flutter clean && flutter pub get'
Write-Host '  flutter build apk --debug'
Write-Host '  # install build\app\outputs\flutter-apk\app-debug.apk'
Write-Host 'Note: use Debug APK for side-by-side install; release is unsigned without key.properties.'
