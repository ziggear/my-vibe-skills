---
name: auto-skill
description: At session end, reviews the conversation and outputs a recap table (Type, Details, Conclusion). Conclusions are Skip / SKILL (new or improve) / Rule/AGENTS. When the user points out that a specific item is suitable for a new or improved skill, updates the action checklist only and waits for final confirmation before creating or editing any file. Creates or improves skills in the Agent's skills directory, or proposes AGENTS.md/rule updates, only after user approval.
---

# Auto-Skill: Session Recap and Skill Extraction

Run this workflow when **closing a session** or when the user asks to recap the session and extract skills. Goal: turn session pain into reusable skills so future sessions avoid the same detours.

**Skills directory**: Save skills in the **current Agent's skills directory** (the path depends on the host). Examples: Cursor uses `~/.cursor/skills/`, Claude uses `~/.claude/skills/`. Use the appropriate path for the environment you are running in.

**Confirmation**: Do not create or edit any skill or rule files until the user has seen the proposed list (recap table + planned new/improved skills and/or AGENTS.md or rule updates) and explicitly approved. Support "execute all", "only these items", or "do not write". **Even when the user points out that a specific recap item or a conversation point is suitable for a new skill or for improving an existing skill, do not make the change immediately**—update the action checklist with that item and wait for the user's final confirmation before executing Step 3.

**Session language**: When outputting to the user (recap, skill checklist, confirmation prompts, summaries), use the **same language as the current conversation**. If the user has been writing in Chinese, output in Chinese; if in English, output in English. Infer from the user's messages; do not ask.

**Skill file language**: When writing or editing any SKILL.md (frontmatter and body), use **English** unless the user explicitly requests another language (e.g. "write this skill in Chinese").

## When to Run

- User says they are closing the session or asks to run "auto-skill"
- User asks for a session recap, lessons learned, or skill extraction
- **User discusses a specific recap item or conversation point** and indicates it is suitable for a new skill or for improving an existing skill (or adding to AGENTS.md/rule)—then follow **Discussion mode** (update checklist, wait for confirmation)
- Session just integrated a new external capability (API, C library, SDK, third-party service) and no skill existed—create one so next time is faster
- Session hit issues that an existing skill in the Agent's skills directory should have covered but didn't—improve that skill

## Discussion mode: user points out a specific item

When the user **discusses** a particular recap row or a point in the conversation and says (or implies) that it is suitable for a **new skill** or for **improving an existing skill** (or adding to AGENTS.md/rule):

1. **Think it through**: Decide whether it should go under "To create", "To improve", or "To add to AGENTS.md or rule"; choose path and scope (e.g. which existing skill to improve, what to add).
2. **Do not execute**: Do **not** create or edit any SKILL.md, AGENTS.md, or rule file at this step.
3. **Update the checklist**: Add or update the corresponding entry in the action checklist (To create / To improve / To add to AGENTS.md or rule). If a full recap table does not exist yet, you may output a minimal recap row for this item plus the updated checklist.
4. **Show and wait**: Output the updated checklist and ask the user to confirm when ready (e.g. "Execute all", "Do only item X", or "Skip"). Only after the user gives **final confirmation** proceed to Step 3 for the approved items.

This keeps all proposed changes in one place (the checklist) and avoids applying changes before the user has seen the full picture and agreed.

## Workflow

### Step 1: Review the Session and Build Recap Table

Scan the full conversation and extract each learning as one row. For each row classify:

- **Type**: One of Detour | Pitfall | Decision | External capability
  - **Detour**: Path taken that didn't work or was unnecessarily slow (wrong approach, wrong docs, wrong assumption).
  - **Pitfall**: Concrete bug, config mistake, version/API mismatch, env or permission issue.
  - **Decision**: Important choice (e.g. "use REST not SDK", "this env var must be set").
  - **External capability**: New API, library, or service used; note missing or unclear docs.

- **Details**: Short description of what happened or what was learned (one line or a few bullets).

- **Conclusion**: Assign one of the three conclusion types below using the **Judgment criteria**.

**Conclusion types and judgment criteria**

