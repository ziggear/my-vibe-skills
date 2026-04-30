# Code exploration task (handoff for another coding agent)

You are running inside a **local repository checkout**. Your job is **exploration and synthesis only**: read/search the codebase, infer architecture, and **do not** apply patches unless the user explicitly asked you to implement a fix in this same session. Prefer **read-only** inspection.

## Task title

@TASK_TITLE@

## What we need from this codebase

@TASK_DETAIL@

## External / ticket context (optional)

If this section is `none`, ignore it.

@ATLASSIAN_CONTEXT@

## Scope hint (optional)

@SCOPE_HINT@

---

## Instructions

1. **Confirm workspace assumptions**: language(s), build entrypoints, main apps/packages, and where configuration lives (only if inferable from the tree).
2. **Restate the problem or feature** in your own words (one short paragraph).
3. **Critical path**: trace from the **user-visible or API entrypoint** (route, CLI, job, UI action) through to the **core functions/classes** involved. Use bullet steps with **file paths** and **symbol names** when possible.
4. **Trigger conditions**: for bugs, list **preconditions** (state, flags, race, data shape, env vars). For features, list **activation conditions** and **edge cases**.
5. **Key implementation map**: table or bullet list of **the 5–15 most important files** with **one-line roles** each.
6. **Hypotheses & verification plan**: ranked guesses (for bugs) or design risks (for features), each with **what to log/read/test next** (concrete commands or files).
7. **Handoff block** (markdown code fence): a single ```handoff``` fenced block containing **≤ 40 lines** of dense notes another agent can paste into its context: scope, critical path, top files, top symbols, open questions.

Use clear headings matching sections above. If something cannot be determined from the repo, say **unknown** and list **what evidence** would resolve it.
