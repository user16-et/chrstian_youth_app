# Android release signing

Release builds are signed with an upload keystore instead of the throwaway
Android debug key, so the APK/AAB is installable as a real release and
publishable to the Play Store.

## ⚠️ Back up the keystore and password — now

The keystore and its password are **irreplaceable secrets**. If you lose them you
can **never publish an update** to the same Play Store listing (users would have
to uninstall and reinstall a new app). Neither file is in git.

Copy these somewhere safe (a password manager + an offline backup):

- `apps/mobile/android/app/upload-keystore.jks` — the keystore (PKCS12).
- `apps/mobile/android/key.properties` — holds the passwords and alias.

Both are gitignored (`key.properties`, `**/*.jks`) and must stay that way.

## How it's wired

`apps/mobile/android/app/build.gradle.kts` loads `android/key.properties` if it
exists and uses it for the `release` signing config. If the file is **absent**
(CI, a fresh clone, a contributor without the keystore), release builds fall back
to debug signing so the project still assembles — but such an APK is **not
publishable**. `build-release.sh` prints which mode is in effect.

`key.properties` format:

```properties
storePassword=<store password>
keyPassword=<same as store password for PKCS12>
keyAlias=upload
storeFile=upload-keystore.jks
```

Note: PKCS12 keystores require `keyPassword == storePassword` (a mismatch fails
at signing with "Given final block not properly padded").

## Build a signed release

```bash
cd apps/mobile
./build-release.sh <api-ip-or-url> 3000 appbundle   # .aab for Play Store
./build-release.sh <api-ip-or-url> 3000 apk         # universal APK (sideload)
./build-release.sh <api-ip-or-url> 3000 split       # per-ABI APKs (smaller)
```

The `appbundle` output (`build/app/outputs/bundle/release/app-release.aab`) is
what you upload to the Play Console.

## Verify a build's signature

```bash
APKSIGNER=$(find $ANDROID_HOME/build-tools -name apksigner | head -1)
"$APKSIGNER" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

A release build shows `CN=Christian Youth Super App` (not `CN=Android Debug`).

## This keystore's certificate

- **Alias:** `upload`  ·  **Type:** PKCS12  ·  **Key:** RSA 2048, SHA384withRSA
- **Valid until:** 2053-11-25 (well past Play's 2033 minimum)
- **SHA-1:** `31:D5:AA:02:B7:08:2B:5A:C6:A0:CA:2C:00:12:51:01:5A:30:15:E9`
- **SHA-256:** `A6:90:60:47:6F:04:F9:B9:98:DC:8F:C9:73:D8:B7:54:E2:97:BC:8B:C5:DA:0B:05:65:A9:7D:35:60:AB:85:0E`

Use these fingerprints when registering the app with Firebase, Google Sign-In,
Maps, or other services that pin the signing cert.

## Play App Signing (recommended)

When you enrol in **Play App Signing**, Google holds the *app signing key* and
this keystore becomes your *upload key* (used only to sign uploads to the
Console). If the upload key is ever lost, Google can reset it — but the app
signing key they hold is the one users' installs are tied to. Either way, still
back up this upload keystore.

## Rotating / regenerating (only if you must)

Generating a new keystore produces a **different** certificate, which the Play
Store treats as a different app unless you use the Play Console key-upgrade flow.
For a brand-new app that hasn't shipped yet, you can regenerate freely:

```bash
cd apps/mobile/android/app
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12 \
  -storepass <PW> -keypass <PW> \
  -dname "CN=Christian Youth Super App, OU=Mobile, O=Christian Youth, L=Addis Ababa, ST=Addis Ababa, C=ET"
# then update android/key.properties with the new password
```