| Conclusion | Meaning | When to use (judgment criteria) |
|-------------|---------|----------------------------------|
| **Skip** | No need to improve or summarize. | One-off fix (typo, single-file change); project-specific detail with no reuse; already well documented elsewhere; low risk of repetition. |
| **SKILL** | Worth a new SKILL or supplement to an existing SKILL. | New external capability (API, SDK, service) with no skill yet; pitfall that an existing skill should have covered; reusable domain knowledge (auth, deploy, transcoding); config/env gotchas that will recur. Prefer improving an existing skill over creating a duplicate. |
| **Rule/AGENTS** | Can add to AGENTS.md or a Cursor rule. | Project-wide convention (e.g. "use npm when yarn fails"); coding standards; workflow or process rule; environment/tooling constraint that applies to this repo or team. |

**Session recap table** (output in the same language as the conversation):

| Type | Details | Conclusion |
|------|---------|------------|
| (e.g. Pitfall) | (what happened, 1–2 lines) | Skip / SKILL / Rule/AGENTS |
| … | … | … |

List every learning from the session in this table. No need to repeat the whole conversation—only what matters for learning and for skills.

### Step 2: Decide Action per Conclusion (agent decides, not the user)

**You** decide for each row in the recap table what action to take based on its **Conclusion**:

| Conclusion | Your decision |
|------------|----------------|
| **Skip** | No file change. Optionally mention in recap only. |
| **SKILL** | **New skill** under `<Agent skills dir>/<topic>/SKILL.md` if no existing skill covers it; otherwise **improve** that skill (add section, fix description, add pitfalls/examples). |
| **Rule/AGENTS** | Propose adding to **AGENTS.md** (project root or repo-specific) or to a **Cursor rule** (e.g. `.cursor/rules/` or rule file). Specify target file and suggested bullet or section. |

Check existing skills in the Agent's skills directory (e.g. assemblyai-transcription, cloudflare-deploy, openrouter-usage) before creating a new one; prefer improving over duplicating. For Rule/AGENTS, check whether the repo has AGENTS.md or `.cursor/rules/` and use the appropriate target.

### Step 2.5: Recap Table, Action Checklist, and User Confirmation

**Do not create or edit any skill or rule files until the user approves.**

1. Output the **session recap table** (Type | Details | Conclusion) from Step 1. Use the same language as the conversation.
2. Output the **action checklist**. Each item is already classified by you as **create** / **improve** / **add to Rule or AGENTS** (from Step 2). If the user has already pointed out specific items during discussion, those should already be reflected here (see **Discussion mode**); do not execute them until the user confirms. Use this format:

   **To create** (proposed new skills)  
   - [ ] **Item 1**: path `<Agent skills dir>/<name>/SKILL.md`, one-line purpose, 1–2 key points to include  
   - [ ] **Item 2**: …  

   **To improve** (proposed changes to existing skills)  
   - [ ] **Item 1**: path `<Agent skills dir>/<existing>/SKILL.md`, what will be added or changed (e.g. new "XXX" section, fix description)  
   - [ ] **Item 2**: …  

   **To add to AGENTS.md or rule** (proposed convention/rule entries)  
   - [ ] **Item 1**: target file (e.g. `AGENTS.md` or `.cursor/rules/foo.mdc`), suggested bullet or section text  
   - [ ] **Item 2**: …  

   If there are none in a category, write "None" for that section. Use the actual path for the current Agent (e.g. `~/.cursor/skills/` when in Cursor, `~/.claude/skills/` when in Claude).

3. **Confirm with the user**: Ask the user to approve the list. For each item ask Yes/No, or ask once: "N items above; reply Yes/No per item, or say execute all / skip all / only items X, Y."
4. **Only after** the user has confirmed (per-item Yes/No, or "execute all", etc.) proceed to Step 3 only for the approved items. If the user says skip or only recap, do not create or edit any files.

### Step 3: Create or Improve Skills / Add to AGENTS.md or Rule (only after user confirmation)

Execute this step only when the user has approved the list from Step 2.5 (e.g. "execute all" or specified which items to do).

**For SKILL items (create or improve):**

