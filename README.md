# personal dev config

## New Section of Config - Terminal Buffers <space> t

"create or go to" -> jjui, claude

## Floating Term

- auto-resize??

## NV tool

- nv notify
- have stop / prompt hooks call nv notify
- have an edit refresh buffer if open???

## New Config -> Register

- <leader>r

## AI - <space> a

- maybe wire up code companion, or do it custom
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

- [ ] shortcut to execute "b a"

## Terminal

- shortcut for cycling through open floating buffers
- ergonomic in/out of terminal mode 

- POC sending data 
- current buffer, current selection, current diagnostics
- to floating term. 
- e.g. "display all revisions that touch this file in jjui"
- "send this selection plus a prompt to claude."
- "ask claude to fix these diagnosis, notify me when you have a fix to propose"

## UI

- [ ] have ctrl+b in terminal mode begin scrollback
- [ ] make ctrl+g scoped to current working dir
- [ ] Have "recent files" in dashboard scoped to current directory
- [ ] Have "sort by" feature in built-in picker
- [ ] wire in mini.sessions more...
- [ ] shortcut for load most recent claude plan
- [ ] shortcut for fp -> find plans (put title inside picker??)
- [ ] add jj info to statusbar
- [ ] make neovim homescreen more useful

- [ ] nushell format

e.g.,

wrapper around fzf to select package.json scripts in Code directory?

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
