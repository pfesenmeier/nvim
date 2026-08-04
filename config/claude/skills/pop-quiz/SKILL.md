---
name: pop-quiz
description: 10 multiple choice questions on a topic
disable-model-invocation: true
allowed-tools: AskUserQuestion, Bash, Read, Write, Grep, Glob, WebSearch, WebFetch
argument-hint: "[focus-area]"
---

Quiz the user with 10 multiple choice questions. Research the topic from real sources, ask one
question at a time using the `AskUserQuestion` tool, grade as you go, and rewrite the results
file after **every** question so an abandoned quiz still leaves a usable record.

Results live in `~/Documents/pop-quizzes/` as one JSON file per quiz, named
`<YYYY-MM-DD>-<topic-slug>.json` (append `-2`, `-3`, … if that name is taken). Create the
directory with `mkdir -p ~/Documents/pop-quizzes` if it does not already exist.

Most quizzes get abandoned partway through. That is expected and fine — it is why the file is
written incrementally rather than at the end, and why research is done just-in-time rather than
all up front.

## Phase 1 — Pick the topic

If `$ARGUMENTS` is provided, that is the topic. Otherwise use `AskUserQuestion` to offer 3–4
candidate topics drawn from the current project (languages, frameworks, and tools you can see
in the repo) — the user can always pick "Other" and type their own.

Derive `topic-slug` from the topic: lowercase, non-alphanumerics collapsed to `-`
(e.g. `Rust async` → `rust-async`).

## Phase 2 — Load history

```bash
ls ~/Documents/pop-quizzes/ 2>/dev/null
```

Read every file whose slug matches or overlaps the current topic, plus the 3 most recent files
regardless of topic. Partial files count — they are the main reason this history exists. Records
are `.jsonl` (one object per line); a few early quizzes exist as pretty-printed `.json`, so handle
both. Use them to:

- **Never repeat a question** the user has already been asked on this topic, even reworded.
- **Re-test what they got wrong** — roughly 2 of the 10 questions should probe a concept missed
  in a previous quiz, from a different angle.
- **Calibrate difficulty** — if the last quiz on this topic scored ≥ 80% of questions answered,
  go harder; ≤ 50%, go easier.
- **Reuse sources** — the `sources` array of a previous quiz on this topic is a head start.

If there is no history, aim for a mix of 3 easy / 5 medium / 2 hard.

## Phase 3 — Research the topic

Do not write questions from memory. Every question must be grounded in something you actually
read during this session, and the source recorded alongside it. Answering from memory produces
questions that are subtly wrong — a real event or flag omitted, a renamed API, a version-skewed
default — and a quiz that teaches wrong things is worse than no quiz.

Available research moves, roughly in order of preference:

1. **The local filesystem** — the user's own config, dotfiles, and project source. `Read`,
   `Grep`, `Glob`. Questions grounded in code the user actually runs land hardest.
2. **Official docs on the web** — `WebFetch` a specific page, `WebSearch` when you need to find
   it first. Prefer primary sources (project docs, RFCs, man pages) over blog posts.
3. **A repo, cloned and explored** — for library or framework topics, read the source:
   ```bash
   mkdir -p ~/.cache/pop-quiz/repos
   git clone --depth 1 --quiet <url> ~/.cache/pop-quiz/repos/<name>
   ```
   Shallow read-only clones for throwaway source reading; plain `git` is correct here since no
   jj workspace is wanted. Reuse an existing clone if the directory is already there, and
   `git -C <dir> log -1 --format=%H` to record what you read.
4. **Installed artifacts** — `--help` output, man pages, `rg` over an installed binary's string
   table, package metadata. Good for "what does this actually do on this machine" questions.

### Running nvim and jj

Both are frequent topics and both can answer questions about themselves. Both will also hang the
session if invoked wrong, so use these forms.

**nvim** — always `--headless` with an explicit `-c 'qa'`; never a bare `nvim`, which starts a TUI
that never returns. Headless `:echo` goes to stderr, so redirect with `2>&1`:

