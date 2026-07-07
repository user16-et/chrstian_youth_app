# Demo and User Journey

## Start from clean demo data

The reset command deletes the local `christian_super_app` schema, reapplies every migration, and starts the API briefly so all seed catalogs are populated.

```bash
POSTGRES_HOST_PORT=5433 npm run demo:reset -- --yes
npm run dev
```

Use `POSTGRES_HOST_PORT=5432` when that is the Docker host port on your machine.

## Demo accounts

All seeded accounts use password `password123`.

| Phone | Persona |
| --- | --- |
| `0910000000` | Youth Ministry |
| `0910000001` | Selam Abebe |
| `0910000002` | Henok Tesfaye |
| `0910000003` | Mekdes Tadesse |

The Account tab in the Flutter app provides one-tap access to these personas. A new user can instead select **Create account**, enter a full name, unique phone number, password, and English or Amharic.

## Complete user path

1. Register or log in from **Account**.
2. Open **Home** for the daily verse, announcements, activity, and the eight super-app pillars.
3. Use **Explore** to search people, churches, ministries, posts, events, groups, sermons, and Bible content.
4. Use **Community** for the social feed, groups, prayer, messaging, testimonies, mentorship, volunteering, talent, and safe courtship tools.
5. Use **Bible** for verses, plans, search, bookmarks, highlights, notes, prayer journal, and growth streaks.
6. Return to **Account** to edit the profile, inspect church/ministry memberships, manage notifications, or change persona.

Authenticated actions persist in PostgreSQL. Public catalogs are seeded for churches, groups, events, ministries, prayer circles, mentors, opportunities, media, talent competitions, giving plans, Bible material, sermons, stories, and courtship discovery.

## Prove the pipeline

With the API running, execute:

```bash
API_URL=http://127.0.0.1:3000 npm run demo:smoke
```

The smoke journey registers a fresh user and exercises authentication, church and group membership, event registration, social engagement, moderation, prayer, growth, ministry operations, Bible study, mentorship, testimony creation, volunteering, talent, giving, courtship, chat, search, and notifications.

It also validates the Samuel acceptance journey: OTP verification, Mulu Wongel onboarding, Youth and Media ministry membership, interests, saved posts, “I prayed,” 90-day plan progress, friendship requests, story replies, course completion, certificates, badges, marketplace orders, and receipts.

## Cleanup

```bash
npm run clean
```

This removes generated build output, Flutter/Next caches, and local runtime logs. It does not remove dependencies, source files, or PostgreSQL data.
