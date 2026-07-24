# API tests

Two layers, run by Jest:

- **Unit** (`src/**/*.spec.ts`) — pure functions, no I/O.
- **Integration** (`src/**/*.integration.spec.ts`, `*.e2e-spec.ts`) — real
  repository/service code against a real Postgres.

## Running

```bash
npm run test          # from services/api (or `npm run test:api` from the repo root)
npm run test:unit     # unit specs only, no DB needed
```

## The test database

Integration tests use an **isolated** database (`christian_super_app_test`) so
they never touch the app's primary data. On the first run, `test/global-setup.ts`
creates that database and applies every migration; it is idempotent.

Defaults target the local docker Postgres on `localhost:5433`. Override via env
for other environments (CI sets these to the service Postgres on 5432):

| Env | Default |
| --- | --- |
| `TEST_PGHOST` | `localhost` |
| `TEST_PGPORT` | `5433` |
| `TEST_PGUSER` | `postgres` |
| `TEST_PGPASSWORD` | `postgres` |
| `TEST_DB_NAME` | `christian_super_app_test` |
| `TEST_DATABASE_URL` | built from the above |

## Fixtures

`test/factories.ts` provides `createUser`, `deleteUsers`, and a shared
`testPool` for arranging and asserting DB state. Close per-repository pools and
`closeTestPool()` in `afterAll` so Jest exits cleanly.