- **Location**: All new and updated skills go in the **current Agent's skills directory** (e.g. Cursor: `~/.cursor/skills/new-api-name/SKILL.md`, Claude: `~/.claude/skills/new-api-name/SKILL.md`).
- **Language**: Write all SKILL.md content (frontmatter and body) in **English** unless the user explicitly asked for another language.
- **How to write**: Follow the **create-skill** skill: YAML frontmatter (`name`, `description`), concise body, third-person description with WHAT and WHEN, under ~500 lines for SKILL.md. Use progressive disclosure (e.g. reference.md, examples.md) if needed.
- **New skill**: Include trigger scenarios, key pitfalls from this session, config/env gotchas, and links to official docs if relevant.
- **Improve existing**: Add a clear section or paragraph that addresses the pitfall or missing scenario from this session; fix any wrong or vague description.

**For Rule/AGENTS items:**

- **AGENTS.md**: Add to the project's AGENTS.md (e.g. repo root). Append a bullet or a short section that states the convention or constraint clearly. Keep tone consistent with existing content.
- **Cursor rule**: Create or edit a rule file (e.g. in `.cursor/rules/`). Use the format expected by the host (e.g. rule description and instructions). One rule file per concern or group related concerns.

You may create or improve multiple skills and add multiple Rule/AGENTS entries in one run.

### Step 4: Output Format

1. **Session recap** (for the user):
   - **Table**: Type | Details | Conclusion for each learning (use the same language as the conversation).
   - Optional: one-line summary per conclusion type (Skip / SKILL / Rule/AGENTS).
2. **Actions produced**:
   - For each new skill: path (e.g. `<Agent skills dir>/xyz/SKILL.md`) and one-line purpose.
   - For each improved skill: path and what was added or changed.
   - For each AGENTS.md or rule update: target file and what was added or changed.

## Examples

**Example 1 – New skill**  
Session integrated "VendorX API" with no skill. Integration was slow due to auth quirks and rate limits.  
→ Recap row: Type = External capability, Details = VendorX API auth and rate limits, Conclusion = SKILL.  
→ Create `<Agent skills dir>/vendorx-api/SKILL.md` covering auth, rate limits, and the pitfalls encountered.

**Example 2 – Improve existing**  
Session used AssemblyAI; existing `assemblyai-transcription` skill didn't mention a REST vs SDK config mismatch that caused wrong timestamps.  
→ Recap row: Type = Pitfall, Details = REST vs SDK config mismatch, wrong timestamps, Conclusion = SKILL.  
→ Edit `<Agent skills dir>/assemblyai-transcription/SKILL.md`: add a "REST vs SDK" section and the timestamp pitfall.

**Example 3 – Add to AGENTS.md**  
Session repeatedly hit "use npm when yarn fails" in this repo.  
→ Recap row: Type = Decision, Details = Prefer npm when yarn fails in this project, Conclusion = Rule/AGENTS.  
→ Add to project `AGENTS.md`: bullet under environment or tooling: "When yarn/npx fails, use npm."

**Example 4 – Skip**  
Session only fixed a typo in one file. No reusable domain or capability.  
→ Recap row: Type = Pitfall, Details = Typo fix in one file, Conclusion = Skip.  
→ Only output the recap table; no new or updated skills or rules.

## Checklist Before Finishing

- [ ] Recap is a **table** (Type | Details | Conclusion) with real detours, pitfalls, decisions, or external capabilities from this session—not generic advice.
- [ ] Each row's **Conclusion** is one of Skip / SKILL / Rule/AGENTS, using the judgment criteria.
- [ ] **Discussion mode**: If the user pointed out that a specific item is suitable for a new skill or improving an existing skill, the checklist was updated and **no** skill/rule file was created or edited until the user gave final confirmation.
- [ ] **Session language**: Recap table, checklist, and confirmations were output in the same language as the conversation.
- [ ] **Skill file language**: All SKILL.md content was written in English (unless the user requested otherwise).
- [ ] Proposed action list (create / improve / add to Rule or AGENTS) was shown to the user and **user confirmed** before any file create/edit.
- [ ] Each new/updated skill lives in the current Agent's skills directory (e.g. `~/.cursor/skills/` or `~/.claude/skills/`).
- [ ] New skills follow create-skill (frontmatter, description, conciseness).
- [ ] Improved skills clearly address the gap or pitfall from this session.
- [ ] AGENTS.md or rule edits match the proposed bullets/sections and repo conventions.
- [ ] Output includes recap table and the list of skills/rules created or updated with paths.
