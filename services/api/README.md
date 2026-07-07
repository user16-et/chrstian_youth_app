# API Service

Backend service scaffold for the Christian Youth Super App.

## Stack

- NestJS
- PostgreSQL
- Redis later for realtime and queues

## Startup rule

This service is now PostgreSQL-only at runtime. Set `DATABASE_URL` before starting it.

## Endpoints implemented

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
- `GET /moderation/reports`
- `POST /moderation/reports`

## Modules

- auth
- users
- churches
- groups
- events
- posts
- chat
- moderation
- feed
