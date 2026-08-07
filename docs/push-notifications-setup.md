# Enabling phone push notifications (FCM)

The app is fully wired for Firebase Cloud Messaging — it just needs **your**
Firebase project. Until you complete these steps, push is disabled gracefully:
in-app notifications (the bell) and the local **daily-verse** alarm still work;
only push-to-phone for messages/calls is inactive.

## What's already built

- **Server**: real FCM sender (`services/worker/src/push-sender.ts`),
  `device_tokens` table, register/disable endpoints, per-category preferences.
- **App**: `PushService` (`apps/mobile/lib/data/push_service.dart`) initializes
  Firebase, gets the FCM token, registers it, keeps it fresh, and shows a local
  notification for foreground messages. It's called on sign-in from `home_shell`.
- **Triggers**: new friend/group messages and missed calls create notifications
  that queue for push (gated by the user's toggles in **Profile → Notification
  settings**).

## Steps (~15 min)

### 1. Create the Firebase project + Android app
1. In the [Firebase Console](https://console.firebase.google.com), create a
   project.
2. Add an **Android app** with package name **`com.christianyouth.superapp`**.
3. (iOS later: add an iOS app with the matching bundle id.)

### 2. Generate the app config
```bash
dart pub global activate flutterfire_cli
cd apps/mobile
flutterfire configure          # select your project + Android (and iOS)
```
This overwrites the placeholder `apps/mobile/lib/firebase_options.dart` with your
real keys and adds the required Android Gradle wiring. Rebuild:
```bash
flutter build apk --release --dart-define=API_BASE_URL=<your api url>
```
Push registration now activates automatically on the next sign-in.

### 3. Give the worker an FCM service account
1. Firebase Console → Project settings → **Service accounts** → *Generate new
   private key* (downloads a JSON).
2. Provide it to the worker as `FCM_SERVICE_ACCOUNT` (the JSON string) and set
   `PUSH_PROVIDER=fcm`. In `docker-compose.yml` under the `worker` service:
   ```yaml
   PUSH_PROVIDER: fcm
   FCM_SERVICE_ACCOUNT: ${FCM_SERVICE_ACCOUNT}
   ```
   and put the JSON in your `.env` (single line). Redeploy the worker.

## Verify
1. Sign in on a device → check a `device_tokens` row exists for that user.
2. Send that user a direct message from another account → the phone gets a push
   (with the app backgrounded).
3. Toggle **Profile → Notification settings → Messages from friends** off →
   no more push for that category.
