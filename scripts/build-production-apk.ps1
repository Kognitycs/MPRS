# Build the production APK.
# App label: MPRS Genie
# Package:   com.mobile.mprs_android
# API header app_name: mprs genie

flutter build apk --flavor production --release

Write-Host ""
Write-Host "Production APK: build/app/outputs/flutter-apk/app-production-release.apk"
