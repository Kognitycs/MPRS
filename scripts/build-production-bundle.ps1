# Production App Bundle for Google Play (release-signed).
# Requires: android/key.properties + android/app/upload-keystore.jks
# Setup: .\scripts\setup-release-signing.ps1 -StorePassword "YourPassword"

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keyProps = Join-Path $root "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Host "Missing android/key.properties"
    Write-Host "Run: .\scripts\setup-release-signing.ps1 -StorePassword `"YourSecurePassword`""
    exit 1
}

flutter build appbundle --flavor production --release

Write-Host ""
Write-Host "Production AAB: build\app\outputs\bundle\productionRelease\app-production-release.aab"
