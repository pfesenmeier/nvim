---
name: pr-summary
description: Write a PR description for the current branch's changes as a markdown file under 4000 characters (the Azure DevOps limit). Use when asked to "write up a pr summary", "pr description", or "summarize this branch for a PR".
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: "[extra context or focus]"
---

Write a PR description for the current branch and save it as markdown. The file must be **under 4000 characters** (Azure DevOps rejects longer descriptions).

Extra context from the user, if any: $ARGUMENTS

## 1. Gather the change

Use `jj`, not `git`.

```bash
jj log -r 'main..@' --no-graph
jj diff -r 'main..@' --stat
jj diff -r 'main..@' --git
```

If `@` is empty, the range still covers the parent commits. Read the full diff, and open the surrounding code when the diff alone doesn't explain the reason for a change. Use the commit message's title as the PR title.

## 2. Write it

Write for a reviewer who knows the codebase but not this branch. Plain English, straight to the point. Use this structure and drop any section with nothing to say:

```markdown
## <commit title>

<1-2 sentences: what this enables and why.>

### What changed

**<Area or feature>**
- <Behavior and the reason for it, not a list of lines touched.>

### Tests
- `<TestClass>`: <the behaviors covered, in a short phrase each>

### Deploy notes
- <Migrations, data backfills, config, ordering, anything ops needs to know.>
```

Guidelines:
- Group by feature or behavior, not by file. Name the key types, activities, queries and migrations in backticks so reviewers can find them.
- Call out design decisions a reviewer would question: why a column is excluded, why a failure is swallowed, why a query is scoped a certain way.
- Mention new GraphQL fields, endpoints, schema changes, and auth requirements.
- Don't claim tests pass unless you ran them in this session.
- No filler, no "this PR", no closing summary.
- End with the attribution line from the system reminder, if there is one.

## 3. Enforce the length limit

Save to `~/Documents/pr-summaries/<YYYY-MM-DD>-<bookmark-or-change-id>.md` (`mkdir -p` first). Use the jj bookmark name when there is one; otherwise use the short change id.

Check the length:

```bash
wc -m <file>
```

If it's 4000 or more, tighten and check again: merge bullets, cut test detail down to class names, drop restated context. Cut the least important content first, never the deploy notes. Repeat until it's under 4000.

## 4. Report

Print the final markdown in the terminal so it can be pasted, then give the character count and the file path as a clickable link. Expand `~` to the full absolute path, because a `~` path isn't clickable. Write it as a markdown link to a `file://` URL, for example `[2026-10-16-my-branch.md](file:///home/<user>/Documents/pr-summaries/2026-10-16-my-branch.md)`. If tests weren't run, say so in one line.
