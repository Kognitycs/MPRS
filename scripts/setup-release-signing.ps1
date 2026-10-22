# Creates android/app/upload-keystore.jks and android/key.properties for Play Store release builds.
# Run once, then: flutter build appbundle --flavor production --release
#
# Example:
#   .\scripts\setup-release-signing.ps1 -StorePassword "YourSecurePass123!"

param(
    [Parameter(Mandatory = $true)]
    [string] $StorePassword,

    [string] $KeyPassword = $StorePassword,
    [string] $KeyAlias = "upload",
    [string] $KeystorePath = "android\app\upload-keystore.jks"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keystoreFull = Join-Path $root $KeystorePath
$keyPropsPath = Join-Path $root "android\key.properties"

if (Test-Path $keystoreFull) {
    Write-Host "Keystore already exists: $keystoreFull"
    Write-Host "Delete it first if you want to regenerate."
    exit 1
}

$dname = "CN=MPRS Genie, OU=Mobile, O=MPRS Shipping, L=Mumbai, ST=Maharashtra, C=IN"

Write-Host "Creating release keystore..."
keytool -genkeypair -v `
    -storetype PKCS12 `
    -keystore $keystoreFull `
    -alias $KeyAlias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass $StorePassword `
    -keypass $KeyPassword `
    -dname $dname

$storeFileRelative = "upload-keystore.jks"
$content = @"
storePassword=$StorePassword
keyPassword=$KeyPassword
keyAlias=$KeyAlias
storeFile=$storeFileRelative
"@

# UTF-8 without BOM — Gradle/Java Properties fail on BOM-prefixed keys.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($keyPropsPath, $content, $utf8NoBom)
Write-Host ""
Write-Host "Created:"
Write-Host "  Keystore:     $keystoreFull"
Write-Host "  key.properties: $keyPropsPath"
Write-Host ""
Write-Host "Next: add upload certificate SHA-1/SHA-256 to Firebase Console, then:"
Write-Host "  flutter build appbundle --flavor production --release"
Write-Host ""
Write-Host "IMPORTANT: Back up the keystore and passwords. You need them for all future Play updates."
