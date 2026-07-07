# Implementation Decisions

This document captures the practical decisions used for the first implementation pass.

## Principle

Build the smallest version that can become production-grade later.

## Chosen direction

- Mobile-first
- English + Amharic localization from the start
- Modular structure instead of a huge all-in-one code dump
- Avoid features that add risk before trust and usage exist
- Standardize work through a repeatable verify loop

## Why this is efficient

- Reduces initial surface area
- Makes localization a core capability, not an afterthought
- Keeps the codebase easy to extend once the core church/community flows are stable
- Keeps the team aligned on one verification path: build, analyze, fix, repeat

## What will be added first

- Locale selection
- String registry for English and Amharic
- Root app shell
- Placeholder admin and API folders for the future monorepo
- Repeatable scripts for backend, admin, and mobile verification
