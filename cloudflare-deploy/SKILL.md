---
name: cloudflare-deploy
description: Cloudflare deployment guidelines—Workers, D1, Pages, Wrangler config, local/remote switching, free tier limits and caveats. Reference when deploying or editing backend, wrangler.toml, migrations, or static frontend.
---

# Cloudflare Deployment and D1/Workers Guidelines

This rule defines standards and caveats for deploying frontends (Pages), Worker backends, and D1 databases on Cloudflare, for use by the Agent and future deployments. **The document is generic and does not reference specific project, instance, or database names.**

## 1 Scope and Principles

- **Workers**: Backend API (e.g. Hono + D1).
- **D1**: Relational database (SQLite-compatible), accessed via Worker bindings.
- **Pages**: Optional, for deploying web frontends (static or SSR).
- **Principles**: Config and code must respect **Cloudflare Free plan** limits; use Secrets for sensitive data, not `wrangler.toml`; switch environments via configuration only, not by changing code.

## 2 wrangler.toml Configuration

### 2.1 Required Settings

- **Node compatibility**: Do not use deprecated `node_compat = true`. Use the compatibility flag:
  ```toml
  compatibility_flags = ["nodejs_compat"]
  ```
- **Free plan: no CPU limits**: The Free plan does not support `cpu_ms` under `[limits]`. If set, you get: `CPU limits are not supported for the Free plan`.
  - **Correct**: Omit `[limits]` or do not set `cpu_ms` on a free account.
  - **Wrong**: On the Free plan, do not add:
    ```toml
    [limits]
    cpu_ms = 30000
    ```
- **D1 binding**: After creating the database, set `database_id` in `wrangler.toml`:
  ```toml
  [[d1_databases]]
  binding = "DB"
  database_name = "<your-database-name>"
  database_id = "<paste from wrangler d1 create output>"
  ```
  The `binding` name (e.g. `DB`) must match code that uses `env.DB`.

### 2.2 Naming and Structure

- Worker name: Prefer a project prefix for clarity.
- Use `[vars]` for non-sensitive env vars; use **Secrets** for sensitive data (API keys, JWT secret), never in toml.

### 2.3 Optional Bindings (uncomment as needed)

- **R2**: Bucket binding for large files (e.g. audio).
- **Workers AI**: For speech-to-text, see **Whisper and Workers AI** below; evaluate limits before adopting.

## 3 Local Run and Config-Based Switching (No Code Changes)

### 3.1 Local Worker + Local D1

- **Local dev**: Run `npx wrangler dev` in the project directory; it uses the **local** D1 instance for the database name in `wrangler.toml`.
- **Local D1 migrations**: Run `npx wrangler d1 migrations apply <database_name> --local` before `wrangler dev`, or local DB has no tables.
- **Local env vars**: Put secrets in **`.dev.vars`** (project root or Worker directory), one `KEY=value` per line. Wrangler loads it automatically for `wrangler dev`. **Do not** commit `.dev.vars`.
- **Pattern**: Provide `.dev.vars.example` listing required keys; developers copy to `.dev.vars` and fill values; production uses `wrangler secret put`.

### 3.2 Switching Local vs Remote via Config (No Code Changes)

- **Database**: Use a single D1 binding in `wrangler.toml`; switch by **command**:
  - Local: `wrangler dev` uses local D1; migrations use `--local`.
  - Remote: `wrangler deploy` uses remote D1; migrations use `--remote`.
- **Env vars**:
  - Local: `.dev.vars`.
  - Remote: `[vars]` (non-sensitive) + `wrangler secret put` (sensitive).
- **Multiple environments (e.g. staging/prod)**: Use separate config files (e.g. `wrangler.toml` for prod, `wrangler.staging.toml` for staging) with different `name`, `database_id`, etc.; switch via `--config wrangler.staging.toml` or npm scripts (e.g. `deploy:staging` runs `wrangler deploy --config wrangler.staging.toml`).
- **Principle**: Switch environments by choosing different config files and commands (dev vs deploy, `--local` vs `--remote`); avoid hardcoded env checks or URLs in application code.

