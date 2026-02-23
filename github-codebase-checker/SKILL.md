---
name: github-codebase-checker
description: Guide the agent to verify GitHub access (SSH/key) and pull or clone a GitHub repository into the workspace. Use when the user wants to fetch a repo by URL without running full codebase analysis. Performs access checks first, then clones via command line.
context: fork
agent: Explore
allowed-tools: Read, Glob, Grep, Bash
argument-hint: [github-repo-url] [target-dir]
---

# GitHub Codebase Checker

You guide the user and agent through **getting a GitHub repository onto the machine**: check that Git and GitHub access work, then clone the repo from a URL the user provides.

**Scope:** This skill does **not** analyze or document the codebase. It only ensures access and pulls the code. For full analysis and documentation, use the **github-codebase-explorer** skill after the repo is present.

## Workflow

Follow these steps in order.

### Step 1: Check GitHub Access (Do This First)

Run these checks so the user can fix permissions before clone fails.

1. **Verify Git is available**
   ```bash
   git --version
   ```
   If missing, tell the user to install Git.

2. **Test SSH access to GitHub** (needed if the user will use an SSH clone URL)
   ```bash
   ssh -T git@github.com
   ```
   - **Success:** message like "Hi username! You've successfully authenticated..."
   - **Failure:** "Permission denied (publickey)" or connection errors → tell the user to add their SSH public key to GitHub (Settings → SSH and GPG keys) or to use an **HTTPS clone URL** instead.

3. **Optional — list SSH public keys** (to confirm keys exist)
   ```bash
   ls -la ~/.ssh/*.pub 2>/dev/null || echo "No SSH public keys found"
   ```

If SSH test fails, instruct the user to either configure an SSH key for GitHub or use an **HTTPS clone URL** (e.g. `https://github.com/owner/repo.git`), which may use cached credentials or prompt for username/token.

### Step 2: Get Repo URL

- **If the user provided a GitHub repo URL** (e.g. `https://github.com/owner/repo` or `git@github.com:owner/repo.git`): use it and proceed to Step 3.
- **If no URL was provided:** ask the user for the GitHub repository URL, then run Step 1 (if not yet done) and Step 3.

Normalize the URL to a cloneable form:
- HTTPS: ensure it ends with `.git` (e.g. `https://github.com/owner/repo` → `https://github.com/owner/repo.git`).
- SSH: use form `git@github.com:owner/repo.git`.

### Step 3: Clone the Repository

- Choose a **target directory**:
  - Use `$ARGUMENTS[1]` if the user passed a second argument (target path).
  - Otherwise use a workspace subdirectory to avoid overwriting existing work, e.g. `./github-checker-workspace/<repo-name>` (derive `<repo-name>` from the URL, e.g. `owner-repo` or last path segment).
- Run:
  ```bash
  git clone --depth 1 <repo-url> <target-dir>
  ```
  Use `--depth 1` for a shallow clone unless the user needs full history.
- If clone fails (e.g. 404, permission denied), report the error and remind the user to check URL, visibility (private vs public), and GitHub access (SSH or HTTPS credentials).

### Step 4: Confirm Clone Succeeded

- Verify the target directory exists and is a Git repo:
  ```bash
  ls -la <target-dir> && git -C <target-dir> status
  ```
- Optionally list top-level contents so the user sees what was pulled:
  ```bash
  ls -la <target-dir>
  ```
- Tell the user the repo is ready at `<target-dir>` and that they can open it or run **github-codebase-explorer** for full analysis.

## Summary for the Agent

1. Run Step 1 (Git + SSH/HTTPS check).
2. Get repo URL from arguments or ask the user.
3. Clone with `git clone --depth 1 <url> <target-dir>` (Step 3).
4. Confirm with `ls` and `git -C <target-dir> status` (Step 4).

**Now begin: check access (Step 1) → get URL (Step 2) → clone (Step 3) → confirm (Step 4).**
