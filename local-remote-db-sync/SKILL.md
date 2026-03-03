---
name: local-remote-db-sync
description: Workflow for keeping local development database and production (remote) schema in sync when iterating with many migrations. Applies to any stack (SQLite, PostgreSQL, D1, etc.) and any migration runner. Use when deploying after local DB changes or when "apply all migrations" fails on production.
---

# Local vs Remote Database Migration Consistency

This skill describes a **paradigm**: develop with a local database and many migration iterations, then bring production to a consistent state without relying on a single "apply all" run. It is **stack-agnostic** (no dependency on Cloudflare D1, Workers, or a specific ORM).

## When to Use This Skill

- The project uses **versioned migration files** (e.g. `migrations/0001_*.sql`, `0002_*.sql`, ...).
- **Local** has been iterated many times: migrations applied (or re-applied), schema changed often.
- **Production/remote** was created earlier or from a different path; its "migration history" may not match the list of migration files.
- You need to **deploy new code** that depends on new tables/columns, and production must be updated without data loss or duplicate-column errors.

## The Problem

- **Migration history vs reality**: Many tools (e.g. Wrangler, Flyway, Rails) record "which migrations ran" in a table. If production was ever built by hand, restored from backup, or had only some migrations run, that history diverges from the actual schema.
- **"Apply all" fails**: Running "apply all pending migrations" on production then fails with errors like:
  - `duplicate column name`
  - `no such table: X`
  - `column already exists`
- **Result**: New code expects the new schema; production does not have it. Deploy breaks or app shows "schema missing" errors.

## Paradigm: Local Dev DB + Remote Verification

1. **Local**: Treat the local database as the place to iterate. Run migrations in order (or reset and re-apply) so local schema always matches the **current set of migration files**.
2. **Remote**: Do **not** assume remote has the same migration history as local. Treat remote as "current production schema" and bring it forward by applying **only the delta** (the migrations that add what production is missing).
3. **Deploy order**: Apply the required migrations to production **before** deploying application code that depends on the new schema. Otherwise the new code may 500 or show "schema missing" on first request.

## How to Achieve Consistency

### Option A: Run specific migration files (recommended when history is unreliable)

- Identify which migration files **production has not yet applied**. (Compare errors: e.g. "no such table: users" means everything that creates `users` and later is missing; "duplicate column: foo" means that migration was already applied.)
- Run those migration files **one by one, in order**, against production using the project's normal "execute SQL file" command (e.g. `psql -f`, `wrangler d1 execute --remote --file=...`, `mysql < file.sql`).
- **Idempotency**: Prefer migrations that are safe to run twice (e.g. `CREATE TABLE IF NOT EXISTS`, `INSERT OR IGNORE`, `ALTER TABLE ... ADD COLUMN` only if the column does not exist, or tooling that skips already-applied steps). If a file is not idempotent and production already has that change, skip that file or fix the script.

### Option B: Use "apply all" only when history is trusted

- Use the framework's "apply all pending migrations" (e.g. `migrations apply --remote`) **only** when you are sure production has never been modified by hand and has run exactly the same sequence of migrations as the codebase.
- If "apply all" fails, **do not** retry the same command; switch to Option A and run the missing migrations by file.

### Checklist for the agent

- Before deploying application code that touches the DB:
  1. Check if there are **new or changed migration files** in this change set.
  2. If yes, ensure production has those changes: run the corresponding migration file(s) against production (in order), or run "apply all" only if the project documents that production is in sync.
  3. Then deploy the application (e.g. deploy Worker, push image, release).

## Documenting in the project

- In the repo, document the **migration runbook** (e.g. in `docs/deployment/` or `AGENTS.md`): "When deploying, if `migrations apply --remote` (or equivalent) fails, run the missing migration files manually in order; see list 0001_..., 0002_..., ..."
- Optionally list **dependencies** (e.g. "0013 adds column to `users`; 0011 must have run first"). That helps the agent choose which files to run when errors point to a missing table or column.

## Pitfalls

- **Running migrations after deploy**: If you deploy new code first and then run migrations, the new code may hit "no such table" or "column not found" until migrations finish. Prefer migrations-before-deploy.
- **Partial apply**: If "apply all" runs 3 of 5 and then fails, production is in a half state. Prefer running the remaining 2 files manually rather than retrying "apply all" (which may try to re-run the 3 and fail on "duplicate").
- **Different DB engines**: Local might be SQLite and production PostgreSQL (or vice versa). Some SQL is not portable (e.g. `INSERT OR IGNORE`). Keep migration SQL compatible with the production engine or maintain separate files per engine.
