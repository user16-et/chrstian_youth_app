# Sanctuary Command Admin

The admin app is a Next.js trust-operations dashboard backed by the Nest API.

## Security model

- There is no public administrator registration.
- The first administrator is created once through the backend CLI.
- Admin login issues a short-lived HS256 JWT tied to a revocable `admin_sessions` record.
- Next.js stores the JWT in an HTTP-only, same-site cookie. Client JavaScript never receives it.
- Platform RBAC protects dashboard, church verification, moderation, and audit APIs.
- Login, logout, moderation decisions, and church verification decisions are audited.

## First administrator

Apply migrations first:

```bash
DATABASE_URL=postgresql://... npm --workspace services/api run migrate
```

Provide the password through the environment or a secret file so it does not enter shell history:

```bash
DATABASE_URL=postgresql://... \nADMIN_PASSWORD_FILE=/run/secrets/first_admin_password \nnpm run admin:create -- --name="Platform Steward" --phone=+251900000000
```

For local development only:

```bash
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/christian_super_app \nADMIN_PASSWORD='use-a-strong-local-password' \nnpm run admin:create -- --name="Local Admin" --phone=0999999999
```

The command refuses to create another initial administrator after one platform administrator exists.

## Run

The API requires a strong JWT secret in production:

```bash
JWT_SECRET_FILE=/run/secrets/jwt_secret
ADMIN_JWT_ISSUER=christian-super-app-api
ADMIN_JWT_AUDIENCE=christian-super-app-admin
ADMIN_JWT_TTL_SECONDS=900
```

Run the dashboard:

```bash
API_BASE_URL=http://127.0.0.1:3000 npm --workspace apps/admin run dev
```

`API_BASE_URL` is server-only and must point to the private API address. In production, serve the dashboard over HTTPS so the secure cookie is enforced.

## Current activities

- Live platform metrics
- Moderation queue resolution
- Church verification approval/rejection
- Administrator activity timeline
- JWT session login/logout and revocation
