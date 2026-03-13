---
name: pr-review
description: Full code review of current branch changes (correctness, security, tests, architecture)
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[focus-area]"
---

Perform a thorough code review of the current branch's changes. Follow these phases in order.

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

Produce a structured markdown review:

---

### PR Review Summary

**Branch commits:** [list commit descriptions]
**Files changed:** [count and list]
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

**`path/to/file.ext`**
- [observation with line reference if applicable]

---

### Positive Observations

[What was done well — good patterns, clear naming, solid tests, etc.]

---

### Questions / Unclear Intent

[Things that are ambiguous or where the intent is unclear — ask rather than assume]

---

Use precise line references (e.g. `L42`, `L100–115`) when calling out specific code. Be direct and actionable. Skip generic advice that doesn't apply to the actual changes.
