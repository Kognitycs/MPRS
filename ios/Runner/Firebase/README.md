# iOS Firebase setup (staging + production)

Bundle IDs mirror Android flavors:

| Flavor       | Bundle ID                      | Display name      |
|--------------|--------------------------------|-------------------|
| production   | `com.mprsshipping.genie`       | MPRS Genie        |
| staging      | `com.mprsshipping.genie.test`  | MPRS Genie Test   |

## 1. Firebase Console

In project **mprs-rms**, add two iOS apps:

1. **Production** — bundle ID `com.mprsshipping.genie`
2. **Staging** — bundle ID `com.mprsshipping.genie.test`

Download each `GoogleService-Info.plist` and replace:

- `ios/Runner/Firebase/Production/GoogleService-Info.plist`
- `ios/Runner/Firebase/Staging/GoogleService-Info.plist`

Copy the `GOOGLE_APP_ID` from each plist into:

- `lib/core/firebase/firebase_app_config.dart` (`_productionIos` / `_testIos`)

## 2. Apple Developer

Register the same bundle IDs under **Certificates, Identifiers & Profiles → Identifiers**.

## 3. Build

```bash
flutter run --flavor staging
flutter run --flavor production
flutter build ipa --flavor production --release
```

Xcode schemes: `staging`, `production` (legacy `Runner` uses production configs).

The **Copy Firebase Plist** build phase selects the correct plist per flavor before compile.

## 4. Native iOS (included in repo)

- **Info.plist** — privacy strings (Face ID, photos, camera), `UIBackgroundModes` → `remote-notification`
- **Runner.entitlements** — Push Notifications (`aps-environment`)
- **Podfile** — CocoaPods with staging/production build configurations

On Mac after pulling:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run --flavor staging
```

Set your **Team** in Xcode → Runner → Signing & Capabilities (not stored in git).
