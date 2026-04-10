---
name: github-codebase-explorer
description: Thoroughly analyze and understand a codebase. Use when exploring a new repository, understanding project structure, or generating comprehensive project documentation. Accepts either a GitHub repo URL (clone after access checks) or an explicit local path to an existing checkout; when the path already contains a project (e.g. `.git`), skip GitHub and analyze in place. Writes IntroductionOfProject.md (or a custom filename) at the analyzed Git repo root (sibling of `.git`) so multiple repos under one tree do not overwrite each other's output.
context: fork
agent: general-purpose
allowed-tools: Read, Glob, Grep, Bash, Write
argument-hint: [github-repo-url | local-repo-path] [output-filename]
---

# GitHub Codebase Explorer

You are an expert codebase analyst. Your task is to systematically understand a repository and generate comprehensive documentation.

## Prerequisites: Choose Source (Local Path vs GitHub)

Before analysis, decide whether the codebase is **already on disk** or must be **fetched from GitHub**.

### Step 0 — Local codebase fast path (skip GitHub)

**When the user explicitly gives a filesystem path** (absolute, `~/...`, or workspace-relative) **and that path is a directory that already contains the project** — treat as **local-only** and **do not** run Step 0a (SSH/GitHub checks) or clone from GitHub.

**Strong signal the path is a real checkout (use this rule):**

- A **`.git`** entry exists under that directory. Count both:
  - **`.git` as a directory** (normal repository), and
  - **`.git` as a file** (linked worktree / some submodule layouts).

If that holds:

1. **Resolve** the path (expand `~`, follow the user’s path literally; use `Bash` to `test -d` / `ls` if needed).
2. **Set the analyzed repo root** to that directory for **all** of Steps 1–8 (`Read` / `Glob` / `Grep` use this root). For Step 8, treat this as **the only** directory where the output file may live unless the user explicitly asked for a different absolute path.
3. **Skip** Step 0a and Step 0b entirely — go straight to **Step 1 (read README, etc.)**.

**Analyzed repo root** (use consistently): the directory that **contains** `.git` as an immediate child (same level as `README.md`, `src/`, etc.). The default output `IntroductionOfProject.md` belongs **next to** `.git` — i.e. `<analyzed-repo-root>/IntroductionOfProject.md`, **not** a parent folder (e.g. not the outer monorepo/workspace root when you are analyzing an inner repo). That way **several Git repos under one tree** each keep their own file and **do not overwrite** one another.

**If the user gave a path but there is no `.git`:** do not assume it is wrong; they may use a non-Git export or a subtree. Either ask once for clarification **or**, if the tree clearly looks like source (e.g. `package.json`, `go.mod`, `Cargo.toml`, `src/`), proceed with analysis in that directory and still **skip** GitHub unless they also gave a **GitHub URL** to clone.

**If the input is clearly a GitHub URL** (`github.com/...`, `git@github.com:...`): ignore the fast path and use Step 0a → 0b below.

---

### Step 0a: Check GitHub Access (only when cloning from GitHub)

Run **only** when you need to clone from GitHub (URL provided and local fast path does **not** apply):

Run these checks so the user can fix permissions before clone fails:

1. **Test SSH access to GitHub** (if user will use SSH clone URL):
   ```bash
   ssh -T git@github.com
   ```
   - Success: message like "Hi username! You've successfully authenticated..."
   - Failure: "Permission denied (publickey)" or connection errors → tell user to add SSH key to GitHub (Settings → SSH and GPG keys) or use HTTPS URL instead.

2. **Verify Git is available**:
   ```bash
   git --version
   ```

3. **Optional — list SSH keys** (to confirm keys exist):
   ```bash
   ls -la ~/.ssh/*.pub 2>/dev/null || echo "No SSH public keys found"
   ```

If SSH test fails, instruct the user to either configure an SSH key for GitHub or provide an **HTTPS clone URL** (e.g. `https://github.com/owner/repo.git`), which may use cached credentials or prompt for username/token.

### Step 0b: Get Repo URL and Clone (only when cloning from GitHub)

- **If the user provides a GitHub repo URL** (e.g. `https://github.com/owner/repo` or `git@github.com:owner/repo.git`):
  - Normalize URL to a cloneable form (ensure it ends with `.git` for HTTPS or is in `git@github.com:owner/repo.git` form for SSH).
  - Choose a clone target: workspace subdirectory (e.g. `./github-codebase-explorer-workspace/<repo-name>`) or current directory. Avoid overwriting existing work.
  - Clone via command line:
    ```bash
    git clone --depth 1 <repo-url> <target-dir>
    ```
  - Use `--depth 1` for a shallow clone unless the user needs full history.
  - After cloning, **run all analysis steps (Steps 1–8) under the cloned directory** (e.g. `cd <target-dir>` in subsequent Bash commands; use that path for Read/Glob/Grep). That cloned folder is the **analyzed repo root** (contains `.git`); **write** `IntroductionOfProject.md` (or the chosen filename) **there**, not outside `<target-dir>`.

