# Push notifications (FCM) setup

Push is queue-backed end to end. The **server side is done**: the worker delivers
to Firebase Cloud Messaging when credentials are present, and logs otherwise. The
**client side** needs a Firebase project before it can obtain device tokens.

## How it works

1. A notification with the `push` channel enabled fans out in the API
   (`notifications.service.ts`): for each of the user's enabled `device_tokens`
   it creates a delivery row and enqueues a `push-notifications` job carrying the
   token, title, body, and target.
2. The worker (`services/worker/src/push-sender.ts`) sends each job via **FCM
   HTTP v1**, authenticating with a service-account JWT it self-signs and
   exchanges for a short-lived OAuth token (cached ~55 min; no firebase-admin
   dependency).
3. Delivery rows move `queued → processing → delivered` (or `retry`/`failed`).
   If FCM reports the token is dead (`UNREGISTERED` / `NOT_FOUND` /
   `INVALID_ARGUMENT` / 404), that `device_tokens` row is **disabled** and the
   job is not retried.

## Server configuration

Set these on the **worker** (env var or a `/run/secrets/*` file, like the other
secrets):

| Var | Value |
|-----|-------|
| `PUSH_PROVIDER` | `fcm` (anything else = disabled → logs only) |
| `FCM_SERVICE_ACCOUNT` | the **full JSON** of a Firebase service-account key |
| `PUSH_TIMEOUT_MS` | optional, default `15000` |

Get the service account: Firebase Console → Project settings → **Service
accounts** → *Generate new private key*. Provide the downloaded JSON as the value
of `FCM_SERVICE_ACCOUNT` (escaped `\n` in the private key is handled). If
`PUSH_PROVIDER=fcm` is set without a service account, the worker refuses to start
— fail fast rather than silently drop pushes.

With `PUSH_PROVIDER` unset/`disabled`, everything works except the actual send:
the worker logs `push_logged` and marks the delivery delivered, so the rest of
the pipeline is testable without credentials.

## Client enablement (~20 min, needs the Firebase project)

The API and a `PushRegistration` helper (`lib/data/push_registration.dart`) are
already in place. To turn on device tokens:

1. **Firebase project** → add an **Android app** with package
   `com.christianyouth.superapp`; download `google-services.json` into
   `apps/mobile/android/app/`. (For iOS later: add an iOS app, drop
   `GoogleService-Info.plist` into the Runner target.)
2. **Gradle**: add the Google services plugin.
   - `android/settings.gradle.kts` plugins block:
     `id("com.google.gms.google-services") version "4.4.2" apply false`
   - `android/app/build.gradle.kts` plugins block:
     `id("com.google.gms.google-services")`
3. **Dart deps** (`apps/mobile/pubspec.yaml`): add `firebase_core` and
   `firebase_messaging`, then `flutter pub get`. Run `flutterfire configure` if
   you prefer generated `firebase_options.dart`.
4. **Init + register** — after Firebase.initializeApp and sign-in:

   ```dart
   final push = PushRegistration(apiClient);
   await FirebaseMessaging.instance.requestPermission();
   final t = await FirebaseMessaging.instance.getToken();
   if (t != null) await push.register(session.token, t);
   FirebaseMessaging.instance.onTokenRefresh.listen((t) => push.register(session.token, t));
   ```

   On sign-out, call `push.reset()` (and optionally `disableDeviceToken`).

> Note: `firebase_messaging` was deliberately **not** added yet. Adding it
> without `google-services.json` breaks the Android build (the google-services
> plugin fails when the file is missing) — the same class of failure `file_picker`
> caused on this toolchain. Add the plugin only once the JSON is in place.

## Testing a real push

1. Configure the worker with `PUSH_PROVIDER=fcm` + `FCM_SERVICE_ACCOUNT`.
2. Register a token: `POST /notifications/device-tokens { token, platform }`
   (the client does this automatically once FCM is enabled).
3. Trigger `POST /notifications/test` (or any push-generating action).
4. Watch the worker log for `push_sent` `provider:"fcm"`, and check the
   `notification_deliveries` row flips to `delivered`.
