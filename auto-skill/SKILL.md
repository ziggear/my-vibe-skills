---
name: auto-skill
description: At session end, reviews the conversation for detours and pitfalls, identifies learnings that should become or update skills, and creates or improves skills in the current Agent's skills directory (e.g. Cursor ~/.cursor/skills/, Claude ~/.claude/skills/). Use when closing a session, when the user asks for session recap or skill extraction, or after integrating new external capabilities (APIs, C libraries, third-party services) that lacked documentation and slowed progress.
---

# Auto-Skill: Session Recap and Skill Extraction

Run this workflow when **closing a session** or when the user asks to recap the session and extract skills. Goal: turn session pain into reusable skills so future sessions avoid the same detours.

**Skills directory**: Save skills in the **current Agent's skills directory** (the path depends on the host). Examples: Cursor uses `~/.cursor/skills/`, Claude uses `~/.claude/skills/`. Use the appropriate path for the environment you are running in.

**Confirmation**: Do not create or edit any skill files until the user has seen the proposed list (recap + planned new/improved skills) and explicitly approved. Support "execute all", "only these items", or "do not write".

## When to Run

- User says they are closing the session or asks to run "auto-skill"
- User asks for a session recap, lessons learned, or skill extraction
- Session just integrated a new external capability (API, C library, SDK, third-party service) and no skill existed—create one so next time is faster
- Session hit issues that an existing skill in the Agent's skills directory should have covered but didn't—improve that skill

## Workflow

### Step 1: Review the Session

Scan the full conversation and extract:

- **Detours**: Paths taken that didn't work or were unnecessarily slow (wrong approach, wrong docs, wrong assumption).
- **Pitfalls**: Concrete bugs, config mistakes, version/API mismatches, env or permission issues.
- **Decisions**: Important choices (e.g. "use REST not SDK", "this env var must be set").
- **External capabilities**: New APIs, libraries, or services used; note missing or unclear docs.

List these in a short recap (bullets are fine). No need to repeat the whole conversation—only what matters for learning and for skills.

### Step 2: Decide New vs Improve (agent decides, not the user)

**You** decide for each learning whether it becomes a **new skill** or an **improvement** to an existing skill. Do not ask the user to choose; give your conclusion and let the user only confirm whether to execute.

For each learning:

| Situation | Your decision |
|-----------|----------------|
| New external capability (API, C lib, SDK, service) and no existing skill covers it | **New skill** under `<Agent skills dir>/<topic>/SKILL.md` |
| Problem relates to an existing skill in the Agent's skills directory but the skill was incomplete, wrong, or unclear | **Improve** that skill (add section, fix description, add pitfalls/examples) |
| Generic or one-off lesson, not reusable | Optional: add to a small "lessons" section in an existing skill, or skip |

Check existing skills in the Agent's skills directory (e.g. assemblyai-transcription, cloudflare-deploy, openrouter-usage) before creating a new one; prefer improving over duplicating.

### Step 2.5: Skill Checklist and User Confirmation

**Do not create or edit any skill files until the user approves.**

1. Output the **session recap** (detours and pitfalls from Step 1).
2. Output the **skill checklist**. Each item is already classified by you as **create** or **improve** (from Step 2); the user does not choose create vs improve—they only agree or disagree with executing each item. Use this format:

   **To create** (proposed new skills)  
   - [ ] **Item 1**: path `<Agent skills dir>/<name>/SKILL.md`, one-line purpose, 1–2 key points to include  
   - [ ] **Item 2**: …  

   **To improve** (proposed changes to existing skills)  
   - [ ] **Item 1**: path `<Agent skills dir>/<existing>/SKILL.md`, what will be added or changed (e.g. new "XXX" section, fix description)  
   - [ ] **Item 2**: …  

   If there are none to create or improve, write "None" for that section. Use the actual path for the current Agent (e.g. `~/.cursor/skills/` when in Cursor, `~/.claude/skills/` when in Claude).

3. **Confirm with the user**: Ask the user to approve the list—not to choose create vs improve (you already decided). For each item ask Yes/No, or ask once: "N items above; reply Yes/No per item, or say execute all / skip all / only items X, Y."
4. **Only after** the user has confirmed (per-item Yes/No, or "execute all", etc.) proceed to Step 3 only for the approved items. If the user says skip or only recap, do not create or edit any files.

### Step 3: Create or Improve Skills (only after user confirmation)

Execute this step only when the user has approved the list from Step 2.5 (e.g. "execute all" or specified which items to do).

- **Location**: All new and updated skills go in the **current Agent's skills directory** (e.g. Cursor: `~/.cursor/skills/new-api-name/SKILL.md`, Claude: `~/.claude/skills/new-api-name/SKILL.md`).
- **How to write**: Follow the **create-skill** skill: YAML frontmatter (`name`, `description`), concise body, third-person description with WHAT and WHEN, under ~500 lines for SKILL.md. Use progressive disclosure (e.g. reference.md, examples.md) if needed.
- **New skill**: Include trigger scenarios, key pitfalls from this session, config/env gotchas, and links to official docs if relevant.
- **Improve existing**: Add a clear section or paragraph that addresses the pitfall or missing scenario from this session; fix any wrong or vague description.

You may create or improve **multiple skills** in one run.

### Step 4: Output Format

1. **Session recap** (for the user):
   - Detours and pitfalls (bulleted list).
   - Optional: one-line summary per learning.
2. **Skills produced**:
   - For each new skill: path (e.g. `<Agent skills dir>/xyz/SKILL.md`) and one-line purpose.
   - For each improved skill: path and what was added or changed.

## Examples

**Example 1 – New skill**  
Session integrated "VendorX API" with no skill. Integration was slow due to auth quirks and rate limits.  
→ Create `<Agent skills dir>/vendorx-api/SKILL.md` covering auth, rate limits, and the pitfalls encountered.

**Example 2 – Improve existing**  
Session used AssemblyAI; existing `assemblyai-transcription` skill didn't mention a REST vs SDK config mismatch that caused wrong timestamps.  
→ Edit `<Agent skills dir>/assemblyai-transcription/SKILL.md`: add a "REST vs SDK" section and the timestamp pitfall.

**Example 3 – No skill**  
Session only fixed a typo in one file. No reusable domain or capability.  
→ Only output the short recap; no new or updated skills.

## Checklist Before Finishing

- [ ] Recap lists real detours and pitfalls from this session, not generic advice.
- [ ] Proposed skill list was shown to the user and **user confirmed** before any file create/edit.
- [ ] Each new/updated skill lives in the current Agent's skills directory (e.g. `~/.cursor/skills/` or `~/.claude/skills/`).
- [ ] New skills follow create-skill (frontmatter, description, conciseness).
- [ ] Improved skills clearly address the gap or pitfall from this session.
- [ ] Output includes both recap and the list of skills created/updated with paths.
