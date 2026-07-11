# Notifications System

Phase 8 makes notifications queue-backed and delivery-aware.

## Channels

- `in_app`: canonical app notification row and read/unread state.
- `push`: queued to `push-notifications`, delivered to active `device_tokens`.
- `sms`: queued to `sms-otp` for now; provider integration can replace worker logging.
- `email`: queued to `email`; provider integration can replace worker logging.

## Tables

- `notifications`: source notification with `priority`, `dedupe_key`, `batch_key`, `scheduled_for`, and metadata.
- `notification_preferences`: per-user channel and category preferences.
- `notification_deliveries`: per-channel delivery attempt state.
- `device_tokens`: active push targets per user/device.

## Rules

- Dedupe is enforced with `notifications.dedupe_key`.
- Low-priority notifications with a `batch_key` are scheduled 15 minutes ahead as the basis for digest batching.
- Urgent church alerts use all channels immediately: in-app, push, SMS, and email if enabled and available.
- BullMQ retries failed jobs with exponential backoff. Delivery rows track queued, processing, delivered, retry, and failed states.

## API

- `GET /notifications`
- `GET /notifications/unread-count`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`
- `GET /notifications/preferences`
- `PATCH /notifications/preferences`
- `POST /notifications/device-tokens`
- `DELETE /notifications/device-tokens/:id`
- `GET /notifications/deliveries`
- `POST /notifications/test`

## Provider Integration

- **Push:** delivered via **FCM HTTP v1** in the worker (`push-sender.ts`),
  env-gated by `PUSH_PROVIDER=fcm` + `FCM_SERVICE_ACCOUNT`; dead tokens are
  auto-disabled. See [push-notifications-setup.md](push-notifications-setup.md).
- **SMS:** delivered via AfroMessage (`sms-sender.ts`, `SMS_PROVIDER=afromessage`).
  See [sms-otp.md](sms-otp.md).
- **Email:** still logs and marks delivered; swap in an email provider while
  keeping the delivery status updates.

Each provider stays behind an env flag and logs (marking the delivery delivered)
when unconfigured, so the pipeline is fully testable without credentials.
