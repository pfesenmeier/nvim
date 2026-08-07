---
name: pr-review
description: Full code review of current branch changes (correctness, security, tests, architecture)
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "[focus-area]"
---

Perform a thorough code review of the current branch's changes. Follow these phases in order.

The final review must be saved to `~/Documents/pr-reviews/` as a markdown file, in addition to being printed to the terminal. Create the directory with `mkdir -p ~/Documents/pr-reviews` if it does not already exist. Name the file `<YYYY-MM-DD>-<branch-or-change-id>.md` (use the current change's bookmark/branch name when available; fall back to the jj change ID).

A JSON sidecar must also be written at the **same basename** (e.g. `2026-06-10-my-branch.json`) — see Phase 5 for shape. The JSON path is printed on its own line *before* the final markdown-path line. The last line of terminal output is still the absolute path to the markdown file.

## Phase 1 — Gather context

Run these commands to understand what changed:

```bash
jj status
jj log -r 'ancestors(@, 10) ~ ancestors(main)' --no-graph
jj diff
```

If `jj diff` produces no output (clean working copy), the diff is between the working copy parent and `main`:
```bash
jj diff -r 'latest(ancestors(@) ~ ancestors(main))'
```

## Phase 2 — Per-file analysis

For each changed file:
1. Read the full file for context (not just the diff)
2. Use `rg` to find callers, related code, and usages
3. Locate corresponding test files and read them

## Phase 3 — Review criteria

Evaluate all four areas regardless of focus:

1. **Correctness** — logic errors, null/edge case handling, off-by-one errors, race conditions, incorrect assumptions
2. **Security** — injection vulnerabilities, auth gaps, secret/credential exposure, missing input validation, insecure defaults
3. **Test coverage** — are changes covered by tests? do tests verify the new behavior or just the happy path? are edge cases tested?
4. **Architecture** — coupling, separation of concerns, design pattern consistency, naming clarity, over-engineering or under-engineering

If `$ARGUMENTS` is provided, weight that area more heavily in your analysis but still cover all four areas.

## Phase 4 — Output format

Produce a structured markdown review. Print the full review to the terminal and also write the same content to `~/Documents/pr-reviews/<YYYY-MM-DD>-<branch-or-change-id>.md` (creating the directory if needed). After the review, print the absolute path to the markdown file (e.g. `/home/<user>/Documents/pr-reviews/2026-05-26-my-branch.md`) with no other text on that line.

### File references must be hyperlinks

Every file you mention — in headings, issues, or prose — must be written as a markdown link to an **absolute** `file://` URL. Terminals render that as a clickable hyperlink; a bare path or a bare `file://` URL does not become one.

```
[neovim/lua/huey/term.lua](file:///home/pfes/nvim/neovim/lua/huey/term.lua)
[term.lua:181](file:///home/pfes/nvim/neovim/lua/huey/term.lua#L181)
[term.lua:12–20](file:///home/pfes/nvim/neovim/lua/huey/term.lua#L12-L20)
```

Rules:
- Link text is short and repo-relative; the URL is always absolute.
- Add an `#L<n>` fragment whenever you cite a line — editors that follow the link jump straight to it.
- Percent-encode characters that are not URL-safe (space → `%20`).
- **Exception:** the trailing JSON and markdown path lines stay plain absolute paths — they are read by tooling, not clicked.

---

### PR Review Summary

**Branch commits:** [list commit descriptions]
**Files changed:** [count, then each file as a hyperlink]
**Focus area:** [if $ARGUMENTS provided, else "General"]

---

### What Changed

[2–4 sentence description of what the code does and why, inferred from the diff and context]

---

### Issues

Group by severity. Omit empty sections.

#### 🔴 Critical
[Bugs, security vulnerabilities, data loss risks — must fix before merge]

#### 🟡 Warning
[Logic gaps, missing tests, architectural concerns — should fix]

#### 💡 Suggestion
[Style, naming, minor improvements — nice to have]

---

### Per-File Feedback

For each changed file, provide inline feedback with line references where relevant.

**[path/to/file.ext](file:///abs/path/to/file.ext)**
- [observation, citing lines as [path/to/file.ext:42](file:///abs/path/to/file.ext#L42) where applicable]

---

### Positive Observations

[What was done well — good patterns, clear naming, solid tests, etc.]

---

### Questions / Unclear Intent

[Things that are ambiguous or where the intent is unclear — ask rather than assume]

---

Use precise line references when calling out specific code, always as hyperlinks (`[file.ext:42](file:///abs/path#L42)`, `[file.ext:100–115](file:///abs/path#L100-L115)`). Be direct and actionable. Skip generic advice that doesn't apply to the actual changes.

---

