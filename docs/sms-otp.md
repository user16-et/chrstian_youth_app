# SMS / OTP delivery

Phone verification (registration, password reset) is a three-step flow:

1. **API generates the code.** `POST /journey/otp/request` creates an `otp_challenges`
   row. In production/staging the code is crypto-random; in development it is the
   fixed `123456` so local demos and `demo:smoke` work without a provider.
2. **API enqueues delivery.** An `sms-otp` BullMQ job carries `{ phoneNumber, code, expiresAt }`.
3. **Worker sends the SMS.** The `smsOtp` processor calls `SmsSender`, which delivers
   through AfroMessage. On failure it throws so BullMQ retries and the
   `notification_deliveries` row is marked `retry`/`failed`.

Verification (`POST /journey/otp/verify`) matches the stored code — the provider only
delivers, it does not verify.

## Provider: AfroMessage

[AfroMessage](https://afromessage.com) is an Ethiopian SMS gateway. Delivery is
controlled entirely by the worker's environment:

| Variable | Purpose |
| --- | --- |
| `SMS_PROVIDER` | `disabled` (log only, default) or `afromessage` |
| `SMS_APP_NAME` | Name shown in the SMS body |
| `AFROMESSAGE_TOKEN` | API access token (JWT) from the AfroMessage dashboard — **required** when enabled |
| `AFROMESSAGE_FROM` | Sender/identifier ID |
| `AFROMESSAGE_SENDER` | Approved sender name / short code |
| `AFROMESSAGE_BASE_URL` | Defaults to `https://api.afromessage.com/api` |
| `AFROMESSAGE_CALLBACK` | Optional delivery-report callback URL |

Enabling it:

```bash
SMS_PROVIDER=afromessage
AFROMESSAGE_TOKEN=<token from dashboard>
AFROMESSAGE_FROM=<identifier id>
AFROMESSAGE_SENDER=<approved sender name>
```

The worker fails fast on boot if `SMS_PROVIDER=afromessage` without a token.

Phone numbers are normalized to E.164 before sending: `0912…`, `0712…`, `2519…`,
`+2519…`, and bare `9…`/`7…` forms all become `+2519XXXXXXXX` / `+2517XXXXXXXX`.

## Known follow-ups

- **Verify attempt limits.** `POST /journey/otp/verify` is covered only by the general
  write rate limit. Add a per-phone attempt lockout before public launch.
- **Canonical phone identity.** The number is stored as typed. Registration/login should
  adopt the same E.164 normalizer so `0912…` and `+2519…` are one account. This couples
  to `isPhoneVerified`, so change all identity paths together.