```bash
nvim --headless -c 'set shiftwidth?' -c 'qa' 2>&1
nvim --headless -c 'echo &shiftwidth . " / " . &expandtab' -c 'qa' 2>&1
nvim --headless -c 'lua print(vim.inspect(vim.opt.completeopt:get()))' -c 'qa' 2>&1
nvim --headless -c 'lua local m = vim.api.nvim_get_keymap("n"); print(#m)' -c 'qa' 2>&1
```

The highest-value pattern for this user is **their config versus the default**, since the primary
working directory *is* their nvim config repo — run the same query twice, once normally and once
with `-u NONE`:

```bash
nvim --headless      -c 'echo &shiftwidth' -c 'qa' 2>&1   # their config: 2
nvim --headless -u NONE -c 'echo &shiftwidth' -c 'qa' 2>&1   # stock default: 8
```

That gives you a verified question ("what does *your* config change about X?") plus a verified
distractor (the stock value) in two commands. Pair it with `rg` over `lua/` to find where the
setting is made, and cite that `file:line` as the source.

To quote `:help` text, use `-u NONE` (faster, no plugin interference) and guard the line range —
a range past the end of the buffer errors with `E16`:

```bash
nvim --headless -u NONE -c 'redir >>/dev/stdout' -c 'silent help quickfix.txt' -c 'silent 1,4p' -c 'qa' 2>/dev/null
```

If a headless call ever hangs — a plugin manager syncing on startup, a prompt waiting on input —
kill it and retry with `-u NONE`.

**jj** — put `--no-pager` immediately after `jj` so a pager never captures the terminal, and so the
call matches the allowlisted `Bash(jj --no-pager:*)` prefix:

```bash
jj --help
jj --no-pager help -k tutorial
jj --no-pager help <subcommand>
jj --no-pager config list --include-defaults
jj --no-pager log -r 'ancestors(@, 5)'
jj --no-pager op log --limit 5
```

For per-subcommand flag docs prefer `jj --no-pager help <subcommand>` over
`jj <subcommand> --help`: the former matches the allowlisted prefix for every subcommand, while
the latter only avoids a prompt for the handful of subcommands allowlisted by name.

Never run a jj command that opens an editor (`jj describe`, `jj split`, `jj commit` without `-m`) —
it will hang waiting on `$EDITOR`. Research is read-only, so this should not come up; if you need
a commit message, read it with `jj --no-pager show`.

`jj config list --include-defaults` is the authoritative source for default-value questions, and
`jj --no-pager help <cmd>` for flag behavior. Record `jj --version` in `sources` — jj is
pre-1.0 and its CLI moves fast, so a question written against 0.43 may be wrong by 0.50.

Rules:

- **Verify or drop.** If you cannot confirm a fact from a source, do not build a question on
  it. Silently dropping a shaky question is always the right call.
- **Record the source per question** — a URL, a `file:line`, or a command. This is what makes a
  wrong answer reviewable later.
