---
name: codex-code-agent
description: >-
  Delegate focused codebase exploration to OpenAI Codex CLI: clarify scope, critical path,
  triggers, and key implementation points, then surface a structured handoff for the current
  agent (feature work or bugfix). Covers install/login checks, optional Atlassian context
  (Jira/Confluence via atlassian-acli), and a scripted codex exec invocation.
---

# Codex Code Agent (exploration handoff)

## When to use

Use this skill when you want **Codex CLI** to do a **read-oriented exploration pass** in a repository and return a **concise brief** for *this* agent to continue implementation or debugging.

Good fits:

- A feature ticket needs **where code lives**, **call flow**, and **integration points**.
- A bug needs **likely trigger conditions**, **critical path**, and **files/symbols to inspect next**.

Codex runs **locally** in the user’s terminal against the chosen working tree. It is a **second agent**; your job is to **prepare context**, **run the exploration**, then **continue** from Codex’s output.

---

## Step 0 — Optional Atlassian context

If the user supplied **Jira keys** (e.g. `MOB-27751`) and/or **Confluence numeric page IDs**:

1. Read and follow **`~/.Codex/skills/atlassian-acli/SKILL.md`** to fetch summaries/bodies with `acli`.
2. Paste the **trimmed, relevant** excerpts into a scratch file (e.g. `.codex-atlassian-context.txt` in the repo or `/tmp`) to pass into the prompt (see Step 3).

Do **not** paste secrets or huge HTML dumps; keep **task-relevant** facts: summary, repro, acceptance criteria, links, comments that change interpretation.

---

## Step 1 — Prerequisites (Codex installed)

Run the bundled check (from any directory):

```bash
bash ~/.Codex/skills/codex-code-agent/scripts/codex-explore.sh check
```

If Codex is missing, install globally:

```bash
npm i -g @openai/codex
```

Re-run `check` until the binary is on `PATH`.

---

## Step 2 — Authentication

`codex login` is **interactive** (browser or device code). Per project conventions for other CLIs:

- Prefer asking the user to run **`codex login`** in their own terminal when `check` reports no credentials heuristic and Codex fails with an auth error.
- For **headless** setups, see OpenAI’s Codex auth docs (device code, API key for automation).

Do **not** ask the user to paste `~/.codex/auth.json` into chat.

---

## Step 3 — Build the exploration prompt

1. **Default working directory**: the **current task folder** (usually the git repo root the user is working in). Override only if the user asked for a specific path.
2. Open the English template:
   - `~/.Codex/skills/codex-code-agent/prompts/exploration-handoff.en.md`
3. Replace the placeholders (or let the script do it — see `scripts/codex-explore.sh --help`):
   - `@TASK_TITLE@` — short label (feature name or bug title).
   - `@TASK_DETAIL@` — what to build or what is broken; expected vs actual; repro if known.
   - `@ATLASSIAN_CONTEXT@` — paste Atlassian excerpts, or the literal `none`.
   - `@SCOPE_HINT@` — subsystems, URLs, feature flags, version paths, or “unknown; infer from repo”.

Either edit a **copy** of the template into a final prompt file, **or** pass `--title`, `--detail`, optional `--atlassian-file` / `--scope` / `-t` to `codex-explore.sh run` (mutually exclusive with `-p`).

---

## Step 4 — Run Codex exploration (non-interactive)

From the host (adjust `-C` if the scope is not cwd):

```bash
# A) Final prompt file you already filled (e.g. from the template):
bash ~/.Codex/skills/codex-code-agent/scripts/codex-explore.sh run \
  -C "$(pwd)" \
  -p /tmp/codex-explore-prompt.md

# B) Build from template flags (multiline-safe Atlassian file):
bash ~/.Codex/skills/codex-code-agent/scripts/codex-explore.sh run \
  -C "$(pwd)" \
  --title "Short title" \
  --detail "Feature/bug description, repro, expected vs actual..." \
  --atlassian-file /tmp/atlassian-context.txt \
  -o /tmp/codex-final-message.md
```

The script defaults to **`codex exec`** with **read-only sandbox** and **`--ask-for-approval never`** so the run is suitable for scripted exploration. It streams Codex output to the terminal; use `-o path` to also capture the **final assistant message** to a file for quoting in your next reply.

If the user explicitly wants Codex to **run tests or mutating commands**, do **not** use the default script presets: run `codex` / `codex exec` manually with **`--sandbox workspace-write`** (or appropriate approval mode) after the user confirms.

---

## Step 5 — Consume the handoff (this agent)

From Codex’s structured output, extract and use:

1. **Scope** — directories, services, configs involved.
2. **Critical path** — user/system entrypoints → modules → persistence/external calls.
3. **Triggers / preconditions** — state, flags, timing, data shape.
4. **Key files & symbols** — concrete paths and identifiers to open first.
5. **Risks / unknowns** — what still needs verification (tests, logs, repro).

Then continue: implement, add tests, or narrow the bug with **your** tools (Read/Grep/Shell in Cursor, etc.), citing Codex only as **hypothesis** until verified.

---

## Files in this skill

| Path | Purpose |
|------|---------|
| `prompts/exploration-handoff.en.md` | English prompt template with `@...@` placeholders |
| `scripts/codex-explore.sh` | `check` / `run` helper (PATH, auth heuristic, `codex exec`) |

---

## References

- Codex CLI overview: https://developers.openai.com/codex/cli  
- CLI options: https://developers.openai.com/codex/cli/reference  
- Authentication: https://developers.openai.com/codex/auth  
- Atlassian CLI skill: `~/.Codex/skills/atlassian-acli/SKILL.md`
