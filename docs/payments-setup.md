# Payments (Chapa) setup

Payments run through a **provider-agnostic module** (`services/api/src/modules/payments`)
with a **Chapa** adapter for production and a **mock** adapter so the whole flow
is testable without gateway credentials. Chapa aggregates telebirr, CBE Birr, and
cards behind one hosted checkout, so a single integration covers the main
Ethiopian rails; other providers (Santimpay, telebirr direct) can be added behind
the same `PaymentProvider` interface.

## Flow

1. **Checkout** — `POST /payments/checkout { purpose, referenceId, amount?, currency? }`
   creates a `payment_transactions` row (status `pending`, a unique `tx_ref`),
   asks the provider to initialize, and returns a hosted `checkoutUrl`.
   - `purpose: "donation"` → `referenceId` = giving fund id; `amount` from the request.
   - `purpose: "payment_plan"` → `referenceId` = plan id; amount comes from the plan.
2. **Pay** — the client opens `checkoutUrl`; the payer completes payment on the
   gateway and is redirected to `PAYMENT_RETURN_URL?tx_ref=...`.
3. **Settle** — two independent paths, both **idempotent**:
   - **Webhook** `POST /payments/webhook` (the gateway calls it): signature is
     verified, then the transaction is **re-verified server-to-server** — the
     webhook body is never trusted for money.
   - **Verify/poll** `GET /payments/:txRef/verify` (the client calls it on return).
   The first `pending → paid` transition writes the domain row (a `donations` or
   `payment_history` record) and marks the transaction `reconciled`. A second
   webhook/verify is a no-op.

## Server configuration

| Var | Value |
|-----|-------|
| `PAYMENT_PROVIDER` | `chapa` in production; `mock` in dev (default); `disabled` to turn off |
| `CHAPA_SECRET_KEY` | Chapa secret key (`sk_...`); required when provider is `chapa` |
| `CHAPA_WEBHOOK_SECRET` | webhook signing secret (recommended; without it the webhook relies on server-side verify) |
| `CHAPA_BASE_URL` | optional, default `https://api.chapa.co/v1` |
| `PAYMENT_CALLBACK_URL` | absolute URL of `POST /payments/webhook` (what Chapa calls) |
| `PAYMENT_RETURN_URL` | where the payer's browser lands after paying |
| `PAYMENT_TIMEOUT_MS` | optional, default `20000` |

Guards: production refuses to boot with `PAYMENT_PROVIDER=mock`, and `chapa`
without `CHAPA_SECRET_KEY` fails fast. Values also load from `/run/secrets/*`
files like the other secrets.

### Chapa dashboard steps

1. Create a Chapa account, get the **secret key** from the dashboard →
   `CHAPA_SECRET_KEY`.
2. Set the **webhook URL** to your public `POST /payments/webhook`, and copy the
   webhook **secret hash** → `CHAPA_WEBHOOK_SECRET`.
3. Set `PAYMENT_CALLBACK_URL` (same webhook URL) and `PAYMENT_RETURN_URL`.

## Endpoints

- `GET  /payments/status` — provider + readiness.
- `POST /payments/checkout` — start a payment (auth).
- `GET  /payments/:txRef/verify` — verify/poll status (auth, owner-only).
- `GET  /payments/transactions` — the caller's transactions (auth).
- `POST /payments/webhook` — gateway callback (signature-verified).
- `POST /payments/:txRef/mock-complete` — **mock provider only**; settles a
  transaction, standing in for the gateway callback in dev/tests.

## Client

`api_client.dart` has `createPaymentCheckout`, `verifyPayment`, and
`fetchPaymentTransactions`. UI wiring (e.g. a "Give" button on a fund): call
`createPaymentCheckout`, open `checkoutUrl` with `url_launcher`, then on return
poll `verifyPayment(txRef)` until `status == 'paid'`.

## Testing without credentials

With `PAYMENT_PROVIDER=mock`:

```bash
# 1. checkout
curl -X POST $API/payments/checkout -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  -d '{"purpose":"donation","referenceId":"<fundId>","amount":150}'
# 2. settle (mock stands in for the gateway)
curl -X POST $API/payments/<txRef>/mock-complete -H "authorization: Bearer $TOKEN"
# 3. confirm: a donations row is written, transaction is paid + reconciled
curl $API/payments/transactions -H "authorization: Bearer $TOKEN"
```

Verified E2E: donation + payment_plan checkout → settle writes the domain row
once (idempotent on repeat), validation (bad purpose / amount<1 / missing fund)
returns 4xx, and Chapa webhook HMAC verification accepts valid and rejects
wrong/missing/tampered signatures.

## Adding another provider

Implement `PaymentProvider` (`initialize`, `verify`, `verifyWebhook`) in
`providers/`, add a branch in `PaymentsService`'s constructor and a
`PAYMENT_PROVIDER` value. The service, reconciliation, and idempotency are
provider-independent.