## 4 D1 Database Guidelines

### 4.1 Create and Migrate

- Create: `npx wrangler d1 create <database-name>`. Put the printed `database_id` into the active `wrangler.toml`.
- Place migrations under `migrations/`, ordered by name (e.g. `0001_initial_schema.sql`).
- **Local**: `npx wrangler d1 migrations apply <database_name> --local`
- **Production/remote**: `npx wrangler d1 migrations apply <database_name> --remote`
- Run a `--remote` migration before deploying the Worker, or remote tables will be missing.

### 4.2 Using D1 in the Worker

- Access via binding: `env.DB` (type `D1Database`).
- Use **parameterized queries** only; no string concatenation to prevent injection:
  ```ts
  // Correct
  await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(id).first();
  // Wrong: do not concatenate SQL
  ```
- Respect single-query row/size limits; paginate for large data.

### 4.3 Multiple Environments

- Use different D1 databases (different `database_id`) per environment (e.g. staging/production) via different `wrangler.*.toml` or env; do not switch by changing application code.

## 5 Workers Deployment

### 5.0 Authentication (why deploy may work without an API token)

- **Interactive use (e.g. Cursor terminal, local shell)**: If you have run `npx wrangler login` once on that machine, Wrangler stores OAuth credentials locally (e.g. under `~/.wrangler`). Later, `npm run deploy` (or `npx wrangler deploy`) reuses that identity and does **not** require an API token each time. That is why deploy can succeed without setting any token.
- **Headless / CI**: In environments with no browser, use an API token. Create a token in Cloudflare Dashboard (My Profile → API Tokens) with permissions for Workers and D1, then set:
  - `CF_API_TOKEN`: the token value
  - `CF_ACCOUNT_ID`: your account ID (from the dashboard or `npx wrangler whoami`)
  Wrangler prefers these env vars when set and skips interactive login.
- **Check current identity**: `npx wrangler whoami`.

### 5.1 Dependencies and Build

- Run `npm install` in the project directory before deploying, or the build may fail to resolve dependencies.
- Deploy with `npx wrangler deploy` (or `npm run deploy`); Wrangler bundles and uploads.

### 5.2 Env Vars and Secrets

- **Secrets** (API keys, JWT secret, etc.): `npx wrangler secret put <NAME>`, then enter the value, or pipe it in (mind shell history).
- Updating a Secret does **not** require redeploy; it takes effect immediately.
- List secrets: `npx wrangler secret list`.
- Use `[vars]` for non-sensitive config (e.g. `JWT_EXPIRES_IN`, `ENVIRONMENT`).

### 5.3 Runtime Constraints (Edge)

- Do not use Node-only APIs (e.g. `Buffer`, `require('fs')`, `__dirname`). Use Web standards: `ArrayBuffer`, `crypto.subtle`, URL, etc.
- Request size and CPU time are limited by plan; stay within Workers request body limits (e.g. 100MB) for large uploads.

## 6 Whisper and Workers AI (Speech-to-Text)

- **Recommendation**: When designing or implementing speech-to-text, **prefer not depending on Workers AI Whisper** if avoidable; consider more controllable or less constrained options (e.g. external STT API, client-side recognition).
- **Reason**: Workers AI Whisper has many limits—e.g. request duration/size, concurrency/QPS, language and quality, free tier and billing, regional availability. Without checking first, you may later find it cannot meet requirements or require a large redesign.
- **If you must use it**: Before adopting, check current Cloudflare docs for Workers AI / Whisper limits and confirm audio length, format, size, concurrency, and free tier meet product needs; document the dependency and limits for maintenance and future replacement.
- **Binding**: If used, set `[ai] binding = "AI"` in `wrangler.toml` and call via `env.AI` in code.

## 7 Frontend Deployment (Cloudflare Pages, Optional)

- To deploy a web frontend on Pages: use a **Pages project** or `wrangler pages`, separate from the Worker.
- Static site: Set the build output directory as the Pages root (e.g. `dist`, `build`).
- If frontend and Worker share a repo: keep them in different directories and use separate `wrangler.toml` or Pages project config.
- Frontend should call the **Worker's full URL** (from deployment); configure CORS in the Worker. Inject different API base URLs per environment via build-time env or config, not hardcoded in code.