- **Be specific about versions.** Note the version of whatever you read (`claude --version`, a
  commit SHA, a doc page's version selector) in the top-level `sources` array. Behavior drifts.
- **Do not research all 10 questions before asking the first one.** That is a long silent
  stall. See the pacing below.

### Pacing the research

`AskUserQuestion` blocks — nothing runs in the main loop while a prompt is on screen. So the
only work that genuinely overlaps a question is a **backgrounded `Bash` call**. Structure it
this way:

1. Before Q1, launch the slow I/O in the background — clones, downloads, `--help` dumps redirected
   to files in `~/.cache/pop-quiz/`. Use `run_in_background: true`.
2. Research **just Q1** in the foreground, from one source. Ask it.
3. In each gap between questions — after grading, before the next `AskUserQuestion` — collect
   whatever background jobs have finished and research the next 1–2 questions. Keep each gap to
   a few tool calls so the quiz does not stall between questions.

This front-loads only one question's worth of latency, and the expensive fetching happens while
the user is reading Q1 rather than before they see anything.

Since most quizzes are abandoned around question 3–5, deep research into questions 8–10 is
usually wasted. Research shallowly ahead, deeply just-in-time.

## Phase 4 — Ask the questions

Ask up to 10 questions, **one `AskUserQuestion` call per question** — never batch several
questions into one call, since the user needs feedback on each before seeing the next.

Each call has one question with exactly 4 options, `multiSelect: false`:

- `question` — the full question text.
- `header` — a ≤12 char label for the concept being tested (e.g. `Ownership`, `HTTP verbs`).
- `options[].label` — the answer, kept to a few words.
- `options[].description` — the rest of the answer when it does not fit in the label, or a
  clarifying detail. Never hint at which option is correct here; every option gets a
  description of comparable length and confidence.

Rules:

- Randomize which position holds the correct answer.
- Distractors must be plausible — common misconceptions, adjacent-but-wrong APIs, off-by-one
  variants. No filler or joke options. Research makes better distractors: the real name of the
  thing that *isn't* the answer beats an invented one.
- For questions that need a code snippet, table, or command output, print it to the terminal in
  a fenced block *before* making the `AskUserQuestion` call, then have the question refer to it
  ("In the snippet above, …").
- Test understanding and application, not trivia. Prefer "what does this do / what breaks /
  which is correct here" over "what year was X released".

After each answer, print one or two lines of immediate feedback, citing the source when it adds
something:

```
Q3 ✅ Correct — `Arc<T>` is the atomically refcounted one; `Rc<T>` is single-threaded.
```

```
Q4 ❌ You said B. Correct answer: D — `.iter()` borrows, `.into_iter()` consumes. (std::iter docs)
```

If the user answers with "Other" free text, judge it on its merits: credit it if it is
substantively right, and say so in the feedback. "Not sure" or similar is not a correct answer —
grade it wrong, say so plainly, and give the explanation.

### After a miss, offer to go deeper

Every time an answer is graded wrong, print the one-line correction and then offer a deeper
explanation with a two-option `AskUserQuestion` — `Explain in depth` / `Next question`. Offer the
initial deep dive only on misses, once per question, and never after a correct answer.

A one-line "say the word if you want more" is not the offer — it forces the user to interrupt.
The prompt is the offer, so accepting costs one keystroke.

If they take it, explain the **underlying model rather than the fact**: why the design works this
way, what problem it solves, what else follows from it, and the adjacent thing most people confuse
it with. Two or three paragraphs, not a wall. Research further if the page you built the question
from doesn't explain the *why* — a deep dive is exactly when a second `WebFetch` is worth the wait.
Cite what you read.

The user's "Other" free text here is usually a specific follow-up question — answer that instead
of delivering the generic explanation.

Record `"deep_dive": true` on the question when they accept the deep dive. A concept the user
stopped to dig into is a stronger signal of a real gap than a wrong guess alone, so later quizzes
should weight those concepts more heavily than ordinary misses when choosing what to re-test.

### After the explanation, offer a follow-up

An explanation is where questions get asked, so end every deep dive with another two-option
`AskUserQuestion` — `Next question` / `Ask a follow-up`. Same reasoning as the deep-dive offer:
without a prompt on screen the user has to interrupt the quiz to ask, and most won't bother.

- `Next question` — resume the quiz at the next question.
- `Ask a follow-up` — the description should say to type the question into "Other". If they pick
  the option with no text, ask what they want to know before answering.

Answer the follow-up at the same depth as the deep dive, research it if the answer isn't already
in a source you read, then offer the pair again. Loop as long as they keep asking — a user chasing
a concept three questions deep is the most valuable thing this skill does, so the quiz can wait.
Only `Next question` ends the loop.

If the user interrupts to ask a real question, answer it, then offer to resume. The results file
is already current, so an interruption costs nothing.

## Phase 5 — Record after every question (append-only)

Immediately after grading each answer — **before** asking the next question — **append one line**
to the results file.

Never rewrite the whole file. A full rewrite grows with every question, and the tool output it
produces scrolls the question's feedback off the user's screen — which defeats the point of giving
feedback. One appended line per question keeps that output constant-sized no matter how far into
the quiz you are.

Append with a quoted heredoc, so apostrophes and double quotes in the question text survive
without escaping:

```bash
cat >> ~/Documents/pop-quizzes/2026-08-04-azure-monitor.jsonl <<'EOF'
{"kind":"q","n":5,"concept":"Retention","result":"incorrect","answered":"31 days","correct":"30 days"}
EOF
```

Keep every object on a **single line** — do not pretty-print. The file is JSON Lines
(`<YYYY-MM-DD>-<topic-slug>.jsonl`), with these line kinds:

| `kind` | When | Fields |
| --- | --- | --- |
| `quiz` | First line, once | `date`, `topic`, `topic_slug`, `total`, `sources` |
| `q` | After grading each question | `n`, `concept`, `difficulty`, `question`, `options`, `correct`, `answered`, `result`, `explanation`, `source` |
| `deep_dive` | User accepts a deeper explanation | `n` |
| `summary` | Only when the quiz finishes | `asked`, `score`, `completed`, `weak_concepts` |

Append a separate `deep_dive` line rather than editing the question's line — the file is
append-only, and nothing is ever rewritten in place.

This makes an abandoned quiz self-evident: it simply has no `summary` line. `asked` and `score`
are derived by counting `q` lines and `result` values, so no running totals need maintaining.

A complete abandoned-at-Q2 file looks like this — three lines, no summary:

```
{"kind":"quiz","date":"2026-08-04","topic":"Rust async","topic_slug":"rust-async","total":10,"sources":[{"kind":"web","ref":"https://doc.rust-lang.org/std/pin/","version":"1.89"},{"kind":"local","ref":"src/runtime.rs"}]}
{"kind":"q","n":1,"concept":"Ownership","difficulty":"medium","question":"…","options":["…","…","…","…"],"correct":"…","answered":"…","result":"correct","explanation":"…","source":"https://doc.rust-lang.org/std/pin/"}
{"kind":"q","n":2,"concept":"Pinning","difficulty":"hard","question":"…","options":["…","…","…","…"],"correct":"…","answered":"…","result":"incorrect","explanation":"…","source":"https://doc.rust-lang.org/std/pin/"}
```

- `correct` and `answered` hold the option label text, not a letter — labels survive reordering
  between quizzes, letters do not.
- `sources` goes on the `quiz` header line. If you research a new source mid-quiz, cite it in the
  `source` field of the question that used it; no need to restate the header.

Print the absolute path to the file once, right after the first write, so the user knows where
the record lives even if they bail at Q2. Don't echo the appended JSON back as prose — the point
of appending is to keep the screen clear for the feedback.

## Phase 6 — Report

When the 10th question is graded — or whenever the user stops and asks how they did — print a
summary:

```
Pop quiz — Rust async · 7/10

Missed:
  Q4  Iterator adapters   — `.iter()` vs `.into_iter()`
  Q7  Pinning             — why `!Unpin` futures need `Box::pin`
  Q9  Cancellation safety — dropping a future mid-`await`

Weak areas: pinning, cancellation safety
```

Then append the final line:

```bash
cat >> ~/Documents/pop-quizzes/<file>.jsonl <<'EOF'
{"kind":"summary","asked":10,"score":7,"completed":true,"weak_concepts":["pinning","cancellation safety"]}
EOF
```

For a partial quiz, score it out of what was asked (`2/4`) and say it was partial.

Follow with 2–3 sentences on what to review, and one concrete pointer per weak area — prefer the
source you actually used for that question over a generic recommendation. If a concept was missed
on a previous quiz too, call that out explicitly.

The last line of terminal output is the absolute path to the JSON file, with no other text on
that line.
