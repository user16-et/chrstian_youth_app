# Christian Youth Super App

Lean starter foundation for the Ethiopia-focused Gospel believer / Protestant Christian youth super app.

## Build decision

This implementation starts with the smallest useful structure:

- Mobile app first, with English and Amharic support from day one
- Backend and admin surfaces scaffolded, but not overbuilt
- MVP scope expanded to identity, church, feed, groups, Bible notes, events, chat, reporting, prayer, ministries, mentorship, stories, payments, and courtship
- API expects PostgreSQL at startup
- Standardized verification loop is available through `npm run verify`

## Repository layout

```text
apps/
  mobile/   Flutter app foundation with bilingual support
  admin/    Next.js admin portal
services/
  api/      NestJS backend
packages/
  shared/   Shared types and constants
docs/      Product and architecture decisions
scripts/   Repeatable verification and maintenance scripts
```

## Language support

The app is built for Ethiopia and must support:

- English
- Amharic

## Standard loop

Use this loop while continuing work:

1. Make a focused change
2. Run `npm run verify`
3. Fix any failures
4. Repeat until the target passes

## Run everything

Use `npm run dev` to start the local stack:

- PostgreSQL via Docker Compose
- NestJS API on `http://127.0.0.1:3000`
- Next.js admin dashboard on `http://127.0.0.1:3001`
- Flutter web app on `http://127.0.0.1:5173`

Related helpers:

- `npm run stop` stops the API, admin app, Flutter web app, and Docker Compose stack
- `npm run logs` tails the API, admin, and mobile logs

`npm run dev` applies the SQL schema automatically if `psql` is installed.

## Mobile API configuration

The Flutter client reads `API_BASE_URL` at compile time. Local web development
defaults to `http://127.0.0.1:3000`. Set the URL explicitly for devices and
production builds:

```bash
# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# Production web
flutter build web --dart-define=API_BASE_URL=https://api.example.com
```

Use an HTTPS URL in production. This value is compiled into the application;
changing a server-side environment file does not change an existing mobile or
web build.

## MVP scope

1. Account and profile identity
2. Church selection and verification
3. Feed and posts
4. Groups and communities
5. Bible and notes
6. Events
7. Chat
8. Reporting and blocking

## API surface

The backend currently includes real endpoints for:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`
- `GET /app/bootstrap`
- `GET /feed`
- `GET /churches`
- `GET /groups`
- `GET /events`
- `GET /posts`
- `POST /posts`
- `GET /bible/notes`
- `POST /bible/notes`
- `PATCH /bible/notes/:id`
- `DELETE /bible/notes/:id`
- `GET /moderation/reports`
- `POST /moderation/reports`

`GET /moderation/reports` is restricted to moderator and administrator JWTs.

## Environment

- `services/api/.env.example` contains the required `DATABASE_URL`
- Flutter receives `API_BASE_URL` through `--dart-define` at build or run time
- Android SDK is installed under [`.sdk/android-sdk`](/home/toor/pro/chrstian_app/.sdk/android-sdk)
- Flutter SDK is installed under [`.sdk/flutter`](/home/toor/pro/chrstian_app/.sdk/flutter)
