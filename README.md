# personal dev config

## New Section of Config - Terminal Buffers <space> t

"create or go to" -> jjui, claude

## AI - <space> a

- maybe wire up code companion, or do it custom
- ap - input, submit prompt to claude
- aP - share buffer path with claude
- as - share selection
- ab - share buffer contents

## Execute buffer command

- add <leader>r for running file
- filetype extensions to set up
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

- [ ] customize background in jjui to be darker
- [ ] refresh lsp diagnostics when leaving normal mode
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