- **If the repo is already in the workspace** (user gave a local path per Step 0 fast path, or did not give a URL but the workspace root is the repo):
  - Skip clone. Proceed with the 8-step analysis in that repo directory.

- **If the user did not provide a URL or a usable path and no repo is present**: Ask for a **GitHub repository URL** or an **explicit local path** to the repo root, then run the appropriate branch (0a/0b for URL, or Step 0 fast path for local).

## Analysis Methodology

Follow this **8-step process** to thoroughly understand any codebase. **Always** run from the **analyzed repo root**: the single Git root for this run (directory that contains `.git`), whether that came from clone, explicit local path, or `git rev-parse --show-toplevel` when appropriate — **not** an arbitrary parent directory when a nested repo is the subject.

### Step 1: Read Root Documentation (Priority Order)

Read these files in the root directory:
- **`README.md`** - Always start here (primary documentation)
- **`ARCHITECTURE.md`**, **`DESIGN.md`**, **`IMPLEMENTATION.md`** - If present
- **`SETUP.md`**, **`INSTALL.md`**, **`GETTING_STARTED.md`** - Setup instructions
- Other `*.md` files that seem relevant

**Skip these files unless specifically requested:**
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `LICENSE`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`

### Step 2: Identify Sub-projects

Check if the root README.md references subdirectories as separate sub-projects. Common indicators:
- Monorepo structure with multiple packages
- "See `packages/` for..."
- "This repo contains X projects in `examples/`, `src/`, etc."

For each sub-project identified:
- Apply the same methodology as Step 1 to that subdirectory
- Read its `README.md` and documentation
- Note relationships between sub-projects

### Step 3: Handle docs/ Directory

**Initially ignore the `docs/` directory** unless:
- The user explicitly asks to examine it
- You cannot understand the project without it
- You've completed analysis of code and need supplementary documentation

The `docs/` directory will be revisited in **Step 6** when examining implementation details of core modules.

### Step 4: Build Directory Tree

After understanding the project from documentation:
- Traverse all directories recursively
- Build a complete directory tree showing:
  - All directories and their purposes
  - Key files in each location
  - File organization patterns
  - Entry points (main files, index files, etc.)

Use `Glob` and `Read` tools to map the structure. Pay attention to:
- Source code directories (e.g., `src/`, `lib/`, `app/`)
- Configuration files (e.g., `package.json`, `Cargo.toml`, `go.mod`)
- Test directories (e.g., `tests/`, `__tests__/`, `test/`)
- Build artifacts (usually ignore: `dist/`, `build/`, `node_modules/`)

### Step 5: Identify 3 Core Implementation Modules

Based on your understanding from Steps 1-4, identify the **3 most important implementation modules** in this project.

Criteria for selecting core modules:
- **Central functionality** - What does this project DO at its core?
- **Business logic** - Where is the primary domain logic?
- **Unique algorithms** - What makes this project special?
- **Integration points** - How do different components connect?
- **Data flow** - Where does data transformation happen?

For each module, document:
- **Location**: File path(s)
- **Purpose**: What it does
- **Dependencies**: What it depends on
- **Key functions/classes**: Main APIs

### Step 6: Deep Dive into Core Modules

For each of the 3 core modules identified:

**A. Examine Code Comments:**
- Read the actual implementation files
- Extract inline comments and documentation
- Note any TODOs, FIXMEs, or warnings
- Identify complex algorithms and design patterns

**B. Find Corresponding Documentation:**
- Now you CAN explore the `docs/` directory
- Search for documentation related to each core module
- Look for:
  - API documentation
  - Architecture diagrams
  - Design discussions
  - Implementation guides

**C. Cross-Reference:**
- Compare code comments with documentation
- Note any discrepancies
- Identify undocumented behaviors

### Step 7: Generate Project Analysis

Based on all gathered information, generate two key sections:

#### A. Project Overview

Include:
- **What it is**: Brief description (2-3 sentences)
- **Purpose**: What problem does it solve?
- **Type**: Library, framework, application, tool, etc.
- **Tech stack**: Main technologies and languages used
- **Architecture pattern**: Monolith, microservices, event-driven, etc.
- **Key features**: 3-5 bullet points of main capabilities

#### B. Notes for Callers/Consumers

This section is CRITICAL for anyone using this project. Detail:

**Constraints and Limitations:**
- Platform requirements (OS, runtime versions)
- Dependency constraints
- Performance limitations
- Scalability considerations

**Project Type Classification:**
- **Out-of-the-box**: Ready to use with minimal setup
- **Component**: Needs integration into larger system
- **Framework**: Requires following specific patterns
- **Library**: Provides specific functionality
- **Tool**: Standalone utility

**Prerequisites:**
- Required software/infrastructure
- Configuration requirements
- Environment variables
- Database/external service dependencies

**Potential Pitfalls (Gotchas):**
- Common mistakes users make
- Non-obvious behaviors
- Breaking changes between versions
- Configuration traps
- Data migration requirements
- Resource consumption warnings

**Integration Guidance:**
- How to integrate (for components/libraries)
- API usage patterns
- Extension points
- Customization options

### Step 8: Generate Final Documentation

Create a comprehensive markdown file with the following structure:

```markdown
# Introduction to [Project Name]

