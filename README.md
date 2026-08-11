# personal dev config

## TODO

- [x] jj pickers
- [x] jj bracketed
- [x] jj diff? (color line numbers)
- [x] workspace bracketed
- [x] clickable links (Claude)
- [x] :Jj
- [x] close and go to next workspace
- [ ] JJ lines history
- [ ] :Jj diff -f @- %
- [ ] :Jj command -> instead of dump to second buffer, invoke Jjui


## Niceties

- Have nushell emit prompt sequences for navigation

Insert mode shortcuts
- alt+$, alt+0 for start, end of lines
- alt+Enter for creating newline

Commands
- dotnet helpers -> :DotnetTest
  - find closest test project
  - passes in closest test project, test method name

Move terminal commands
- I forget that they are tuis. explore? float?

## NV

- nv notify
    - have stop / prompt hooks call nv notify
    - different types of notifications, e.g. 'buffer edited'

## AI / REGISTER

- :50at  ? share last 50 lines of terminal buffer
- ap - input, submit prompt to claude
- ass - share shell
- aP - share buffer path with claude
- as - share selection
- ab - share buffer contents

## Execute buffer command

- [ ] ft settings with default that shows error message
- add <leader>r for running file
<leader>rf - file
<leader>rs - selection

## JJUI

- [ ] shortcut to execute "b a", "git push"

## Terminal

- shortcut for cycling through open floating buffers

## UX

- [ ] shortcut edit nushell env / config
- [ ] add jj info to statusbar
- [ ] add claude status to statusbar

## Inspiration - VSCode Extextension
- Github Pull Requests
- Better Comments
- Paste JSON as Code
- Comment Tag Template
- Biome
- Css Peek
- File Utils
- Error Lens
- Code Snap
- Pretty TS Errors
- Permute Lines
- TODO Tree
