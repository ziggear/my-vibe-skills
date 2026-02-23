---
name: github-codebase-explorer
description: Thoroughly analyze and understand a GitHub codebase. Use when exploring a new repository, understanding project structure, or generating comprehensive project documentation. Accepts a GitHub repo URL, checks Git/SSH access, clones the repo via command line, then discovers key modules and creates IntroductionOfProject.md with project overview, architecture, and caller's guide.
context: fork
agent: Explore
allowed-tools: Read, Glob, Grep, Bash
argument-hint: [github-repo-url] [output-filename]
---

# GitHub Codebase Explorer

You are an expert codebase analyst. Your task is to systematically understand a GitHub repository and generate comprehensive documentation.

## Prerequisites: Repo Access and Clone

Before analysis, ensure GitHub access and obtain the codebase.

### Step 0a: Check GitHub Access (Do This First)

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

### Step 0b: Get Repo URL and Clone

- **If the user provides a GitHub repo URL** (e.g. `https://github.com/owner/repo` or `git@github.com:owner/repo.git`):
  - Normalize URL to a cloneable form (ensure it ends with `.git` for HTTPS or is in `git@github.com:owner/repo.git` form for SSH).
  - Choose a clone target: workspace subdirectory (e.g. `./github-codebase-explorer-workspace/<repo-name>`) or current directory. Avoid overwriting existing work.
  - Clone via command line:
    ```bash
    git clone --depth 1 <repo-url> <target-dir>
    ```
  - Use `--depth 1` for a shallow clone unless the user needs full history.
  - After cloning, **run all analysis steps (Steps 1–8) under the cloned directory** (e.g. `cd <target-dir>` in subsequent Bash commands; use that path for Read/Glob/Grep).

- **If the repo is already in the workspace** (user did not give a URL):
  - Skip clone. Proceed with the 8-step analysis in the current (or specified) repo directory.

- **If the user did not provide a URL and no repo is present**: Ask for a GitHub repository URL, then run Step 0a and 0b.

## Analysis Methodology

Follow this **8-step process** to thoroughly understand any codebase (run from the repo root, i.e. cloned dir or existing workspace):

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

**Write the output to:** If user passed two arguments, the second is the output filename; if one argument and it is not a GitHub URL, use it as the output filename; otherwise use `IntroductionOfProject.md`. Place the file in the analyzed repo root (cloned dir or workspace).

## Best Practices

- **Be thorough but concise**: Don't overwhelm with details, but don't skip important context
- **Use file references**: Point to specific files (e.g., `src/auth/login.ts:45`) for precision
- **Quote directly**: When extracting important comments or documentation, use exact quotes
- **Identify patterns**: Note recurring patterns in code organization and design
- **Stay objective**: Report what you find, not what you think should be there
- **Highlight risks**: Explicitly call out potential issues or gotchas
- **Think from user's perspective**: What would a new contributor or user need to know?

## Important Reminders

- **First**: Run Step 0a (check GitHub/SSH access). If the user will clone via SSH and the test fails, tell them to add their public key to GitHub or use an HTTPS URL.
- **Repo source**: If the user provides a GitHub repo URL, run Step 0b to clone it; then run Steps 1–8 inside the cloned directory.
- Always start with README.md unless it doesn't exist
- Ignore docs/ until Step 6 (unless user requests it)
- The 3 core modules should represent the heart of the project, not peripheral utilities
- Caller's Guide is the most valuable section - spend time here
- If a project is too large, focus on understanding the architecture rather than every file
- Use diagrams (ASCII art) when helpful to show relationships
- When writing the output file, use the path relative to the analyzed repo root (or workspace); if user passed an output filename in arguments, use that.

---

**Now begin: (0a) check GitHub access → (0b) get repo URL and clone if needed → then run the 8-step analysis.**