## Project Overview
[Content from Step 7A]

## File Structure
[Directory tree from Step 4]

## Core Modules

### Module 1: [Name]
- **Location**: [Path]
- **Purpose**: [Description]
- **Dependencies**: [List]
- **Key APIs**: [Functions/Classes]
- **Implementation Logic**: [From Step 6]

### Module 2: [Name]
[Same structure]

### Module 3: [Name]
[Same structure]

## Core Module Dependencies
[Diagram or list showing how modules interact]

## Implementation Details
[Key algorithms, design patterns, and architectural decisions]

## Caller's Reference Guide
[Content from Step 7B - Notes for Callers]

## Quick Start
[Minimal setup/instantiation example]

## Additional Resources
[Links to external docs, examples, tutorials]
```

**Determine output filename:**
- If the user passed **two** arguments: first = GitHub URL or local repo path, second = output filename
- If **one** argument: if it is a **GitHub URL** or an **existing directory** used as repo root (including Step 0 fast path) → use `IntroductionOfProject.md`
- If **one** argument: if it is **not** a URL and **not** an existing directory (e.g. only a filename like `MyOverview.md`) → use that string as the output filename; **analyzed repo root** = the Git root for the scope of work (`git rev-parse --show-toplevel` from the relevant cwd when inside a repo), not “workspace root” if that would point **above** the repo being documented
- Otherwise: use `IntroductionOfProject.md`

**Where to write the file (required — prevents overwrites):**

- **Default:** `<analyzed-repo-root>/IntroductionOfProject.md` — the **same directory as `.git`** (sibling of the `.git` entry), for **this** repository only.
- **Never** place the file in a **parent** directory of the analyzed repo just because the IDE opened a larger folder or monorepo. **One Git repo ⇒ one output file beside that repo’s `.git`.** Nested or sibling repos under one tree each get their own copy when you analyze each root separately; writing everything to a shared parent would **overwrite** a single `IntroductionOfProject.md`.
- If the user’s path is ambiguous (e.g. they pointed at a folder that is **not** a Git root but contains **multiple** nested `.git` dirs), **stop and ask** which repo root to analyze **or** run the skill **once per** chosen repo root.

**MANDATORY FINAL CHECKLIST — complete every item before finishing:**

- [ ] Determine the output filename using the rules above
- [ ] Confirm **analyzed repo root** = the directory that **contains** `.git` for the repo you analyzed in Steps 1–7 (clone target dir, explicit local path, or `git rev-parse --show-toplevel` as appropriate)
- [ ] Use the `Write` tool to write the full markdown content to `<analyzed-repo-root>/<output-filename>` (must be **sibling** of `.git`, not a parent path unless the user explicitly required a different absolute output path)
- [ ] Confirm the file was written by reading it back with the `Read` tool
- [ ] Report the full file path to the user

> **CRITICAL:** You MUST use the `Write` tool to save the file. Do NOT output the content as chat text only. If the file is not written to disk, Step 8 is incomplete.

## Best Practices

- **Be thorough but concise**: Don't overwhelm with details, but don't skip important context
- **Use file references**: Point to specific files (e.g., `src/auth/login.ts:45`) for precision
- **Quote directly**: When extracting important comments or documentation, use exact quotes
- **Identify patterns**: Note recurring patterns in code organization and design
- **Stay objective**: Report what you find, not what you think should be there
- **Highlight risks**: Explicitly call out potential issues or gotchas
- **Think from user's perspective**: What would a new contributor or user need to know?

## Important Reminders

- **First**: If the user gave an explicit local path with `.git` (dir or file) under it, use the **Step 0 fast path** — **do not** run Step 0a or clone.
- **GitHub clone path**: Only then run Step 0a (SSH/GitHub access). If the user will clone via SSH and the test fails, tell them to add their public key to GitHub or use an HTTPS URL.
- **Repo source**: If the user provides a GitHub repo URL, run Step 0b to clone it; then run Steps 1–8 inside the cloned directory.
- Always start with README.md unless it doesn't exist
- Ignore docs/ until Step 6 (unless user requests it)
- The 3 core modules should represent the heart of the project, not peripheral utilities
- Caller's Guide is the most valuable section - spend time here
- If a project is too large, focus on understanding the architecture rather than every file
- Use diagrams (ASCII art) when helpful to show relationships
- When writing the output file, put it **in the analyzed repo root** (next to `.git`); do not substitute the workspace root when it would steal or unify paths across multiple repos. If the user passed an output filename in arguments, still use **that** name under **that** repo root unless they gave a fully explicit output path.

---

**Now begin:** If explicit local repo path with `.git` → set repo root and run Steps 1–8. Otherwise → (0a) check GitHub access → (0b) clone if needed → then run the 8-step analysis.
