# Tool Preferences

- Use `jj` instead of `git` for version control
- Use `rg --files` instead of `find` for file searching
- Use `rg` instead of `grep` for content searching
  - `rg` is not a drop-in replacement for `grep`. Verify these before assuming a flag means what it does in `grep`:
    - **`-n` is required when output is piped or captured.** `rg` only auto-enables line numbers on a TTY, so `rg foo` in a tool call prints `file:match` with no line number. Pass `-n` (or `--vimgrep`) whenever the result will be cited as `path:42`.
    - **`-r` is `--replace`, not recursive.** `rg` is already recursive; `rg -r pat dir` silently consumes `pat` as replacement text.
    - **`-l`/`--files-with-matches` lists files that matched; `--files` lists files without searching at all.** `--files-without-match` is the inverse of `-l`.
    - **`-c`/`--count` counts matching *lines*.** Use `--count-matches` to count matches.
    - Default filtering skips three independent things -- pick the matching override:
      - `--hidden` -- dotfiles/dotdirs only; does **not** un-ignore git-ignored files
      - `--no-ignore` / `-u` -- stop respecting `.gitignore`/`.ignore`/`.rgignore`
      - `-uu` = `--no-ignore --hidden`; `-uuu` = also searches binary files
    - Patterns are Rust regex (roughly `grep -E`): no backreferences or lookaround. Use `-P`/`--pcre2` for those, `-F` for literal strings, `-w` for whole words.
    - A pattern only matches within one line unless `-U`/`--multiline` is set; add `--multiline-dotall` for `.` to cross newlines.
    - Scoping: `-g GLOB` (repeatable, `!` negates), `-t TYPE`/`-T TYPE` (`rg --type-list`), `-d NUM` for max depth.
    - Result order is nondeterministic due to parallel traversal; `--sort=path` stabilizes it at the cost of single-threading.

- Be judicious about adding comments - should be infrequent and terse
- Your audience is always a developer who will do the PR review for the feature branch into main, or will find this change on main weeks or months from now.
