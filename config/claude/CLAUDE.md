# Tool Preferences

- Use `jj` instead of `git` for version control
- Use `rg --files` instead of `find` for file searching
- Use `rg` instead of `grep` for content searching
  - `rg` ignores git-ignored files by default; pass `--hidden` to search git-ignored files
  - `rg` is not a drop-in replacement for `grep` -- double check its flags if its output does not look correct

- Be judicious about adding comments - should be infrequent and terse
- Your audience is always a developer who will do the PR review for the feature branch into main, or will find this change on main weeks or months from now.