### 7.1 Worker + Pages full stack (deploy both for UI to update)

When the app is **Worker (API) + Pages (frontend)**:

- **Two separate deploys**: Deploying only the Worker (`npm run deploy` in the Worker directory) does **not** update the frontend. The UI is served from Pages; to ship new frontend code you must build and deploy the frontend as well.
- **Full production deploy**:
  1. **Worker**: In the Worker project directory: `npm run db:migrate:remote` (if schema changed), then `npm run deploy`.
  2. **Frontend**: In the frontend project directory, build with the **production API base URL** (e.g. `VITE_API_BASE_URL=https://your-worker.workers.dev`), then upload the build output to Pages:
     ```bash
     VITE_API_BASE_URL=https://your-worker.workers.dev npm run build
     npx wrangler pages deploy dist --project-name=<your-pages-project-name>
     ```
     Use the same Worker URL the frontend will call in production; otherwise the deployed site will hit the wrong API or localhost.
- **Pitfall**: Saying "deploy to production" and only running Worker deploy leaves the live site showing the old UI until the frontend is built and deployed to Pages. If the user reports "production still shows old UI", check that **Pages** was redeployed with the new build, not only the Worker.
- **Pages production vs preview**: `wrangler pages deploy` may create a preview deployment by default. To have the main project domain (e.g. `your-project.pages.dev`) show the new build, use `--branch=main` (or the branch configured as production in the Pages project), or in the Cloudflare Dashboard set the latest deployment as the production deployment.

## 8 Free Tier Limits and Caveats (Must Read)

- **CPU**: Free plan does not support custom `[limits] cpu_ms`; remove it or deploy will fail.
- **Usage**: Workers free tier has daily request and CPU limits; D1 has read/write and storage limits; upgrade or optimize if you exceed.
- **Wrangler v4+**: `node_compat` is removed; you must use `compatibility_flags = ["nodejs_compat"]` or config parsing fails.
- **First deploy**: If the Worker does not exist yet, `wrangler secret put` may prompt to create it; that is expected. Then run `wrangler deploy`.

## 9 Command Reference

- Login: `npx wrangler login`
- Current identity: `npx wrangler whoami`
- Create D1: `npx wrangler d1 create <name>`
- Local migrations: `npx wrangler d1 migrations apply <database_name> --local`
- Remote migrations: `npx wrangler d1 migrations apply <database_name> --remote`
- Local dev: `npx wrangler dev` (uses local D1 + `.dev.vars`)
- Set secret: `npx wrangler secret put <NAME>`
- Deploy: `npx wrangler deploy` or `npm run deploy`
- Deploy with config: `npx wrangler deploy --config wrangler.staging.toml`
- Live logs: `npx wrangler tail` or `npm run tail`
- Run SQL (remote): `npx wrangler d1 execute <database_name> --remote --command "SELECT 1"`
- Run SQL (local): `npx wrangler d1 execute <database_name> --local --command "SELECT 1"`

## 10 References and Extension

- The project's `wrangler.toml` and `migrations/` directory are the reference for the current Worker and D1 setup.
- Deployment steps and checklists can live in project docs (e.g. DEPLOYMENT.md, DEPLOYMENT_STEPS.md); this rule stays generic and does not reference specific instances or database names.

## 11 Pre-Deploy Checklist

- [ ] `wrangler.toml` has no `node_compat`; uses `compatibility_flags = ["nodejs_compat"]`
- [ ] No `[limits] cpu_ms` on the Free plan
- [ ] D1 `database_id` is set and matches `wrangler d1 create` output
- [ ] Remote env has run `d1 migrations apply <database_name> --remote`
- [ ] Secrets set via `wrangler secret put` (remote) or `.dev.vars` (local), not in toml
- [ ] `npm install` has been run before `wrangler deploy`
- [ ] If using Whisper/Workers AI, limits are confirmed and documented
