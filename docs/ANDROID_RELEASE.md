<!-- Developed by Codesoftwares -->
# Android signing and release (Nari Shakthi Matrimony)

Do these in order. Phase 10 rule: no secrets in source control or inside the app.

## 1. Create the Android project (once)
```
cd app
flutter create . --platforms=android --org com.yourcompany --project-name nari_shakthi
```
Pick your own `--org`. The package name (applicationId) becomes `com.yourcompany.nari_shakthi`
and can NEVER change after you publish. Do not ship `com.example`.

## 2. Manifest (android/app/src/main/AndroidManifest.xml)
- Add inside `<manifest>`: `<uses-permission android:name="android.permission.INTERNET"/>`
  (only the debug manifest has it by default, so a release build cannot reach your API without this).
- Set `android:label="Nari Shakthi Matrimony"` on `<application>`.
- Use an HTTPS API URL in release. Do not enable cleartext traffic.

## 3. Upload keystore (once, keep it safe)
```
keytool -genkey -v -keystore ~/nari-shakthi-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Back it up in two separate safe places with the passwords. Never commit it (`.gitignore` already blocks `*.jks`).
Enrol in Play App Signing when you upload, so a lost upload key can be reset by Google.

## 4. android/key.properties (not committed)
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/nari-shakthi-upload.jks
```

## 5. android/app/build.gradle.kts
Add at the very top:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))
```
Inside `android { ... }`:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```
(If your template uses `build.gradle` with Groovy, the same keys apply with Groovy syntax; see Flutter's "Build and release an Android app" page.)

## 6. Version
`app/pubspec.yaml`: `version: 1.0.0+1`. Raise the number after `+` on every upload.

## 7. Build
```
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.your-domain --dart-define=UPI_ID=name@bank
```
Output: `build/app/outputs/bundle/release/app-release.aab` (upload this to Play).
For a direct-install test file: `flutter build apk --release --split-per-abi` with the same defines.

## 8. Test the release build on a real phone (Phase 10 smoke tests)
Use test accounts only, against the production API over HTTPS:
- Register, complete profile, add a photo (opens, and is NOT visible to a stranger when private).
- Search, send interest, accept, chat, share phone (both must agree).
- Upload payment screenshot, admin verifies it, notification arrives.
- Admin tab rejects a normal member account (403).
- Logs contain no passwords, phone numbers, messages or screenshots.
- Delete account works.

## 9. Play Console
1. Create the app, enrol in Play App Signing, upload the .aab to Internal testing first.
2. Fill: privacy policy URL, Data safety (email, profile details, photos, messages, payment screenshots, phone number), content rating, target audience 18+.
3. Add an account deletion option (in the app: Profile > Delete my account) and the web link Play asks for.
4. New personal developer accounts may need a closed test with a minimum number of testers for a set time before production. Check the current rule in Play Console.
5. Roll out in stages (for example 10%), watch crashes and the server logs, then widen.

## 10. Check before you submit: Play payments policy
Your plan is a UPI QR + screenshot membership payment outside Google Play. Google's payments policy lists subscription
services such as dating among items that must use Google Play's billing system, and says apps may not lead users to another
payment method unless the policy permits it. A matrimonial membership may fall under this. Read the current Payments policy
(support.google.com/googleplay/android-developer/answer/9858738) and, if unsure, ask Play support before launch.
Options: Play Billing for the membership, an exemption or alternative billing program if one applies to you, or removing
in-app payment (pay on your website, app is consumption-only). Rejection or removal of the app is the risk if this is wrong.
